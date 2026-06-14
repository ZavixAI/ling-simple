import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final Random _queuedPromptIdRandom = Random.secure();

class ChatRuntimeController {
  int _promptRunSequence = 0;
  final Set<int> _interruptedPromptRunIds = <int>{};
  String? _pendingVoiceDraftTranscript;

  String nextQueuedPromptId() => _generateUuidV4();

  int nextPromptRunId() => ++_promptRunSequence;

  bool isPromptRunInterrupted(int runId) =>
      _interruptedPromptRunIds.contains(runId);

  void markPromptRunInterrupted(int runId) {
    _interruptedPromptRunIds.add(runId);
  }

  void clearInterruptedPromptRun(int runId) {
    _interruptedPromptRunIds.remove(runId);
  }

  String? get pendingVoiceDraftTranscript => _pendingVoiceDraftTranscript;

  void setPendingVoiceDraftTranscript(String? value) {
    final normalized = value?.trim();
    _pendingVoiceDraftTranscript = normalized == null || normalized.isEmpty
        ? null
        : normalized;
  }

  void reset() {
    _promptRunSequence = 0;
    _interruptedPromptRunIds.clear();
    _pendingVoiceDraftTranscript = null;
  }

  void dispose() {
    _interruptedPromptRunIds.clear();
    _pendingVoiceDraftTranscript = null;
  }
}

final chatRuntimeControllerProvider = Provider<ChatRuntimeController>((ref) {
  final controller = ChatRuntimeController();
  ref.onDispose(controller.dispose);
  return controller;
});

String _generateUuidV4() {
  final bytes = List<int>.generate(
    16,
    (_) => _queuedPromptIdRandom.nextInt(256),
  );
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
