import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/auth/data/auth_api.dart';
import '../../features/auth/data/auth_service.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.userId,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String userId;
  final http.Client _httpClient;

  // ── Public HTTP methods ───────────────────────────────────────────────────

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _withAutoRefresh(
        () => _rawGet(path, queryParameters: queryParameters),
      );

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
  }) =>
      _withAutoRefresh(
        () => _rawPost(path, body: body, queryParameters: queryParameters),
      );

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _withAutoRefresh(() => _rawPatch(path, body: body));

  Future<void> delete(String path) =>
      _withAutoRefresh(() => _rawDelete(path));

  void dispose() => _httpClient.close();

  // ── Auto-refresh wrapper ──────────────────────────────────────────────────

  /// Executes [call]. On 401, attempts one token refresh then retries once.
  /// If the refresh itself fails, clears auth state and rethrows.
  Future<T> _withAutoRefresh<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;

      // Try to refresh
      try {
        final newToken = await AuthApi.instance.refresh();
        await AuthService.instance.saveToken(newToken);
      } catch (_) {
        // Refresh failed — clear session, let caller handle it
        await AuthService.instance.clearAll();
        rethrow;
      }

      // Retry original call once with fresh token
      return await call();
    }
  }

  // ── Raw request methods (no retry logic) ─────────────────────────────────

  Future<dynamic> _rawGet(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters: queryParameters);
    try {
      final headers = await _headers();
      final response = await _httpClient.get(uri, headers: headers);
      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } on Exception {
      throw ApiException(
        message:
            'Cannot reach server. Check your internet connection and try again.',
        statusCode: -1,
      );
    }
  }

  Future<dynamic> _rawPost(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters: queryParameters);
    try {
      final headers = await _headers();
      final response = await _httpClient.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } on Exception {
      throw ApiException(
        message:
            'Cannot reach server. Check your internet connection and try again.',
        statusCode: -1,
      );
    }
  }

  Future<dynamic> _rawPatch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    try {
      final headers = await _headers();
      final response = await _httpClient.patch(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } on Exception {
      throw ApiException(
        message:
            'Cannot reach server. Check your internet connection and try again.',
        statusCode: -1,
      );
    }
  }

  Future<void> _rawDelete(String path) async {
    final uri = _buildUri(path);
    try {
      final headers = await _headers();
      final response = await _httpClient.delete(uri, headers: headers);
      _decodeResponse(response);
    } on ApiException {
      rethrow;
    } on Exception {
      throw ApiException(
        message:
            'Cannot reach server. Check your internet connection and try again.',
        statusCode: -1,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uri _buildUri(String path, {Map<String, dynamic>? queryParameters}) {
    final base = Uri.parse(baseUrl);
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final incomingPath = path.startsWith('/') ? path.substring(1) : path;
    final mergedPath = '$basePath/$incomingPath';

    final query = queryParameters?.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    return base.replace(
      path: mergedPath,
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
  }

  /// Returns headers with Bearer token if available, else falls back to
  /// X-User-Id when a client user id is available.
  Future<Map<String, String>> _headers() async {
    final token = await AuthService.instance.getToken();
    final resolvedUserId = userId.trim();
    return {
      'content-type': 'application/json',
      'accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token'
      else if (resolvedUserId.isNotEmpty)
        'X-User-Id': userId,
    };
  }

  dynamic _decodeResponse(http.Response response) {
    final dynamic payload = _tryDecodeJson(response.bodyBytes);
    final isSuccess =
        response.statusCode >= 200 && response.statusCode < 300;

    if (!isSuccess) {
      final serverMessage = _extractErrorMessage(payload);
      final message = _toUserFacingMessage(
        response.statusCode,
        serverMessage,
      );
      throw ApiException(message: message, statusCode: response.statusCode);
    }

    return payload;
  }

  dynamic _tryDecodeJson(List<int> bodyBytes) {
    if (bodyBytes.isEmpty) return null;
    final decoded = utf8.decode(bodyBytes).trim();
    if (decoded.isEmpty) return null;
    try {
      return jsonDecode(decoded);
    } catch (_) {
      return decoded;
    }
  }

  String? _extractErrorMessage(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final detail = payload['detail'];
      // Structured error: {"detail": {"code": "...", "message": "..."}}
      if (detail is Map) {
        final msg = detail['message'];
        if (msg is String && msg.trim().isNotEmpty) return msg;
      }
      if (detail is String && detail.trim().isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        return detail.map((i) => i.toString()).join(', ');
      }
    }
    if (payload is String && payload.trim().isNotEmpty) return payload;
    return null;
  }

  String _toUserFacingMessage(int statusCode, String? serverMessage) {
    final cleanMessage = (serverMessage ?? '').trim();
    final lowerMessage = cleanMessage.toLowerCase();

    switch (statusCode) {
      case 401:
        return 'Your session expired. Please sign in again.';
      case 403:
        if (lowerMessage.contains('not verified') ||
            lowerMessage.contains('verify')) {
          return 'Please verify your account with OTP to continue.';
        }
        return cleanMessage.isNotEmpty
            ? cleanMessage
            : 'You do not have permission for this action.';
      case 404:
        if (cleanMessage.isEmpty || lowerMessage == 'not found') {
          return 'This feature is not available right now.';
        }
        return cleanMessage;
      case 409:
        return cleanMessage.isNotEmpty
            ? cleanMessage
            : 'This action has already been completed.';
      case 422:
        return cleanMessage.isNotEmpty
            ? cleanMessage
            : 'Some details are invalid. Please review and try again.';
      case 503:
        if (cleanMessage.isEmpty || lowerMessage == 'service unavailable') {
          return 'Service is temporarily unavailable. Please try again shortly.';
        }
        return cleanMessage;
      default:
        if (statusCode >= 500) {
          if (cleanMessage.isEmpty ||
              lowerMessage == 'internal server error' ||
              lowerMessage == 'unexpected server error') {
            return 'Server is having trouble right now. Please try again.';
          }
          return cleanMessage;
        }
        return cleanMessage.isNotEmpty
            ? cleanMessage
            : 'Something went wrong. Please try again.';
    }
  }
}
