import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

/// Thin wrapper around flutter_secure_storage.
/// Stores access token + basic user info between app restarts.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken  = 'auth_access_token';
  static const _keyUserId = 'auth_user_id';
  static const _keyEmail  = 'auth_email';
  static const _keyName   = 'auth_display_name';
  static const _keyHealthOnboarded = 'health_onboarding_completed';

  // ── Token ──────────────────────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    await _safeWrite(_keyToken, token);
  }

  Future<String?> getToken() => _safeRead(_keyToken);

  // ── User identity ──────────────────────────────────────────────────────────

  Future<void> saveUser({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    await Future.wait([
      _safeWrite(_keyUserId, userId),
      _safeWrite(_keyEmail, email),
      _safeWrite(_keyName, displayName),
    ]);
  }

  Future<String?> getUserId() => _safeRead(_keyUserId);
  Future<String?> getEmail() => _safeRead(_keyEmail);
  Future<String?> getDisplayName() => _safeRead(_keyName);

  // ── Session ────────────────────────────────────────────────────────────────

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Health onboarding gate ─────────────────────────────────────────────────

  Future<bool> isHealthOnboardingCompleted() async {
    final v = await _safeRead(_keyHealthOnboarded);
    return v == 'true';
  }

  Future<void> markHealthOnboardingCompleted() =>
      _safeWrite(_keyHealthOnboarded, 'true');

  // ── Session ────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _safeDeleteAll();
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      // Plugin may be unavailable in unit tests or unsupported runtimes.
    } on PlatformException {
      // Storage backend is unavailable; fail soft to avoid app crash.
    }
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _safeDeleteAll() async {
    try {
      await _storage.deleteAll();
    } on MissingPluginException {
      // No storage backend available.
    } on PlatformException {
      // No storage backend available.
    }
  }
}
