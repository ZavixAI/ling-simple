class ApiException implements Exception {
  ApiException({required this.message, this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    return 'ApiException(message: $message, statusCode: $statusCode, cause: $cause)';
  }
}
