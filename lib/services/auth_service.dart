import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {
  static const String _userKey = 'saved_user';

  static Future<AuthResult> login({
    required String mobile,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            ApiConfig.uri('/api/auth/surveyor-login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'mobile': mobile, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      switch (response.statusCode) {
        case 200:
          final user = body['user'] as Map<String, dynamic>;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_userKey, jsonEncode(user));
          } catch (_) {}
          return AuthResult.success(user);
        case 400:
          return AuthResult.failure('Mobile and password are required.');
        case 401:
          return AuthResult.failure('Invalid mobile number or password.');
        case 403:
          if (body['error'] == 'Account blocked') {
            return AuthResult.failure(
              'Your account has been blocked. ${body['reason'] ?? 'Contact your administrator.'}',
            );
          }
          return AuthResult.failure('Access denied. Surveyor accounts only.');
        default:
          return AuthResult.failure('Something went wrong. Please try again.');
      }
    } on TimeoutException {
      return AuthResult.failure('Request timed out. Please try again.');
    } catch (_) {
      return AuthResult.failure('Network error. Please check your connection.');
    }
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_userKey);
      if (jsonStr == null) return null;
      final user = jsonDecode(jsonStr) as Map<String, dynamic>;
      // Sessions saved before the login API was bound have no id;
      // records can't be attributed to them, so require a fresh login.
      if (user['id'] == null) return null;
      return user;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } catch (_) {}
  }
}

class AuthResult {
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic>? user;

  const AuthResult._({required this.success, this.errorMessage, this.user});

  factory AuthResult.success(Map<String, dynamic> user) =>
      AuthResult._(success: true, user: user);

  factory AuthResult.failure(String message) =>
      AuthResult._(success: false, errorMessage: message);
}
