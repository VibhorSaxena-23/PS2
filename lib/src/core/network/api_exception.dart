class ApiException implements Exception {
  ApiException({
    required this.message,
    required this.statusCode,
  });

  final String message;
  final int statusCode;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}
