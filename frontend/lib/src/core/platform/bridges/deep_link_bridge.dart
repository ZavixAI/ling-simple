import 'package:flutter/services.dart';

import 'package:ling/src/core/platform/app_platform.dart';

class LingDeepLink {
  const LingDeepLink({required this.kind, required this.url, this.materialId});

  final String kind;
  final String url;
  final String? materialId;

  factory LingDeepLink.fromMap(Map<Object?, Object?> map) {
    return LingDeepLink(
      kind: _readString(map['kind']),
      url: _readString(map['url']),
      materialId: _readNullableString(map['materialId']),
    );
  }
}

abstract interface class LingDeepLinkBridge {
  Future<LingDeepLink?> ready();
  void setListener(void Function(LingDeepLink link)? listener);
}

class MethodChannelLingDeepLinkBridge implements LingDeepLinkBridge {
  const MethodChannelLingDeepLinkBridge();

  static const MethodChannel _channel = MethodChannel('ling/deep_link');

  bool get _isSupported => isNativeLingBridgeSupported();

  @override
  Future<LingDeepLink?> ready() async {
    if (!_isSupported) {
      return null;
    }
    final response = await _channel.invokeMethod<Object?>('ready');
    if (response is Map<Object?, Object?>) {
      return LingDeepLink.fromMap(response);
    }
    return null;
  }

  @override
  void setListener(void Function(LingDeepLink link)? listener) {
    if (!_isSupported) {
      return;
    }
    _channel.setMethodCallHandler(
      listener == null
          ? null
          : (call) async {
              if (call.method != 'deepLinkOpened') {
                throw MissingPluginException();
              }
              final arguments = call.arguments;
              if (arguments is Map<Object?, Object?>) {
                listener(LingDeepLink.fromMap(arguments));
              }
            },
    );
  }
}

String _readString(Object? value) {
  if (value == null) {
    return '';
  }
  return '$value'.trim();
}

String? _readNullableString(Object? value) {
  final normalized = _readString(value);
  return normalized.isEmpty ? null : normalized;
}
