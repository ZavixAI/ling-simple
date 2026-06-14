import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatSurfaceState {
  const ChatSurfaceState({this.isAwaitingMembershipSummary = false});

  final bool isAwaitingMembershipSummary;

  ChatSurfaceState copyWith({bool? isAwaitingMembershipSummary}) {
    return ChatSurfaceState(
      isAwaitingMembershipSummary:
          isAwaitingMembershipSummary ?? this.isAwaitingMembershipSummary,
    );
  }
}

class ChatSurfaceController extends Notifier<ChatSurfaceState> {
  @override
  ChatSurfaceState build() => const ChatSurfaceState();

  void clear() {
    state = const ChatSurfaceState();
  }

  Future<bool> ensureMembershipReadyForChat({
    required bool isAuthenticated,
    required Future<bool> Function() ensureReady,
  }) async {
    if (!isAuthenticated) {
      return true;
    }
    _setAwaitingMembershipSummary(true);
    try {
      return await ensureReady();
    } finally {
      _setAwaitingMembershipSummary(false);
    }
  }

  void _setAwaitingMembershipSummary(bool value) {
    if (state.isAwaitingMembershipSummary == value) {
      return;
    }
    state = state.copyWith(isAwaitingMembershipSummary: value);
  }
}

final chatSurfaceControllerProvider =
    NotifierProvider<ChatSurfaceController, ChatSurfaceState>(
      ChatSurfaceController.new,
    );
