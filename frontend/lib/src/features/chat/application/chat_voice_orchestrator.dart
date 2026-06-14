import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/features/chat/application/chat_voice_transcript_normalizer.dart';
import 'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart';

class ChatVoiceOrchestrator {
  const ChatVoiceOrchestrator({
    SpeechRecognitionBridge? speechRecognitionBridge,
  }) : _speechRecognitionBridge = speechRecognitionBridge;

  final SpeechRecognitionBridge? _speechRecognitionBridge;

  SpeechRecognitionBridge get _bridge {
    final bridge = _speechRecognitionBridge;
    if (bridge == null) {
      throw StateError('SpeechRecognitionBridge is not configured.');
    }
    return bridge;
  }

  StreamSubscription<SpeechEvent> subscribeToEvents(
    void Function(SpeechEvent event) listener,
  ) {
    return _bridge.events().listen(listener);
  }

  Future<void> cancelRecognition() {
    return _bridge.cancelRecognition();
  }

  Future<void> startRecording({
    required bool isDockBusy,
    required bool isVoiceInteractionActive,
    required AppPlatform platform,
    required String localeCode,
    required String unsupportedMessage,
    SpeechRecognitionBridge? speechRecognitionBridge,
    required void Function() closeKeyboardComposer,
    required void Function({
      bool? isStartingVoice,
      bool? isRecordingVoice,
      bool? isFinalizingVoice,
      bool? voiceStopRequested,
      String? voiceDraftTranscript,
      String? voiceDraftAudioPath,
      bool? voiceResultHandled,
    })
    updateVoiceState,
    required void Function(String? transcript) setPendingVoiceDraftTranscript,
    required Future<void> Function() stopVoiceRecognitionAfterStart,
    required void Function() resetVoiceState,
    required void Function(Object error) showError,
    required void Function(String message) showMessage,
  }) async {
    if (isDockBusy || isVoiceInteractionActive) {
      return;
    }
    if (platform != AppPlatform.ios) {
      showMessage(unsupportedMessage);
      return;
    }

    closeKeyboardComposer();
    updateVoiceState(
      isStartingVoice: true,
      isRecordingVoice: false,
      isFinalizingVoice: false,
      voiceDraftTranscript: '',
      voiceDraftAudioPath: '',
      voiceResultHandled: false,
      voiceStopRequested: false,
    );
    setPendingVoiceDraftTranscript(null);

    try {
      await (speechRecognitionBridge ?? _bridge).startRecognition(
        locale: localeCode,
      );
      await stopVoiceRecognitionAfterStart();
    } catch (error) {
      if (_isRecognitionAlreadyRunningError(error)) {
        return;
      }
      resetVoiceState();
      showError(error);
    }
  }

  Future<void> finishRecording({
    required bool isStartingVoice,
    required bool isRecordingVoice,
    required bool isFinalizingVoice,
    required bool voiceResultHandled,
    SpeechRecognitionBridge? speechRecognitionBridge,
    required void Function({
      bool? isStartingVoice,
      bool? isRecordingVoice,
      bool? isFinalizingVoice,
      bool? voiceStopRequested,
      String? voiceDraftTranscript,
      String? voiceDraftAudioPath,
      bool? voiceResultHandled,
    })
    updateVoiceState,
    required void Function() resetVoiceState,
    required void Function(Object error) showError,
  }) async {
    if (!isStartingVoice && !isRecordingVoice && !isFinalizingVoice) {
      return;
    }
    if (isStartingVoice) {
      updateVoiceState(
        isStartingVoice: false,
        voiceStopRequested: true,
        isRecordingVoice: false,
        isFinalizingVoice: true,
      );
      return;
    }
    if (isFinalizingVoice) {
      return;
    }
    try {
      updateVoiceState(isRecordingVoice: false, isFinalizingVoice: true);
      await (speechRecognitionBridge ?? _bridge).stopRecognition();
    } catch (error) {
      if (!voiceResultHandled) {
        resetVoiceState();
        showError(error);
      }
    }
  }

