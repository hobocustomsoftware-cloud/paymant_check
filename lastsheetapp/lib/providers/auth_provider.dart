import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  String? _authToken;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  AuthProvider() {
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    _isLoading = true;
    notifyListeners();
    try {
      _authToken = await _storage.read(key: 'auth_token');
      if (_authToken != null) {
        // If a token is found, try to get user info.
        // The isAuthenticated status should depend on both token and user data.
        await loadUserFromStorage();
        if (_currentUser != null) {
          _isAuthenticated = true;
        }
      } else {
        print('DEBUG: No auth token found in storage.');
        _isAuthenticated = false;
      }
    } catch (e) {
      print('Error during auth token retrieval: $e');
      _isAuthenticated = false;
      await logout(); // Clear any corrupted data
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserFromStorage() async {
    try {
      String? userId = await _storage.read(key: 'user_id');
      String? username = await _storage.read(key: 'username');
      String? email = await _storage.read(key: 'email');
      String? userType = await _storage.read(key: 'user_type');

      if (userId != null &&
          username != null &&
          email != null &&
          userType != null) {
        _currentUser = User(
          id: int.parse(userId),
          username: username,
          email: email,
          userType: userType,
        );
        print(
          'DEBUG: User loaded from storage: ID=${_currentUser!.id}, Username=${_currentUser!.username}, Type=${_currentUser!.userType}',
        );
      } else {
        _currentUser = null;
        print('DEBUG: Incomplete user details in storage. User will be null.');
      }
    } catch (e) {
      print("Error parsing user data from storage: $e");
      _currentUser = null;
      await logout();
    }
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
    try {
      _currentUser = await _apiService.login(username, password);
      _authToken = await _storage.read(key: 'auth_token');

      if (_currentUser != null && _authToken != null) {
        await _storage.write(
          key: 'user_id',
          value: _currentUser!.id.toString(),
        );
        await _storage.write(key: 'username', value: _currentUser!.username);
        await _storage.write(key: 'email', value: _currentUser!.email);
        await _storage.write(key: 'user_type', value: _currentUser!.userType);
        _isAuthenticated = true;
        print('DEBUG: User details stored and authentication successful.');
      } else {
        print('DEBUG: Login failed. API did not return user or token.');
        await logout(); // Clean up if login fails
      }
    } catch (e) {
      print('DEBUG: Login process failed with an error: $e');
      await logout(); // Ensure a clean state on error
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    _isAuthenticated = false;
    _currentUser = null;
    _authToken = null;

    // Deleting all stored data
    await _storage.deleteAll();
    await _apiService.logout(); // Call API to revoke token

    _isLoading = false;
    notifyListeners();
    print('DEBUG: User logged out and storage cleared.');
  }
}
