import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatVoiceState {
  const ChatVoiceState({
    this.isStartingVoice = false,
    this.isRecordingVoice = false,
    this.isFinalizingVoice = false,
    this.voiceStopRequested = false,
    this.voiceDraftTranscript = '',
    this.voiceDraftAudioPath = '',
    this.voiceResultHandled = false,
  });

  final bool isStartingVoice;
  final bool isRecordingVoice;
  final bool isFinalizingVoice;
  final bool voiceStopRequested;
  final String voiceDraftTranscript;
  final String voiceDraftAudioPath;
  final bool voiceResultHandled;

  ChatVoiceState copyWith({
    bool? isStartingVoice,
    bool? isRecordingVoice,
    bool? isFinalizingVoice,
    bool? voiceStopRequested,
    String? voiceDraftTranscript,
    String? voiceDraftAudioPath,
    bool? voiceResultHandled,
  }) {
    return ChatVoiceState(
      isStartingVoice: isStartingVoice ?? this.isStartingVoice,
      isRecordingVoice: isRecordingVoice ?? this.isRecordingVoice,
      isFinalizingVoice: isFinalizingVoice ?? this.isFinalizingVoice,
      voiceStopRequested: voiceStopRequested ?? this.voiceStopRequested,
      voiceDraftTranscript: voiceDraftTranscript ?? this.voiceDraftTranscript,
      voiceDraftAudioPath: voiceDraftAudioPath ?? this.voiceDraftAudioPath,
      voiceResultHandled: voiceResultHandled ?? this.voiceResultHandled,
    );
  }
}

class ChatVoiceController extends Notifier<ChatVoiceState> {
  @override
  ChatVoiceState build() => const ChatVoiceState();

  void updateVoiceState({
    bool? isStartingVoice,
    bool? isRecordingVoice,
    bool? isFinalizingVoice,
    bool? voiceStopRequested,
    String? voiceDraftTranscript,
    String? voiceDraftAudioPath,
    bool? voiceResultHandled,
  }) {
    state = state.copyWith(
      isStartingVoice: isStartingVoice,
      isRecordingVoice: isRecordingVoice,
      isFinalizingVoice: isFinalizingVoice,
      voiceStopRequested: voiceStopRequested,
      voiceDraftTranscript: voiceDraftTranscript,
      voiceDraftAudioPath: voiceDraftAudioPath,
      voiceResultHandled: voiceResultHandled,
    );
  }

  void reset({
    String voiceDraftTranscript = '',
    String voiceDraftAudioPath = '',
    bool voiceResultHandled = false,
  }) {
    state = ChatVoiceState(
      voiceDraftTranscript: voiceDraftTranscript,
      voiceDraftAudioPath: voiceDraftAudioPath,
      voiceResultHandled: voiceResultHandled,
    );
  }
}

final chatVoiceControllerProvider =
    NotifierProvider<ChatVoiceController, ChatVoiceState>(
      ChatVoiceController.new,
    );
