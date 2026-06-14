import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/features/chat/application/chat_conversation_controller.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

void main() {
  test('reset assigns started time for a new empty conversation', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      chatConversationControllerProvider.notifier,
    );

    controller.reset();

    expect(controller.state.conversation, isEmpty);
    expect(controller.state.conversationStartedAt, isNotNull);
  });

  test('replacing empty conversation keeps existing started time', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      chatConversationControllerProvider.notifier,
    );
    final startedAt = DateTime(2026, 4, 5, 8);

    controller.reset(conversationStartedAt: startedAt);
    controller.replaceConversation(const []);

    expect(controller.state.conversationStartedAt, startedAt);
  });

  test('upsert ignores identical conversation entries', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      chatConversationControllerProvider.notifier,
    );
    const entry = ConversationEntryDto(
      id: 'assistant-1',
      entryType: 'assistant_message',
      role: 'assistant',
      text: 'hello',
      attachments: <AttachmentDto>[],
      isStreaming: false,
      status: 'completed',
      messageId: 'assistant-1',
      messageType: 'do_subtask_result',
    );

    controller.reset(conversation: const [entry]);
    final originalConversation = controller.state.conversation;

    controller.upsertConversationEntry(entry);

    expect(
      identical(controller.state.conversation, originalConversation),
      isTrue,
    );
    expect(controller.state.conversation, hasLength(1));
    expect(controller.state.conversation.single.text, 'hello');
  });

  test('upsert merges user entries with the same message id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      chatConversationControllerProvider.notifier,
    );
    const optimistic = ConversationEntryDto(
      id: 'local-user-1',
      sessionId: 'session-1',
      entryType: 'user_message',
      role: 'user',
      text: 'hello',
      attachments: <AttachmentDto>[],
      isStreaming: false,
      status: 'completed',
      messageId: 'msg-user-1',
    );
    const serverEntry = ConversationEntryDto(
      id: 'server-user-1',
      sessionId: 'session-1',
      entryType: 'user_message',
      role: 'user',
      text: 'hello',
      attachments: <AttachmentDto>[],
      isStreaming: false,
      status: 'completed',
      messageId: 'msg-user-1',
    );

    controller.reset(conversation: const [optimistic]);
    controller.upsertConversationEntry(serverEntry);

    expect(controller.state.conversation, hasLength(1));
    expect(controller.state.conversation.single.id, 'server-user-1');
    expect(controller.state.conversation.single.messageId, 'msg-user-1');
  });

  test('upsert inserts late server entries by created time', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      chatConversationControllerProvider.notifier,
    );
    final userACreatedAt = DateTime.utc(2026, 5, 28, 5);
    final assistantACreatedAt = DateTime.utc(2026, 5, 28, 5, 0, 1);
    final userBCreatedAt = DateTime.utc(2026, 5, 28, 5, 0, 2);
    final userA = ConversationEntryDto(
      id: 'user-a',
      sessionId: 'session-1',
      entryType: 'user_message',
      role: 'user',
      createdAt: userACreatedAt,
      text: 'A',
      attachments: const <AttachmentDto>[],
      isStreaming: false,
      status: 'completed',
      messageId: 'msg-user-a',
    );
    final userB = ConversationEntryDto(
      id: 'user-b',
      sessionId: 'session-1',
      entryType: 'user_message',
      role: 'user',
      createdAt: userBCreatedAt,
      text: 'B',
      attachments: const <AttachmentDto>[],
      isStreaming: false,
      status: 'completed',
      messageId: 'msg-user-b',
    );
    final assistantA = ConversationEntryDto(
      id: 'assistant-a',
      sessionId: 'session-1',
      entryType: 'assistant_message',
      role: 'assistant',
      createdAt: assistantACreatedAt,
      text: 'A partial',
      attachments: const <AttachmentDto>[],
      isStreaming: true,
      status: 'running',
      messageId: 'msg-assistant-a',
    );

    controller.reset(conversation: [userA, userB]);
    controller.upsertConversationEntry(assistantA);

    expect(
      controller.state.conversation.map((entry) => entry.text),
      orderedEquals(<String>['A', 'A partial', 'B']),
    );
  });

  test('keeps tool call and completes it when settling streaming entries', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      chatConversationControllerProvider.notifier,
    );
    controller.reset(
      conversation: const [
        ConversationEntryDto(
          id: 'tool_call:call-1',
          entryType: 'tool_call',
          role: 'assistant',
          text: '',
          attachments: <AttachmentDto>[],
          isStreaming: true,
          status: 'running',
          toolCallId: 'call-1',
          toolName: 'search_memory',
          toolArguments: '{"query":"生日"}',
          toolResult: '',
        ),
      ],
    );

    controller.settleStreamingConversationEntries();

    expect(controller.state.conversation, hasLength(1));
    expect(controller.state.conversation.single.isStreaming, isFalse);
    expect(controller.state.conversation.single.entryType, 'tool_call');
    expect(controller.state.conversation.single.toolName, 'search_memory');
    expect(controller.state.conversation.single.status, 'completed');
  });

  test('drops unfinished empty tool call placeholder when settling', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      chatConversationControllerProvider.notifier,
    );
    controller.reset(
      conversation: const [
        ConversationEntryDto(
          id: 'tool_call:call-2',
          entryType: 'tool_call',
          role: 'assistant',
          text: '',
          attachments: <AttachmentDto>[],
          isStreaming: true,
          status: 'running',
          toolCallId: null,
          toolName: null,
          toolArguments: '',
          toolResult: '',
        ),
      ],
    );

    controller.settleStreamingConversationEntries();

    expect(controller.state.conversation, isEmpty);
  });

  test('drops turn status tool entries on reset and upsert', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      chatConversationControllerProvider.notifier,
    );
    const turnStatus = ConversationEntryDto(
      id: 'tool_call:turn-status',
      entryType: 'tool_call',
      role: 'assistant',
      text: '',
      attachments: <AttachmentDto>[],
      isStreaming: false,
      status: 'completed',
      toolCallId: 'call-turn-status',
      toolName: 'turn_status',
      toolArguments: '{}',
      toolResult: '{"ok":true,"action":"turn_status"}',
    );

    controller.reset(conversation: const [turnStatus]);
    expect(controller.state.conversation, isEmpty);

    controller.upsertConversationEntry(turnStatus);
    expect(controller.state.conversation, isEmpty);
  });

  test('drops backend error message entries on reset and upsert', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      chatConversationControllerProvider.notifier,
    );
    const errorEntry = ConversationEntryDto(
      id: 'assistant-error',
      entryType: 'assistant_message',
      role: 'assistant',
      text: 'ClientException: Connection closed while receiving data',
      attachments: <AttachmentDto>[],
      isStreaming: false,
      status: 'completed',
      messageType: 'error',
    );

    controller.reset(conversation: const [errorEntry]);
    expect(controller.state.conversation, isEmpty);

    controller.upsertConversationEntry(errorEntry);
    expect(controller.state.conversation, isEmpty);
  });
}