  void handleSpeechEvent({
    required SpeechEvent event,
    required bool voiceResultHandled,
    required bool isStartingVoice,
    required bool isRecordingVoice,
    required bool isFinalizingVoice,
    required String voiceDraftTranscript,
    required String? pendingVoiceDraftTranscript,
    required void Function({
      bool? isStartingVoice,
      bool? isRecordingVoice,
      bool? isFinalizingVoice,
      bool? voiceStopRequested,
      String? voiceDraftTranscript,
      String? voiceDraftAudioPath,
      bool? voiceResultHandled,
    })
    updateVoiceState,
    required void Function(String transcript)
    scheduleVoiceDraftTranscriptRefresh,
    required void Function() scheduleVoiceFinalizeFallback,
    required void Function(String transcript) submitRecognizedVoiceTranscript,
    required void Function({bool clearTranscript, bool resetResultHandled})
    resetVoiceState,
    required void Function(String message) showMessage,
  }) {
    if (voiceResultHandled) {
      switch (event.type) {
        case SpeechEventType.cancelled:
        case SpeechEventType.error:
          resetVoiceState(clearTranscript: true, resetResultHandled: false);
          return;
        case SpeechEventType.listening:
        case SpeechEventType.processing:
        case SpeechEventType.partialResult:
        case SpeechEventType.finalResult:
          return;
      }
    }

    switch (event.type) {
      case SpeechEventType.listening:
        if (isFinalizingVoice ||
            (!isStartingVoice && isRecordingVoice && !isFinalizingVoice)) {
          return;
        }
        updateVoiceState(
          isStartingVoice: false,
          isRecordingVoice: true,
          isFinalizingVoice: false,
        );
        return;
      case SpeechEventType.processing:
        if (!isStartingVoice && !isRecordingVoice && !isFinalizingVoice) {
          return;
        }
        final transcript = ChatVoiceTranscriptNormalizer.collapseRepeated(
          event.transcript,
        );
        final hasStateChange =
            isStartingVoice || isRecordingVoice || !isFinalizingVoice;
        final hasTranscriptChange =
            transcript.isNotEmpty &&
            transcript != voiceDraftTranscript &&
            transcript != pendingVoiceDraftTranscript;
        if (hasTranscriptChange) {
          scheduleVoiceDraftTranscriptRefresh(transcript);
        }
        if (hasStateChange) {
          updateVoiceState(
            isStartingVoice: false,
            isRecordingVoice: false,
            isFinalizingVoice: true,
          );
        }
        scheduleVoiceFinalizeFallback();
        return;
      case SpeechEventType.partialResult:
        final transcript = ChatVoiceTranscriptNormalizer.collapseRepeated(
          event.transcript,
        );
        if (transcript.isEmpty ||
            transcript == voiceDraftTranscript ||
            transcript == pendingVoiceDraftTranscript) {
          return;
        }
        scheduleVoiceDraftTranscriptRefresh(transcript);
        return;
      case SpeechEventType.finalResult:
        final audioPath = event.audioPath.trim();
        if (audioPath.isNotEmpty) {
          updateVoiceState(voiceDraftAudioPath: audioPath);
        }
        submitRecognizedVoiceTranscript(event.transcript.trim());
        return;
      case SpeechEventType.cancelled:
        resetVoiceState(clearTranscript: true, resetResultHandled: true);
        return;
      case SpeechEventType.error:
        if (isFinalizingVoice) {
          final transcript =
              (pendingVoiceDraftTranscript ?? voiceDraftTranscript).trim();
          submitRecognizedVoiceTranscript(transcript);
          return;
        }
        resetVoiceState(clearTranscript: true, resetResultHandled: true);
        final message = event.message.trim();
        if (message.isNotEmpty) {
          showMessage(message);
        }
        return;
    }
  }

  Future<void> submitRecognizedTranscript({
    required String transcript,
    required bool voiceResultHandled,
    required String voiceDraftTranscript,
    required String? pendingVoiceDraftTranscript,
    required void Function({
      bool? isStartingVoice,
      bool? isRecordingVoice,
      bool? isFinalizingVoice,
      bool? voiceStopRequested,
      String? voiceDraftTranscript,
      String? voiceDraftAudioPath,
      bool? voiceResultHandled,
    })
    updateVoiceState,
    required void Function() cancelVoiceUiTimers,
    required void Function(String? transcript) setPendingVoiceDraftTranscript,
    required void Function({bool clearTranscript, bool resetResultHandled})
    resetVoiceState,
    required FutureOr<void> Function(String prompt) applyRecognizedTranscript,
  }) async {
    if (voiceResultHandled) {
      return;
    }

    final prompt = ChatVoiceTranscriptNormalizer.chooseFinalTranscript(
      finalTranscript: transcript,
      fallbackTranscript: pendingVoiceDraftTranscript ?? voiceDraftTranscript,
    ).trim();

    updateVoiceState(voiceResultHandled: true);
    cancelVoiceUiTimers();
    setPendingVoiceDraftTranscript(null);

    if (prompt.isNotEmpty) {
      updateVoiceState(voiceDraftTranscript: prompt);
    }

    if (prompt.isEmpty) {
      resetVoiceState(clearTranscript: true, resetResultHandled: false);
      return;
    }

    await applyRecognizedTranscript(prompt);
    resetVoiceState(clearTranscript: false, resetResultHandled: false);
  }

  Future<void> stopRecognitionAfterStart({
    required bool voiceStopRequested,
    SpeechRecognitionBridge? speechRecognitionBridge,
    required void Function({
      bool? isStartingVoice,
      bool? isRecordingVoice,
      bool? isFinalizingVoice,
      bool? voiceStopRequested,
      String? voiceDraftTranscript,
      String? voiceDraftAudioPath,
      bool? voiceResultHandled,
    })
    updateVoiceState,
  }) async {
    if (!voiceStopRequested) {
      return;
    }

    updateVoiceState(
      isStartingVoice: false,
      isRecordingVoice: false,
      isFinalizingVoice: true,
      voiceStopRequested: false,
    );
    await (speechRecognitionBridge ?? _bridge).stopRecognition();
    updateVoiceState(
      isStartingVoice: false,
      isRecordingVoice: false,
      isFinalizingVoice: false,
      voiceStopRequested: false,
    );
  }
}

bool _isRecognitionAlreadyRunningError(Object error) {
  return error is PlatformException && error.code == 'busy';
}

final chatVoiceOrchestratorProvider = Provider<ChatVoiceOrchestrator>((ref) {
  return ChatVoiceOrchestrator(
    speechRecognitionBridge: ref.read(appleSpeechRecognitionBridgeProvider),
  );
});
