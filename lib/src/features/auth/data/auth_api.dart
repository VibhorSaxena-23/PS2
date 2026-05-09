import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import 'auth_models.dart';
import 'auth_service.dart';

/// Dedicated HTTP client for the auth service.
/// Uses Dio + PersistCookieJar so the HttpOnly refresh_token cookie
/// is stored on disk and sent automatically on /auth/refresh calls.
class AuthApi {
  AuthApi._();

  static final AuthApi instance = AuthApi._();

  Dio? _dio;
  PersistCookieJar? _cookieJar;

  // Auth is mounted on the gateway at port 8000 (same server as mobile APIs).
  // Path: /api/v1/auth/...
  static String get _baseUrl {
    const fromEnv = String.fromEnvironment('AUTH_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return _ensureAuthSuffix(fromEnv);
    }
    return _ensureAuthSuffix(AppConfig.webApiBaseUrl);
  }

  static String _ensureAuthSuffix(String base) {
    final uri = Uri.parse(base);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && segments.last == 'auth') {
      return uri.replace(pathSegments: segments).toString();
    }
    return uri.replace(pathSegments: [...segments, 'auth']).toString();
  }

  Future<Dio> _client() async {
    if (_dio != null) return _dio!;

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (_) => true, // handle errors manually
      // Web: send HttpOnly cookies cross-origin (refresh_token)
      extra: kIsWeb ? {'withCredentials': true} : {},
    ));

    // Web: browser manages cookies natively — PersistCookieJar uses file I/O
    // which doesn't exist on web, so skip it entirely.
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      _cookieJar = PersistCookieJar(
        storage: FileStorage('${dir.path}/.cookies/'),
      );
      _dio!.interceptors.add(CookieManager(_cookieJar!));
    }

    return _dio!;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final dio = await _client();
    final res = await dio.post(path, data: body);
    _assertOk(res);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    String? bearerToken,
  }) async {
    final dio = await _client();
    final res = await dio.get(
      path,
      options: Options(
        headers: bearerToken != null
            ? {'Authorization': 'Bearer $bearerToken'}
            : null,
      ),
    );
    _assertOk(res);
    return Map<String, dynamic>.from(res.data as Map);
  }

  void _assertOk(Response res) {
    if (res.statusCode != null &&
        res.statusCode! >= 200 &&
        res.statusCode! < 300) {
      return;
    }

    final data = res.data;
    String message = 'Request failed (${res.statusCode})';
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map && detail['message'] != null) {
        message = detail['message'].toString();
      } else if (detail is String) {
        message = detail;
      }
    }
    throw AuthException(message: message, statusCode: res.statusCode ?? -1);
  }

  // ── Auth endpoints ─────────────────────────────────────────────────────────

  Future<LoginResponse> login(LoginRequest req) async {
    final json = await _post('/login', req.toJson());
    return LoginResponse.fromJson(json);
  }

  Future<RegisterResponse> register(RegisterRequest req) async {
    final json = await _post('/register', req.toJson());
    return RegisterResponse.fromJson(json);
  }

  Future<void> requestOtp(OtpRequest req) async {
    await _post('/request-otp', req.toJson());
  }

  Future<VerifyOtpResponse> verifyOtp(VerifyOtpRequest req) async {
    final json = await _post('/verify-otp', req.toJson());
    return VerifyOtpResponse.fromJson(json);
  }

  Future<String> refresh() async {
    final json = await _post('/refresh', {});
    final token = json['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const AuthException(
          message: 'Refresh failed: no token in response', statusCode: 401);
    }
    return token;
  }

  Future<void> logout() async {
    try {
      await _post('/logout', {});
    } catch (_) {
      // Even if server rejects, clear local state
    }
  }

  Future<AuthUser> getMe(String token) async {
    final json = await _get('/me', bearerToken: token);
    return AuthUser.fromJson(json);
  }

  Future<void> forgotPassword(ForgotPasswordRequest req) async {
    await _post('/forgot-password', req.toJson());
  }

  Future<VerifyOtpResponse> verifyForgotPasswordOtp(
      VerifyOtpRequest req) async {
    final json = await _post('/forgot-password/verify-otp', req.toJson());
    return VerifyOtpResponse.fromJson(json);
  }

  Future<void> resetPassword(ResetPasswordRequest req) async {
    await _post('/reset-password', req.toJson());
  }
}

// ── Auth-specific exception ────────────────────────────────────────────────────

class AuthException implements Exception {
  const AuthException({required this.message, required this.statusCode});
  final String message;
  final int statusCode;

  bool get isInvalidCredentials => statusCode == 401;
  bool get isInvalidOtp => message.toLowerCase().contains('otp') ||
      message.toLowerCase().contains('invalid');

  @override
  String toString() => 'AuthException($statusCode): $message';
}

// ── Save helpers used from multiple screens ────────────────────────────────────

Future<void> saveAuthState({
  required String token,
  required AuthApi authApi,
}) async {
  await AuthService.instance.saveToken(token);
  try {
    final user = await authApi.getMe(token);
    final emailOrPhone = user.email ?? user.phoneNumber ?? '';
    final displayName = user.fullName.isNotEmpty ? user.fullName : emailOrPhone;
    await AuthService.instance.saveUser(
      userId: user.id,
      email: emailOrPhone,
      displayName: displayName,
    );
  } catch (_) {
    // Non-fatal: token is saved, user info can be fetched later
  }
}
