import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _userKey = 'saved_user';

  /// TODO: Bind the new login API here.
  /// Currently accepts any credentials and stores a local session so the
  /// rest of the app can be used while the backend is being wired up.
  static Future<AuthResult> login({
    required String mobile,
    required String password,
  }) async {
    final user = <String, dynamic>{
      'id': null,
      'name': 'Surveyor',
      'mobile': mobile,
      'role': 'surveyor',
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    } catch (_) {}

    return AuthResult.success(user);
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_userKey);
      if (jsonStr == null) return null;
      return jsonDecode(jsonStr) as Map<String, dynamic>;
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
