import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String _apiBaseUrlFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _webApiBaseUrlFromEnv = String.fromEnvironment(
    'WEB_API_BASE_URL',
    defaultValue: '',
  );

  static final String apiBaseUrl = _apiBaseUrlFromEnv.isNotEmpty
      ? _normalizeMobileApiBaseUrl(_apiBaseUrlFromEnv)
      : _defaultMobileApiBaseUrl();

  // Web service base URL — used for auth-adjacent features: gym discovery,
  // memberships, attendance, plans, subscriptions, and user profile.
  static final String webApiBaseUrl = _webApiBaseUrlFromEnv.isNotEmpty
      ? _normalizeWebApiBaseUrl(_webApiBaseUrlFromEnv)
      : _apiBaseUrlFromEnv.isNotEmpty
      ? _normalizeWebApiBaseUrl(_apiBaseUrlFromEnv)
      : _defaultWebApiBaseUrl();

  static const String userId = String.fromEnvironment(
    'FLEXICURL_USER_ID',
    defaultValue: '',
  );

  static String _defaultMobileApiBaseUrl() => kIsWeb
      ? 'http://localhost:8000/mobile/api/v1'
      : kReleaseMode
      ? 'https://api.flexicurl.fit/mobile/api/v1'
      : defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8000/mobile/api/v1'
      : 'http://localhost:8000/mobile/api/v1';

  static String _defaultWebApiBaseUrl() => kIsWeb
      ? 'http://localhost:8000/api/v1'
      : kReleaseMode
      ? 'https://api.flexicurl.fit/api/v1'
      : defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8000/api/v1'
      : 'http://localhost:8000/api/v1';

  static String _normalizeMobileApiBaseUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return uri.replace(pathSegments: ['mobile', 'api', 'v1']).toString();
    }

    if (segments.length >= 3 &&
        segments[segments.length - 3] == 'mobile' &&
        segments[segments.length - 2] == 'api' &&
        segments.last == 'v1') {
      return uri.replace(pathSegments: segments).toString();
    }

    if (segments.length >= 2 &&
        segments[segments.length - 2] == 'api' &&
        segments.last == 'v1') {
      if (segments.first == 'mobile') {
        return uri.replace(pathSegments: segments).toString();
      }
      return uri.replace(pathSegments: ['mobile', ...segments]).toString();
    }

    if (segments.length == 1 && segments.first == 'mobile') {
      return uri.replace(pathSegments: ['mobile', 'api', 'v1']).toString();
    }

    if (segments.length == 1 && segments.first == 'api') {
      return uri.replace(pathSegments: ['mobile', 'api', 'v1']).toString();
    }

    if (segments.length == 2 &&
        segments.first == 'mobile' &&
        segments.last == 'api') {
      return uri.replace(pathSegments: ['mobile', 'api', 'v1']).toString();
    }

    if (segments.length == 2 &&
        segments.first == 'api' &&
        segments.last == 'v1') {
      return uri.replace(pathSegments: ['mobile', 'api', 'v1']).toString();
    }

    if (segments.length >= 2 &&
        segments.first == 'mobile' &&
        segments[1] != 'api') {
      return uri.replace(pathSegments: ['mobile', 'api', 'v1']).toString();
    }

    if (!_looksLikeApiV1Base(uri)) return baseUrl;

    if (segments.isNotEmpty && segments.first == 'mobile') {
      return uri.replace(pathSegments: segments).toString();
    }

    return uri.replace(pathSegments: ['mobile', ...segments]).toString();
  }

  static String _normalizeWebApiBaseUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return uri.replace(pathSegments: ['api', 'v1']).toString();
    }

    if (segments.length >= 2 &&
        segments[segments.length - 2] == 'api' &&
        segments.last == 'v1') {
      if (segments.first == 'mobile') {
        return uri.replace(pathSegments: segments.skip(1).toList()).toString();
      }
      return uri.replace(pathSegments: segments).toString();
    }

    if (segments.length == 1 && segments.first == 'mobile') {
      return uri.replace(pathSegments: ['api', 'v1']).toString();
    }

    if (segments.length == 1 && segments.first == 'api') {
      return uri.replace(pathSegments: ['api', 'v1']).toString();
    }

    if (segments.length == 2 &&
        segments.first == 'mobile' &&
        segments.last == 'api') {
      return uri.replace(pathSegments: ['api', 'v1']).toString();
    }

    if (segments.length == 2 &&
        segments.first == 'mobile' &&
        segments.last == 'v1') {
      return uri.replace(pathSegments: ['api', 'v1']).toString();
    }

    if (!_looksLikeApiV1Base(uri)) return baseUrl;

    if (segments.isEmpty || segments.first != 'mobile') {
      return uri.replace(pathSegments: segments).toString();
    }

    return uri.replace(pathSegments: segments.skip(1).toList()).toString();
  }

  static bool _looksLikeApiV1Base(Uri uri) {
    final segments = uri.pathSegments;
    return segments.length >= 2 &&
        segments[segments.length - 2] == 'api' &&
        segments.last == 'v1';
  }

  static bool _isLocalUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
  }

  static bool get isUsingLocalBackend =>
      _isLocalUri(apiBaseUrl) || _isLocalUri(webApiBaseUrl);
}
