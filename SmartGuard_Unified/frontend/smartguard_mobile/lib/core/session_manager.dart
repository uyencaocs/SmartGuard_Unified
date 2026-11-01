import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class SessionManager {
  static const _storage = FlutterSecureStorage();

  static const _keyToken = 'sg_jwt_token';
  static const _keyUser = 'sg_user_info';
  static const _keyBiometricEnabled = 'sg_biometric_enabled';

  static String? _cachedToken;
  static Map<String, dynamic>? _cachedUser;

  static String? get token => _cachedToken;
  static bool get isLoggedIn => _cachedToken != null && _cachedToken!.isNotEmpty;
  static bool get isAdmin => _cachedUser?['role']?.toString().toLowerCase() == 'admin';
  static String get role => _cachedUser?['role']?.toString() ?? 'Owner';
  static String get username => _cachedUser?['username']?.toString() ?? 'Người dùng';
  static String get email => _cachedUser?['email']?.toString() ?? '';
  static String get userId => _cachedUser?['userId']?.toString() ?? '';

  static Future<UserModel?> getCurrentUser() async {
    if (_cachedUser == null) {
      await init();
    }
    if (_cachedUser == null) return null;
    return UserModel.fromJson(_cachedUser!);
  }

  static Future<void> init() async {
    try {
      _cachedToken = await _storage.read(key: _keyToken);
      final userJson = await _storage.read(key: _keyUser);
      if (userJson != null) {
        _cachedUser = jsonDecode(userJson) as Map<String, dynamic>;
      }
    } catch (_) {
      _cachedToken = null;
      _cachedUser = null;
    }
  }

  static Future<void> saveSession({
    required String token,
    required String userId,
    required String email,
    required String username,
    required String role,
  }) async {
    _cachedToken = token;
    _cachedUser = {
      'userId': userId,
      'email': email,
      'username': username,
      'role': role,
    };

    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUser, value: jsonEncode(_cachedUser));
  }

  static Future<void> clearSession() async {
    _cachedToken = null;
    _cachedUser = null;
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyUser);
  }

  static Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _keyBiometricEnabled);
    return val == 'true';
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled ? 'true' : 'false');
  }
}
