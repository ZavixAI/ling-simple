class ApiResponse {
  const ApiResponse({
    required this.code,
    required this.message,
    required this.data,
    required this.timestamp,
  });

  final int code;
  final String message;
  final Object? data;
  final String? timestamp;

  bool get isSuccess => code >= 200 && code < 300;
  bool get isEnvelope => code != 200 || message.isNotEmpty || timestamp != null;

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      code: json['code'] is int ? json['code'] as int : 200,
      message:
          json['message']?.toString() ??
          json['detail']?.toString() ??
          json['error']?.toString() ??
          '',
      data: json['data'],
      timestamp: json['timestamp']?.toString(),
    );
  }
}
