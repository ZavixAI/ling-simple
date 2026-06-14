import 'dart:collection';

enum LogLevel { debug, info, warn, error }

class LogEvent {
  const LogEvent({
    required this.id,
    required this.level,
    required this.category,
    required this.message,
    required this.fields,
    required this.createdAt,
    this.stackTrace,
  });

  final String id;
  final LogLevel level;
  final String category;
  final String message;
  final Map<String, Object?> fields;
  final String? stackTrace;
  final DateTime createdAt;

  String get levelLabel => switch (level) {
    LogLevel.debug => 'DEBUG',
    LogLevel.info => 'INFO',
    LogLevel.warn => 'WARN',
    LogLevel.error => 'ERROR',
  };

  LogEvent copyWith({
    String? id,
    LogLevel? level,
    String? category,
    String? message,
    Map<String, Object?>? fields,
    String? stackTrace,
    bool clearStackTrace = false,
    DateTime? createdAt,
  }) {
    return LogEvent(
      id: id ?? this.id,
      level: level ?? this.level,
      category: category ?? this.category,
      message: message ?? this.message,
      fields: fields ?? this.fields,
      stackTrace: clearStackTrace ? null : (stackTrace ?? this.stackTrace),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'level': levelLabel,
      'category': category,
      'message': message,
      'fields': Map<String, Object?>.from(fields),
      'stack_trace': stackTrace,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory LogEvent.fromJson(Map<String, dynamic> json) {
    final levelRaw = '${json['level'] ?? 'INFO'}'.trim().toUpperCase();
    return LogEvent(
      id: '${json['id'] ?? ''}'.trim(),
      level: switch (levelRaw) {
        'DEBUG' => LogLevel.debug,
        'WARN' => LogLevel.warn,
        'ERROR' => LogLevel.error,
        _ => LogLevel.info,
      },
      category: '${json['category'] ?? 'ui'}'.trim(),
      message: '${json['message'] ?? ''}',
      fields: _normalizeFields(json['fields']),
      stackTrace: _normalizeNullableString(json['stack_trace']),
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
    );
  }

  static Map<String, Object?> _normalizeFields(Object? value) {
    if (value is Map<String, Object?>) {
      return UnmodifiableMapView<String, Object?>(value);
    }
    if (value is Map) {
      return UnmodifiableMapView<String, Object?>(
        value.map((key, item) => MapEntry('${key ?? ''}', item)),
      );
    }
    return const <String, Object?>{};
  }

  static String? _normalizeNullableString(Object? value) {
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }
}
