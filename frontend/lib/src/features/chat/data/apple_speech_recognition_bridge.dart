import 'dart:async';

import 'package:flutter/services.dart';

import 'package:ling/src/core/platform/app_platform.dart';

enum SpeechAuthorizationState {
  granted,
  notDetermined,
  denied,
  restricted,
  unsupported,
  unknown,
}

String serializeSpeechAuthorizationState(SpeechAuthorizationState state) {
  switch (state) {
    case SpeechAuthorizationState.granted:
      return 'granted';
    case SpeechAuthorizationState.notDetermined:
      return 'not_determined';
    case SpeechAuthorizationState.denied:
      return 'denied';
    case SpeechAuthorizationState.restricted:
      return 'restricted';
    case SpeechAuthorizationState.unsupported:
      return 'unsupported';
    case SpeechAuthorizationState.unknown:
      return 'unknown';
  }
}

enum SpeechEventType {
  listening,
  processing,
  partialResult,
  finalResult,
  cancelled,
  error,
}

class SpeechRecognitionSessionConfig {
  const SpeechRecognitionSessionConfig({
    required this.appkey,
    required this.token,
    required this.gateway,
    this.expiresAt,
  });

  final String appkey;
  final String token;
  final String gateway;
  final DateTime? expiresAt;
}

class SpeechEvent {
  const SpeechEvent({
    required this.type,
    this.transcript = '',
    this.audioPath = '',
    this.message = '',
  });

  final SpeechEventType type;
  final String transcript;
  final String audioPath;
  final String message;

  factory SpeechEvent.fromJson(Map<Object?, Object?> json) {
    return SpeechEvent(
      type: _mapType('${json['type'] ?? ''}'),
      transcript: '${json['transcript'] ?? ''}',
      audioPath: '${json['audioPath'] ?? ''}',
      message: '${json['message'] ?? ''}',
    );
  }

  static SpeechEventType _mapType(String raw) {
    switch (raw) {
      case 'listening':
        return SpeechEventType.listening;
      case 'processing':
        return SpeechEventType.processing;
      case 'partial_result':
        return SpeechEventType.partialResult;
      case 'final_result':
        return SpeechEventType.finalResult;
      case 'cancelled':
        return SpeechEventType.cancelled;
      default:
        return SpeechEventType.error;
    }
  }
}

typedef AppleSpeechAuthorizationState = SpeechAuthorizationState;
typedef AppleSpeechEventType = SpeechEventType;
typedef AppleSpeechEvent = SpeechEvent;
typedef AppleSpeechRecognitionSessionConfig = SpeechRecognitionSessionConfig;

abstract interface class SpeechRecognitionBridge {
  Stream<SpeechEvent> events();
  Future<SpeechAuthorizationState> getAuthorizationState();
  Future<SpeechAuthorizationState> requestMicrophonePermission();
  Future<void> startRecognition({
    required String locale,
    SpeechRecognitionSessionConfig? config,
  });
  Future<void> stopRecognition();
  Future<void> cancelRecognition();
  Future<Duration> getPreviewDuration({required String path});
  Future<Duration> playPreview({required String path});
  Future<void> stopPreview();
  Future<void> openSystemSettings();
}

typedef AppleSpeechRecognitionBridge = SpeechRecognitionBridge;

class MethodChannelSpeechRecognitionBridge implements SpeechRecognitionBridge {
  MethodChannelSpeechRecognitionBridge();

  static const MethodChannel _methodChannel = MethodChannel(
    'ling/apple_speech_recognition',
  );
  static const EventChannel _eventChannel = EventChannel(
    'ling/apple_speech_recognition/events',
  );

  bool get _isSupported => AppPlatformInfo.current == AppPlatform.ios;

  @override
  Stream<SpeechEvent> events() {
    if (!_isSupported) {
      return const Stream<SpeechEvent>.empty();
    }
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      final json = event is Map
          ? Map<Object?, Object?>.from(event)
          : const <Object?, Object?>{};
      return SpeechEvent.fromJson(json);
    });
  }

  @override
  Future<SpeechAuthorizationState> getAuthorizationState() async {
    if (!_isSupported) {
      return SpeechAuthorizationState.unsupported;
    }
    final value = await _methodChannel.invokeMethod<String>(
      'getAuthorizationState',
    );
    return _mapAuthorizationState(value);
  }

  @override
  Future<SpeechAuthorizationState> requestMicrophonePermission() async {
    if (!_isSupported) {
      return SpeechAuthorizationState.unsupported;
    }
    final value = await _methodChannel.invokeMethod<String>(
      'requestMicrophonePermission',
    );
    return _mapAuthorizationState(value);
  }

  @override
  Future<void> startRecognition({
    required String locale,
    SpeechRecognitionSessionConfig? config,
  }) async {
    if (!_isSupported) {
      throw PlatformException(
        code: 'unsupported',
        message: 'Speech recognition is only available on iOS.',
      );
    }
    await _methodChannel.invokeMethod<void>('startRecognition', {
      'locale': locale,
      if (config != null) ...{
        'appkey': config.appkey,
        'token': config.token,
        'gateway': config.gateway,
      },
    });
  }

  @override
  Future<void> stopRecognition() async {
    if (!_isSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('stopRecognition');
  }

  @override
  Future<void> cancelRecognition() async {
    if (!_isSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('cancelRecognition');
  }

  @override
  Future<Duration> getPreviewDuration({required String path}) async {
    if (!_isSupported || path.trim().isEmpty) {
      return Duration.zero;
    }
    final seconds = await _methodChannel.invokeMethod<double>(
      'getPreviewDuration',
      {'path': path},
    );
    return Duration(milliseconds: ((seconds ?? 0) * 1000).round());
  }

  @override
  Future<Duration> playPreview({required String path}) async {
    if (!_isSupported || path.trim().isEmpty) {
      return Duration.zero;
    }
    final seconds = await _methodChannel.invokeMethod<double>('playPreview', {
      'path': path,
    });
    return Duration(milliseconds: ((seconds ?? 0) * 1000).round());
  }

  @override
  Future<void> stopPreview() async {
    if (!_isSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('stopPreview');
  }

  @override
  Future<void> openSystemSettings() async {
    if (!_isSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('openSystemSettings');
  }

  SpeechAuthorizationState _mapAuthorizationState(String? value) {
    switch (value) {
      case 'granted':
        return SpeechAuthorizationState.granted;
      case 'denied':
        return SpeechAuthorizationState.denied;
      case 'restricted':
        return SpeechAuthorizationState.restricted;
      case 'not_determined':
        return SpeechAuthorizationState.notDetermined;
      default:
        return SpeechAuthorizationState.unsupported;
    }
  }
}

typedef MethodChannelAppleSpeechRecognitionBridge =
    MethodChannelSpeechRecognitionBridge;
