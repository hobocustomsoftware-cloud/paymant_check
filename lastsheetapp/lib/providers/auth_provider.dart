import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  String? _authToken;
  bool _isLoading = true;

  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  AuthProvider() {
    loadUserFromStorage();
  }

  Future<void> loadUserFromStorage() async {
    _isLoading = true;
    notifyListeners();
    _authToken = await _storage.read(key: 'auth_token');
    if (_authToken != null) {
      // If token exists, try to load user details from secure storage.
      // This is crucial for maintaining user session across app restarts.
      String? userId = await _storage.read(key: 'user_id');
      String? username = await _storage.read(key: 'username');
      String? email = await _storage.read(key: 'email');
      String? userType = await _storage.read(key: 'user_type'); // Changed from 'role'

      if (userId != null && username != null && email != null && userType != null) {
        try {
          _currentUser = User(
            id: int.parse(userId),
            username: username,
            email: email,
            userType: userType, // Changed from 'role'
          );
          print('DEBUG: User loaded from storage: ID=${_currentUser!.id}, Username=${_currentUser!.username}, Type=${_currentUser!.userType}');
        } catch (e) {
          print("Error parsing user data from storage: $e");
          await logout(); // Clear invalid data
        }
      } else {
        print('DEBUG: Auth token found, but user details incomplete in storage. User will be null until re-login.');
        // If token exists but user details are incomplete, consider it not fully authenticated
        // or prompt for re-login. For now, _currentUser remains null.
      }
    } else {
      print('DEBUG: No auth token found in storage.');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentUser = await _apiService.login(username, password); // ApiService.login returns User
      _authToken = await _storage.read(key: 'auth_token'); // Get token stored by apiService

      // Store user details in secure storage for persistence across app restarts
      if (_currentUser != null) {
        await _storage.write(key: 'user_id', value: _currentUser!.id.toString());
        await _storage.write(key: 'username', value: _currentUser!.username);
        await _storage.write(key: 'email', value: _currentUser!.email);
        await _storage.write(key: 'user_type', value: _currentUser!.userType); // Changed from 'role'
        print('DEBUG: User details stored: ID=${_currentUser!.id}, Type=${_currentUser!.userType}');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow; // Rethrow to show error message in UI
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await _apiService.logout();
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'username');
    await _storage.delete(key: 'email');
    await _storage.delete(key: 'user_type'); // Changed from 'role'
    _currentUser = null;
    _authToken = null;
    _isLoading = false;
    notifyListeners();
  }
}
