from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_restful import Api
from flasgger import Swagger
from dotenv import load_dotenv
import os
import uuid
from datetime import datetime, timedelta
from pymongo import MongoClient
import cv2
import numpy as np
import tensorflow as tf
import logging
from logging.handlers import RotatingFileHandler
import random
from collections import deque
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from functools import wraps

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
handler = RotatingFileHandler('app.log', maxBytes=10000, backupCount=1)
handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)

# Initialize Flask app
app = Flask(__name__)
CORS(app)
api = Api(app)

# JWT Secret Key
app.config['SECRET_KEY'] = os.getenv('JWT_SECRET_KEY')

# Configure Swagger
swagger_config = {
    "headers": [],
    "specs": [
        {
            "endpoint": 'apispec',
            "route": '/apispec.json',
            "rule_filter": lambda rule: True,
            "model_filter": lambda tag: True,
        }
    ],
    "static_url_path": "/flasgger_static",
    "swagger_ui": True,
    "specs_route": "/docs"
}

swagger_template = {
    "swagger": "2.0",
    "info": {
        "title": "Emotion Detection API",
        "description": "API for facial emotion detection and analysis",
        "version": "1.0.0"
    }
}

swagger = Swagger(app, config=swagger_config, template=swagger_template)

# MongoDB setup
client = MongoClient(os.getenv('MONGODB_URI', 'mongodb://localhost:27017/'))
db = client.emotion_detection
predictions_collection = db.predictions
users_collection = db.users

# Load the emotion detection model
model = tf.keras.models.load_model('D:\Mostafa\Work\BUE 2024-2025\Emotion detection\Emotion detection\emotion_model.h5')
emotion_labels = ['angry', 'disgust', 'fear', 'happy', 'sad', 'surprise', 'neutral']

# Load face cascade classifier
face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

# Add after other global variables
_used_stories = deque(maxlen=5)  # Store last 5 used stories
_used_tips = deque(maxlen=5)     # Store last 5 used tips

# Token required decorator
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        try:
            token = token.split(' ')[1]  # Remove 'Bearer ' prefix
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = users_collection.find_one({'email': data['email']})
            if not current_user:
                return jsonify({'error': 'User not found'}), 401
        except Exception as e:
            return jsonify({'error': 'Invalid token'}), 401
        return f(current_user, *args, **kwargs)
    return decorated

