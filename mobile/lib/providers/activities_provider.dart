import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ActivitiesProvider with ChangeNotifier {
  final String _baseUrl = 'http://192.168.8.26:5000/api';
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = false;
  String? _error;
  List<String> _board = List.filled(9, " ");
  String? _gameStatus;
  String? _gameMessage;

  List<Map<String, dynamic>> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get board => _board;
  String? get gameStatus => _gameStatus;
  String? get gameMessage => _gameMessage;

  Future<void> fetchActivities(String emotion) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.get(
        Uri.parse('$_baseUrl/activities?emotion=$emotion'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _activities = List<Map<String, dynamic>>.from(data['activities']);
      } else {
        _error = 'Failed to fetch activities';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error in fetchActivities: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> getTip() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.get(Uri.parse('$_baseUrl/activities/tip'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['tip'];
      } else {
        _error = 'Failed to get tip';
        return null;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error in getTip: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> getStory() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/activities/story'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['story'];
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error in getStory: $e');
      return null;
    }
  }

  Future<bool> makeMove(int position) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.post(
        Uri.parse('$_baseUrl/activities/tic_tac_toe'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'board': _board,
          'move': position,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _board = List<String>.from(data['board']);
        _gameStatus = data['status'];
        _gameMessage = data['message'];

        if (_gameStatus != 'continue') {
          // Reset board after game ends
          Future.delayed(const Duration(seconds: 2), () {
            _board = List.filled(9, " ");
            _gameStatus = null;
            _gameMessage = null;
            notifyListeners();
          });
        }
        return true;
      } else {
        _error = 'Failed to make move';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error in makeMove: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetGame() {
    _board = List.filled(9, " ");
    _gameStatus = null;
    _gameMessage = null;
    notifyListeners();
  }
}
