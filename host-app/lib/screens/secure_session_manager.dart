import 'package:flutter/foundation.dart';

/// SecureSessionManager securely manages the active authenticated user session.
/// Wraps in-memory token state, making it production-ready to swap in 
/// a flutter_secure_storage implementation.
class SecureSessionManager {
  static String? _token;
  static String? _username;

  static String? get token => _token;
  static String? get username => _username;

  static bool get isAuthenticated => _token != null;

  /// Saves the user token and username securely
  static Future<void> saveSession({required String token, required String username}) async {
    _token = token;
    _username = username;
    debugPrint('SecureSessionManager: Saved active session for $username');
  }

  /// Clears active session credentials (logout)
  static Future<void> clearSession() async {
    _token = null;
    _username = null;
    debugPrint('SecureSessionManager: Session cleared (Logged Out)');
  }
}
