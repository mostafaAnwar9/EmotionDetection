import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_provider.dart';

class EmotionProvider with ChangeNotifier {
  String? _currentEmotion;
  double? _confidence;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;
  String? _error;
  final String _baseUrl = 'http://localhost:5000/api';

  String? get currentEmotion => _currentEmotion;
  double? get confidence => _confidence;
  List<Map<String, dynamic>> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> predictEmotion(
      List<int> imageBytes, BuildContext context) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.getToken();

      if (token == null) {
        _error = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      File? tempFile;
      try {
        // Save image bytes to temporary file
        final tempDir = await getTemporaryDirectory();
        tempFile = File('${tempDir.path}/temp_image.jpg');
        await tempFile.writeAsBytes(imageBytes);
      } catch (e) {
        debugPrint('Error creating temporary file: $e');
        // Fallback to using bytes directly
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/predict'),
        );

        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: 'image.jpg',
          ),
        );

        final response = await request.send();
        final responseData = await response.stream.bytesToString();
        final data = json.decode(responseData);

        if (response.statusCode == 200) {
          _currentEmotion = data['emotion'];
          _confidence = data['confidence'].toDouble();
          await _saveToHistory(data);
        } else {
          _error = data['error'] ?? 'Failed to predict emotion';
        }
        return;
      }

      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/predict'),
        );

        request.headers['Authorization'] = 'Bearer $token';
        request.files
            .add(await http.MultipartFile.fromPath('image', tempFile.path));

        final response = await request.send();
        final responseData = await response.stream.bytesToString();
        final data = json.decode(responseData);

        if (response.statusCode == 200) {
          _currentEmotion = data['emotion'];
          _confidence = data['confidence'].toDouble();
          await _saveToHistory(data);
        } else {
          _error = data['error'] ?? 'Failed to predict emotion';
        }
      } finally {
        // Clean up temporary file
        try {
          await tempFile?.delete();
        } catch (e) {
          debugPrint('Error deleting temporary file: $e');
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error in predictEmotion: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchHistory(BuildContext context) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.getToken();

      if (token == null) {
        _error = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/history'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _history = List<Map<String, dynamic>>.from(data);
      } else {
        _error = data['error'] ?? 'Failed to fetch history';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error in fetchHistory: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToHistory(Map<String, dynamic> prediction) async {
    _history.insert(0, prediction);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getAnalytics(BuildContext context) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.getToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/analytics'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception(data['error'] ?? 'Failed to fetch analytics');
      }
    } catch (e) {
      debugPrint('Error in getAnalytics: $e');
      throw Exception('Failed to fetch analytics: $e');
    }
  }

  void clearEmotion() {
    _currentEmotion = null;
    _error = null;
    notifyListeners();
  }
}
