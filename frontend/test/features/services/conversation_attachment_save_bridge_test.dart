import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ling/src/features/chat/application/conversation_attachment.dart';
import 'package:ling/src/features/chat/data/conversation_attachment_save_service.dart';

void main() {
  test('method channel bridge reports unsupported outside iOS', () async {
    final bridge = MethodChannelConversationAttachmentSaveBridge();

    final result = await bridge.saveImageToLocal(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      filename: 'photo.png',
    );

    expect(result.status, ConversationAttachmentSaveStatus.unsupported);
  });

  test('service downloads remote attachment bytes before saving', () async {
    final bridge = _FakeConversationAttachmentSaveBridge();
    final service = ConversationAttachmentSaveService(
      bridge: bridge,
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/photo.png');
        return http.Response.bytes(Uint8List.fromList(<int>[7, 8, 9]), 200);
      }),
    );
    addTearDown(service.dispose);

    final result = await service.saveAttachmentsToLocal([
      const LingConversationAttachment(
        attachmentId: 'att-1',
        filename: 'photo.png',
        url: 'https://example.com/photo.png',
        messageContent: <String, dynamic>{},
      ),
    ]);

    expect(result.status, ConversationAttachmentSaveStatus.success);
    expect(bridge.savedPayloads, hasLength(1));
    expect(bridge.savedPayloads.single.filename, 'photo.png');
    expect(bridge.savedPayloads.single.bytes, <int>[7, 8, 9]);
  });

  test('service returns bridge failure for local attachments', () async {
    final bridge = _FakeConversationAttachmentSaveBridge(
      result: const ConversationAttachmentSaveResult(
        status: ConversationAttachmentSaveStatus.failed,
      ),
    );
    final service = ConversationAttachmentSaveService(
      bridge: bridge,
      client: MockClient((request) async {
        fail('No network request should be made for local attachment bytes.');
      }),
    );
    addTearDown(service.dispose);

    final result = await service.saveAttachmentsToLocal([
      LingConversationAttachment(
        attachmentId: 'att-1',
        filename: 'photo.png',
        url: '',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        messageContent: <String, dynamic>{},
      ),
    ]);

    expect(result.status, ConversationAttachmentSaveStatus.failed);
    expect(bridge.savedPayloads, hasLength(1));
  });
}

class _FakeConversationAttachmentSaveBridge
    implements ConversationAttachmentSaveBridge {
  _FakeConversationAttachmentSaveBridge({
    this.result = const ConversationAttachmentSaveResult(
      status: ConversationAttachmentSaveStatus.success,
    ),
  });

  final ConversationAttachmentSaveResult result;
  final List<_SavedPayload> savedPayloads = <_SavedPayload>[];

  @override
  Future<ConversationAttachmentSaveResult> saveImageToLocal({
    required Uint8List bytes,
    String? filename,
  }) async {
    savedPayloads.add(
      _SavedPayload(bytes: bytes.toList(growable: false), filename: filename),
    );
    return result;
  }
}

class _SavedPayload {
  const _SavedPayload({required this.bytes, required this.filename});

  final List<int> bytes;
  final String? filename;
}