def preprocess_image(image_data):
    """Preprocess the image for model prediction"""
    try:
        # Convert bytes to image
        nparr = np.frombuffer(image_data, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return None, "Failed to decode image"
            
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Detect faces
        faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
        if len(faces) == 0:
            return None, "No face detected"
            
        # Get the largest face
        (x, y, w, h) = max(faces, key=lambda box: box[2] * box[3])
        face = gray[y:y + h, x:x + w]
        
        # Resize to model input size
        face_resized = cv2.resize(face, (48, 48))
        
        # Normalize and reshape
        image_pixels = face_resized.reshape(1, 48, 48, 1).astype('float32') / 255.0
        
        return image_pixels, None
        
    except Exception as e:
        return None, f"Error in preprocessing: {str(e)}"

@app.route('/api/predict', methods=['POST'])
@token_required
def predict_emotion(current_user):
    """
    Predict emotion from image
    ---
    parameters:
      - name: image
        in: formData
        type: file
        required: true
        description: Image file to analyze
      - name: device_id
        in: header
        type: string
        required: false
        description: Unique device identifier
    responses:
      200:
        description: Prediction result
    """
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'No image provided'}), 400

        image_file = request.files['image']
        image_data = image_file.read()
        
        # Preprocess image
        processed_image, error = preprocess_image(image_data)
        if error:
            return jsonify({'error': error}), 400
        
        # Get prediction
        predictions = model.predict(processed_image)
        emotion_idx = np.argmax(predictions[0])
        emotion = emotion_labels[emotion_idx]
        confidence = float(predictions[0][emotion_idx])
        
        # Create prediction record
        prediction_record = {
            'request_id': str(uuid.uuid4()),
            'timestamp': datetime.utcnow(),
            'emotion': emotion,
            'confidence': confidence,
            'device_id': request.headers.get('device-id'),
            'user_id': current_user['email']
        }
        
        # Save to MongoDB
        predictions_collection.insert_one(prediction_record)
        
        return jsonify({
            'emotion': emotion,
            'confidence': confidence,
            'request_id': prediction_record['request_id']
        })
        
    except Exception as e:
        logging.error(f"Error in prediction: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/history', methods=['GET'])
@token_required
def get_history(current_user):
    """
    Get prediction history
    ---
    parameters:
      - name: device_id
        in: query
        type: string
        required: false
        description: Filter by device ID
      - name: limit
        in: query
        type: integer
        required: false
        description: Number of records to return
    responses:
      200:
        description: List of predictions
    """
    try:
        device_id = request.args.get('device_id')
        limit = int(request.args.get('limit', 50))
        
        query = {}
        if device_id:
            query['device_id'] = device_id
        query['user_id'] = current_user['email']
        
        history = list(predictions_collection.find(
            query,
            {'_id': 0}
        ).sort('timestamp', -1).limit(limit))
        
        return jsonify(history)
        
    except Exception as e:
        logging.error(f"Error fetching history: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/analytics', methods=['GET'])
@token_required
def get_analytics(current_user):
    """
    Get emotion analytics
    ---
    parameters:
      - name: device_id
        in: query
        type: string
        required: false
        description: Filter by device ID
    responses:
      200:
        description: Analytics data
    """
    try:
        device_id = request.args.get('device_id')
        
        match = {'device_id': device_id} if device_id else {}
        match['user_id'] = current_user['email']
        
        pipeline = [
            {'$match': match},
            {'$group': {
                '_id': '$emotion',
                'count': {'$sum': 1},
                'avg_confidence': {'$avg': '$confidence'}
            }},
            {'$sort': {'count': -1}}
        ]
        
        analytics = list(predictions_collection.aggregate(pipeline))
        
        return jsonify(analytics)
        
    except Exception as e:
        logging.error(f"Error fetching analytics: {str(e)}")
        return jsonify({'error': str(e)}), 500

# Add user choice response functions
def get_tip():
    tips = [
        "Take a deep breath and count to 10. It helps clear your mind.",
        "Remember that every day is a new beginning.",
        "Try to find something positive in every situation.",
        "Talk to someone you trust about how you're feeling.",
        "Take a short walk outside to refresh your mind."
    ]
    
    # Filter out used tips
    available_tips = [t for t in tips if t not in _used_tips]
    
    if not available_tips:
        # Reset used tips if all have been shown
        _used_tips.clear()
        return "You've seen all the tips! Starting fresh..."
    
    # Get a random tip from available ones
    tip = random.choice(available_tips)
    _used_tips.append(tip)
    return tip

def get_story():
    stories = [
        "Once upon a time in a peaceful village,\na girl named Lila loved to plant flowers.\nOne spring, a stranger asked her why she cared.\nShe said: 'Because flowers grow hope.'\nYears later, her flowers made the village famous.\nThe End.",
        "A young boy found a lost puppy in the rain.\nHe took it home, dried it off, and gave it food.\nThe puppy became his best friend, and together they brought joy to the whole neighborhood.",
        "In a small town, an old man planted a tree every year.\nDecades later, the town was filled with shade and fruit, and everyone remembered the kindness of the old man.",
        "A girl who was afraid of the dark learned to love the stars.\nShe realized that even in darkness, there is beauty and hope.",
        "A teacher believed in a struggling student.\nWith encouragement, the student discovered a love for learning and grew up to help others in need."
    ]
    
    # Filter out used stories
    available_stories = [s for s in stories if s not in _used_stories]
    
    if not available_stories:
        # Reset used stories if all have been shown
        _used_stories.clear()
        return "You've read all the stories! Starting fresh..."
    
    # Get a random story from available ones
    story = random.choice(available_stories)
    _used_stories.append(story)
    return story

@app.route('/api/activities', methods=['GET'])
def get_activities():
    """
    Get available activities based on emotion
    ---
    parameters:
      - name: emotion
        in: query
        type: string
        required: true
        description: Current emotion
    responses:
      200:
        description: List of available activities
    """
    try:
        emotion = request.args.get('emotion')
        if not emotion:
            return jsonify({'error': 'Emotion parameter is required'}), 400

        activities = []
        if emotion not in ['happy', 'neutral']:
            activities = [
                {'id': 'tic_tac_toe', 'name': 'Play Tic Tac Toe', 'description': 'Play a game of Tic Tac Toe'},
                {'id': 'tip', 'name': 'Get a Tip', 'description': 'Receive a helpful tip'},
                {'id': 'story', 'name': 'Hear a Story', 'description': 'Listen to an uplifting story'}
            ]
        
        return jsonify({'activities': activities})
        
    except Exception as e:
        logging.error(f"Error getting activities: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/activities/tip', methods=['GET'])
def get_activity_tip():
    """Get a random tip"""
    try:
        tip = get_tip()
        return jsonify({'tip': tip})
    except Exception as e:
        logging.error(f"Error getting tip: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/activities/story', methods=['GET'])
def get_activity_story():
    """Get a story"""
    try:
        story = get_story()
        return jsonify({'story': story})
    except Exception as e:
        logging.error(f"Error getting story: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/activities/tic_tac_toe', methods=['POST'])
def play_tic_tac_toe():
    """Play a move in Tic Tac Toe"""
    try:
        data = request.get_json()
        if not data or 'board' not in data or 'move' not in data:
            return jsonify({'error': 'Invalid request data'}), 400

        board = data['board']
        move = data['move']
        
        # Validate move
        if board[move] != " ":
            return jsonify({'error': 'Invalid move'}), 400

        # Make player's move
        board[move] = "X"
        
        # Check for player win
        if check_winner(board, "X"):
            return jsonify({
                'board': board,
                'status': 'win',
                'message': 'You win!'
            })

        # Check for draw
        if " " not in board:
            return jsonify({
                'board': board,
                'status': 'draw',
                'message': "It's a draw!"
            })

        # Make computer's move
        empty_cells = [i for i in range(9) if board[i] == " "]
        if empty_cells:
            computer_move = random.choice(empty_cells)
            board[computer_move] = "O"
            
            # Check for computer win
            if check_winner(board, "O"):
                return jsonify({
                    'board': board,
                    'status': 'lose',
                    'message': 'Computer wins!'
                })

            # Check for draw after computer move
            if " " not in board:
                return jsonify({
                    'board': board,
                    'status': 'draw',
                    'message': "It's a draw!"
                })

        return jsonify({
            'board': board,
            'status': 'continue',
            'message': 'Game continues'
        })

    except Exception as e:
        logging.error(f"Error in Tic Tac Toe: {str(e)}")
        return jsonify({'error': str(e)}), 500

def check_winner(board, player):
    """Check if the player has won"""
    wins = [(0,1,2),(3,4,5),(6,7,8),(0,3,6),(1,4,7),(2,5,8),(0,4,8),(2,4,6)]
    return any(all(board[i] == player for i in combo) for combo in wins)

# Authentication routes
@app.route('/api/auth/register', methods=['POST'])
def register():
    """Register a new user"""
    try:
        data = request.get_json()
        
        # Validate required fields
        if not all(k in data for k in ['email', 'password', 'name']):
            return jsonify({'error': 'Missing required fields'}), 400
            
        # Check if user already exists
        if users_collection.find_one({'email': data['email']}):
            return jsonify({'error': 'Email already registered'}), 400
            
        # Create user document
        user = {
            'email': data['email'],
            'password': generate_password_hash(data['password']),
            'name': data['name'],
            'created_at': datetime.utcnow()
        }
        
        # Insert user into database
        users_collection.insert_one(user)
        
        return jsonify({'message': 'User registered successfully'}), 201
        
    except Exception as e:
        logging.error(f"Error in registration: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/auth/login', methods=['POST'])
def login():
    """Login user"""
    try:
        data = request.get_json()
        
        # Validate required fields
        if not all(k in data for k in ['email', 'password']):
            return jsonify({'error': 'Missing email or password'}), 400
            
        # Find user
        user = users_collection.find_one({'email': data['email']})
        if not user:
            return jsonify({'error': 'User not found'}), 401
            
        # Check password
        if not check_password_hash(user['password'], data['password']):
            return jsonify({'error': 'Invalid password'}), 401
            
        # Generate token
        token = jwt.encode({
            'email': user['email'],
            'exp': datetime.utcnow() + timedelta(days=1)
        }, app.config['SECRET_KEY'])
        
        return jsonify({
            'token': token,
            'user': {
                'email': user['email'],
                'name': user['name']
            }
        }), 200
        
    except Exception as e:
        logging.error(f"Error in login: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 5000)), debug=os.getenv('FLASK_ENV') == 'development') 