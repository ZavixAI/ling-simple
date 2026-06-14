import 'package:flutter/services.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/features/chat/application/agent_file_data.dart';

enum AgentFileSaveStatus { success, unsupported, failed }

class AgentFileSaveResult {
  const AgentFileSaveResult({required this.status, this.message});

  final AgentFileSaveStatus status;
  final String? message;

  bool get isSuccess => status == AgentFileSaveStatus.success;
}

abstract interface class AgentFileSaveBridge {
  Future<AgentFileSaveResult> saveFileToLocal({
    required List<int> bytes,
    required String filename,
    required String contentType,
  });
}

class MethodChannelAgentFileSaveBridge implements AgentFileSaveBridge {
  static const MethodChannel _channel = MethodChannel(
    'ling/conversation_attachment_save',
  );

  @override
  Future<AgentFileSaveResult> saveFileToLocal({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    if (AppPlatformInfo.current != AppPlatform.ios) {
      return const AgentFileSaveResult(status: AgentFileSaveStatus.unsupported);
    }
    try {
      await _channel.invokeMethod<void>('saveFileToLocal', {
        'bytes': Uint8List.fromList(bytes),
        'filename': filename,
        'contentType': contentType,
      });
      return const AgentFileSaveResult(status: AgentFileSaveStatus.success);
    } on PlatformException catch (error) {
      return AgentFileSaveResult(
        status: AgentFileSaveStatus.failed,
        message: error.message,
      );
    }
  }
}

class AgentFileSaveService {
  AgentFileSaveService({AgentFileSaveBridge? bridge})
    : _bridge = bridge ?? MethodChannelAgentFileSaveBridge();

  final AgentFileSaveBridge _bridge;

  Future<AgentFileSaveResult> saveFileToLocal(LingAgentFileData data) {
    return _bridge.saveFileToLocal(
      bytes: data.bytes,
      filename: data.filename,
      contentType: data.contentType,
    );
  }
}
