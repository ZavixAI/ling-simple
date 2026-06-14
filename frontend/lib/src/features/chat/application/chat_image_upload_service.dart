import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/features/chat/data/chat_repository.dart';
import 'package:ling/src/features/chat/data/native_camera_picker_bridge.dart';
import 'package:ling/src/features/chat/models/chat_session_models.dart';

class UploadedConversationImage {
  const UploadedConversationImage({
    required this.attachment,
    required this.bytes,
  });

  final AttachmentDto attachment;
  final Uint8List bytes;
}

class ChatImageUploadBatchResult {
  const ChatImageUploadBatchResult({required this.uploads, this.error});

  final List<UploadedConversationImage> uploads;
  final Object? error;
}

class ChatImageUploadService {
  const ChatImageUploadService({
    required ChatRepository repository,
    NativeCameraPickerBridge? nativeCameraPickerBridge,
    ImagePicker? imagePicker,
  }) : _repository = repository,
       _nativeCameraPickerBridge = nativeCameraPickerBridge,
       _imagePicker = imagePicker;

  final ChatRepository _repository;
  final NativeCameraPickerBridge? _nativeCameraPickerBridge;
  final ImagePicker? _imagePicker;

  Future<ChatImageUploadBatchResult> uploadConversationImages(
    List<XFile> pickedFiles,
  ) async {
    final uploads = <UploadedConversationImage>[];
    Object? firstError;

    for (final picked in pickedFiles) {
      try {
        final bytes = await picked.readAsBytes();
        final attachment = await _repository.uploadConversationImage(
          bytes: bytes,
          filename: picked.name,
        );
        uploads.add(
          UploadedConversationImage(attachment: attachment, bytes: bytes),
        );
      } catch (error) {
        firstError ??= error;
      }
    }

    return ChatImageUploadBatchResult(uploads: uploads, error: firstError);
  }

  Future<AttachmentDto> uploadConversationAudio({
    required List<int> bytes,
    required String filename,
  }) {
    return _repository.uploadConversationAudio(
      bytes: bytes,
      filename: filename,
    );
  }

  Future<List<XFile>> pickConversationImages({
    required ImageSource source,
    required AppPlatform platform,
  }) async {
    final nativeCameraPickerBridge = _nativeCameraPickerBridge;
    final imagePicker = _imagePicker;

    if (source == ImageSource.camera && platform == AppPlatform.ios) {
      if (nativeCameraPickerBridge == null) {
        throw StateError('NativeCameraPickerBridge is not configured.');
      }
      final picked = await nativeCameraPickerBridge.pickImage(
        imageQuality: 88,
        maxWidth: 2048,
      );
      if (picked == null) {
        return const [];
      }
      return [picked];
    }

    if (imagePicker == null) {
      throw StateError('ImagePicker is not configured.');
    }

    if (source == ImageSource.gallery) {
      return imagePicker.pickMultiImage(imageQuality: 88, maxWidth: 2048);
    }

    final picked = await imagePicker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 2048,
    );
    if (picked == null) {
      return const [];
    }
    return [picked];
  }
}
