import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _baseUrl =
      'https://adminsurveyapp.vercel.app/api/auth/surveyor-login';
  static const String _userKey = 'saved_user';

  static Future<AuthResult> login({
    required String mobile,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile': mobile, 'password': password}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      switch (response.statusCode) {
        case 200:
          // Save user locally for persistent login
          try {
            final prefs = await SharedPreferences.getInstance();
            final userJson = jsonEncode(body['user']);
            await prefs.setString(_userKey, userJson);
          } catch (_) {}

          return AuthResult.success(body['user'] as Map<String, dynamic>);
        case 400:
          return AuthResult.failure('Mobile and password are required.');
        case 401:
          return AuthResult.failure('Invalid mobile number or password.');
        case 403:
          final message = body['message'] as String? ?? '';
          if (message.toLowerCase().contains('block')) {
            return AuthResult.failure(
              'Your account has been blocked. Contact support.',
            );
          }
          return AuthResult.failure(
            'Access denied. Surveyor accounts only.',
          );
        default:
          return AuthResult.failure('Something went wrong. Please try again.');
      }
    } catch (_) {
      return AuthResult.failure(
        'Network error. Please check your connection.',
      );
    }
  }

    static Future<Map<String, dynamic>?> getSavedUser() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = prefs.getString(_userKey);
        if (jsonStr == null) return null;
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded;
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

  const AuthResult._({
    required this.success,
    this.errorMessage,
    this.user,
  });

  factory AuthResult.success(Map<String, dynamic> user) =>
      AuthResult._(success: true, user: user);

  factory AuthResult.failure(String message) =>
      AuthResult._(success: false, errorMessage: message);
}


