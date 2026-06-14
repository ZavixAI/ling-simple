import 'package:flutter/foundation.dart';
import 'package:ling/src/core/logging/log_event.dart';

typedef AppLogSink = void Function(LogEvent event);

class AppLogger {
  const AppLogger._();

  static const int _maxBacklogSize = 500;

  static final List<LogEvent> _backlog = <LogEvent>[];
  static final Map<Object, AppLogSink> _sinks = <Object, AppLogSink>{};
  static int _sequence = 0;
  static bool _isWritingToConsole = false;
  static bool _consoleOutputEnabled = true;

  static bool get isWritingToConsole => _isWritingToConsole;

  static void setConsoleOutputEnabled(bool enabled) {
    _consoleOutputEnabled = enabled;
  }

  static Object registerSink(AppLogSink sink, {bool replayBacklog = true}) {
    final token = Object();
    _sinks[token] = sink;
    if (replayBacklog) {
      for (final event in List<LogEvent>.from(_backlog)) {
        sink(event);
      }
    }
    return token;
  }

  static void unregisterSink(Object token) {
    _sinks.remove(token);
  }

  static void debug(
    String message, {
    String category = 'ui',
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    _log(
      level: LogLevel.debug,
      message: message,
      category: category,
      fields: fields,
    );
  }

  static void info(
    String message, {
    String category = 'ui',
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    _log(
      level: LogLevel.info,
      message: message,
      category: category,
      fields: fields,
    );
  }

  static void warn(
    String message, {
    String category = 'ui',
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    _log(
      level: LogLevel.warn,
      message: message,
      category: category,
      fields: fields,
    );
  }

  static void error(
    String message, {
    StackTrace? stackTrace,
    String category = 'error',
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    _log(
      level: LogLevel.error,
      message: message,
      category: category,
      fields: fields,
      stackTrace: stackTrace,
    );
  }

  static void captureConsoleLine(String message, {String category = 'zone'}) {
    _dispatch(
      LogEvent(
        id: _nextLogId(),
        level: LogLevel.info,
        category: category,
        message: message,
        fields: const <String, Object?>{},
        createdAt: DateTime.now(),
      ),
      includeConsole: false,
    );
  }

  static void _log({
    required LogLevel level,
    required String message,
    required String category,
    required Map<String, Object?> fields,
    StackTrace? stackTrace,
  }) {
    final event = LogEvent(
      id: _nextLogId(),
      level: level,
      category: category,
      message: message,
      fields: Map<String, Object?>.unmodifiable(
        Map<String, Object?>.from(fields),
      ),
      stackTrace: stackTrace?.toString(),
      createdAt: DateTime.now(),
    );
    _dispatch(event, includeConsole: true);
  }

  static void _dispatch(LogEvent event, {required bool includeConsole}) {
    _backlog.add(event);
    if (_backlog.length > _maxBacklogSize) {
      _backlog.removeAt(0);
    }

    if (includeConsole && _consoleOutputEnabled) {
      _isWritingToConsole = true;
      try {
        debugPrint('[${event.levelLabel}] ${event.message}');
        if (event.stackTrace != null && event.stackTrace!.trim().isNotEmpty) {
          debugPrint(event.stackTrace);
        }
      } finally {
        _isWritingToConsole = false;
      }
    }

    for (final sink in _sinks.values) {
      try {
        sink(event);
      } catch (_) {
        // Keep logging non-fatal even if one sink fails.
      }
    }
  }

  static String _nextLogId() {
    _sequence += 1;
    return 'log_${DateTime.now().microsecondsSinceEpoch}_$_sequence';
  }
}
