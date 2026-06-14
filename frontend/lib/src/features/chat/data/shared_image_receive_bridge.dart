import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ling/src/core/platform/app_platform.dart';

@immutable
class SharedImageFile {
  const SharedImageFile({
    required this.shareId,
    required this.path,
    required this.filename,
  });

  factory SharedImageFile.fromMap(Map<dynamic, dynamic> value) {
    return SharedImageFile(
      shareId: '${value['shareId'] ?? ''}',
      path: '${value['path'] ?? ''}',
      filename: '${value['filename'] ?? ''}',
    );
  }

  final String shareId;
  final String path;
  final String filename;
}

@immutable
class SharedItemsAvailability {
  const SharedItemsAvailability({
    required this.hasPendingFiles,
    required this.shouldImportPasteboardText,
    required this.shouldAutoSend,
  });

  factory SharedItemsAvailability.fromArguments(Object? arguments) {
    if (arguments case final Map<dynamic, dynamic> value) {
      return SharedItemsAvailability(
        hasPendingFiles: value['hasPendingFiles'] == true,
        shouldImportPasteboardText:
            value['shouldImportPasteboardText'] == true ||
            value['shouldImportPasteboard'] == true,
        shouldAutoSend: value['shouldAutoSend'] == true,
      );
    }
    return const SharedItemsAvailability(
      hasPendingFiles: false,
      shouldImportPasteboardText: false,
      shouldAutoSend: false,
    );
  }

  final bool hasPendingFiles;
  final bool shouldImportPasteboardText;
  final bool shouldAutoSend;

  bool get hasSharedItems => hasPendingFiles || shouldImportPasteboardText;
}

abstract interface class SharedImageReceiveBridge {
  Future<SharedItemsAvailability> getPendingSharedItemsAvailability();

  Future<List<SharedImageFile>> getPendingSharedImages();

  Future<void> consumeSharedImages(Iterable<SharedImageFile> images);

  Future<void> consumeSharedPasteboardTextRequest();

  void setSharedItemsAvailableHandler(
    void Function(SharedItemsAvailability availability)? handler,
  );

  Future<SharedItemsAvailability?> markReady();
}

class MethodChannelSharedImageReceiveBridge
    implements SharedImageReceiveBridge {
  MethodChannelSharedImageReceiveBridge() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const MethodChannel _channel = MethodChannel(
    'ling/shared_image_receive',
  );

  void Function(SharedItemsAvailability availability)?
  _sharedItemsAvailableHandler;

  @override
  Future<SharedItemsAvailability> getPendingSharedItemsAvailability() async {
    if (AppPlatformInfo.current != AppPlatform.ios) {
      return const SharedItemsAvailability(
        hasPendingFiles: false,
        shouldImportPasteboardText: false,
        shouldAutoSend: false,
      );
    }
    final arguments = await _channel.invokeMapMethod<dynamic, dynamic>(
      'getPendingSharedItemsAvailability',
    );
    return SharedItemsAvailability.fromArguments(arguments);
  }

  @override
  Future<List<SharedImageFile>> getPendingSharedImages() async {
    if (AppPlatformInfo.current != AppPlatform.ios) {
      return const <SharedImageFile>[];
    }
    final rawItems = await _channel.invokeListMethod<dynamic>(
      'getPendingSharedImages',
    );
    if (rawItems == null || rawItems.isEmpty) {
      return const <SharedImageFile>[];
    }
    return rawItems
        .whereType<Map<dynamic, dynamic>>()
        .map(SharedImageFile.fromMap)
        .where((item) => item.path.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> consumeSharedImages(Iterable<SharedImageFile> images) async {
    if (AppPlatformInfo.current != AppPlatform.ios) {
      return;
    }
    final paths = images
        .map((image) => image.path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (paths.isEmpty) {
      return;
    }
    await _channel.invokeMethod<void>('consumeSharedImages', {'paths': paths});
  }

  @override
  Future<void> consumeSharedPasteboardTextRequest() async {
    if (AppPlatformInfo.current != AppPlatform.ios) {
      return;
    }
    await _channel.invokeMethod<void>('consumeSharedPasteboardTextRequest');
  }

  @override
  void setSharedItemsAvailableHandler(
    void Function(SharedItemsAvailability availability)? handler,
  ) {
    _sharedItemsAvailableHandler = handler;
  }

  @override
  Future<SharedItemsAvailability?> markReady() async {
    if (AppPlatformInfo.current != AppPlatform.ios) {
      return null;
    }
    final arguments = await _channel.invokeMapMethod<dynamic, dynamic>('ready');
    if (arguments == null) {
      return null;
    }
    return SharedItemsAvailability.fromArguments(arguments);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'sharedItemsAvailable':
        _sharedItemsAvailableHandler?.call(
          SharedItemsAvailability.fromArguments(call.arguments),
        );
      case 'sharedImagesAvailable':
        _sharedItemsAvailableHandler?.call(
          SharedItemsAvailability.fromArguments(call.arguments),
        );
    }
  }
}
