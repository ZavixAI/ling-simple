import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/features/chat/application/conversation_attachment.dart';

enum ConversationAttachmentSaveStatus { success, unsupported, failed }

class ConversationAttachmentSaveResult {
  const ConversationAttachmentSaveResult({required this.status, this.message});

  final ConversationAttachmentSaveStatus status;
  final String? message;

  bool get isSuccess => status == ConversationAttachmentSaveStatus.success;
}

abstract interface class ConversationAttachmentSaveBridge {
  Future<ConversationAttachmentSaveResult> saveImageToLocal({
    required Uint8List bytes,
    String? filename,
  });
}

class MethodChannelConversationAttachmentSaveBridge
    implements ConversationAttachmentSaveBridge {
  static const MethodChannel _channel = MethodChannel(
    'ling/conversation_attachment_save',
  );

  @override
  Future<ConversationAttachmentSaveResult> saveImageToLocal({
    required Uint8List bytes,
    String? filename,
  }) async {
    if (AppPlatformInfo.current != AppPlatform.ios) {
      return const ConversationAttachmentSaveResult(
        status: ConversationAttachmentSaveStatus.unsupported,
      );
    }
    try {
      await _channel.invokeMethod<void>('saveImageToLocal', {
        'bytes': bytes,
        'filename': filename,
      });
      return const ConversationAttachmentSaveResult(
        status: ConversationAttachmentSaveStatus.success,
      );
    } on PlatformException catch (error) {
      return ConversationAttachmentSaveResult(
        status: ConversationAttachmentSaveStatus.failed,
        message: error.message,
      );
    }
  }
}

class ConversationAttachmentSaveService {
  ConversationAttachmentSaveService({
    ConversationAttachmentSaveBridge? bridge,
    http.Client? client,
  }) : _bridge = bridge ?? MethodChannelConversationAttachmentSaveBridge(),
       _client = client ?? http.Client();

  final ConversationAttachmentSaveBridge _bridge;
  final http.Client _client;

  Future<ConversationAttachmentSaveResult> saveAttachmentsToLocal(
    Iterable<LingConversationAttachment> attachments,
  ) async {
    final normalizedAttachments = attachments.toList(growable: false);
    if (normalizedAttachments.isEmpty) {
      return const ConversationAttachmentSaveResult(
        status: ConversationAttachmentSaveStatus.failed,
      );
    }

    for (final attachment in normalizedAttachments) {
      final bytes = await _resolveAttachmentBytes(attachment);
      final result = await _bridge.saveImageToLocal(
        bytes: bytes,
        filename: attachment.filename,
      );
      if (!result.isSuccess) {
        return result;
      }
    }

    return const ConversationAttachmentSaveResult(
      status: ConversationAttachmentSaveStatus.success,
    );
  }

  Future<Uint8List> _resolveAttachmentBytes(
    LingConversationAttachment attachment,
  ) async {
    final localBytes = attachment.bytes;
    if (localBytes != null && localBytes.isNotEmpty) {
      return localBytes;
    }

    final normalizedUrl = attachment.url.trim();
    if (normalizedUrl.isEmpty) {
      throw StateError(
        'Attachment ${attachment.attachmentId} is missing local bytes and download URL.',
      );
    }

    final response = await _client.get(Uri.parse(normalizedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Failed to download attachment ${attachment.attachmentId} (HTTP ${response.statusCode}).',
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw StateError(
        'Downloaded attachment ${attachment.attachmentId} is empty.',
      );
    }
    return response.bodyBytes;
  }

  void dispose() {
    _client.close();
  }
}
