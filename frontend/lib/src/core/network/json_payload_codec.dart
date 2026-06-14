import 'dart:convert';

import 'package:ling/src/config/app_environment.dart';
import 'package:ling/src/core/network/api_exception.dart';

Map<String, dynamic> asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      throw ApiException(message: '接口返回格式异常，无法解析为对象。', cause: value);
    }
  }
  throw ApiException(message: '接口返回格式异常，预期为对象。', cause: value);
}

Object? decodeStoredJson(String payload) {
  try {
    return jsonDecode(payload);
  } catch (_) {
    throw ApiException(message: '本地缓存格式异常，无法解析。', cause: payload);
  }
}

Map<String, dynamic> decodeStoredMap(String payload) {
  return asJsonMap(decodeStoredJson(payload));
}

Map<String, dynamic> normalizeAttachmentJson(Map<String, dynamic> value) {
  final normalized = Map<String, dynamic>.from(value);
  final downloadPath = '${normalized['download_path'] ?? ''}';
  if (downloadPath.isNotEmpty) {
    normalized['url'] = AppEnvironment.resolveUrl(downloadPath).toString();
  } else if ('${normalized['download_url'] ?? ''}'.trim().isNotEmpty) {
    normalized['url'] = AppEnvironment.resolveUrl(
      '${normalized['download_url']}',
    ).toString();
  }

  final content = normalized['message_content'];
  if (content is Map) {
    final messageContent = Map<String, dynamic>.from(content);
    final imageUrl = messageContent['image_url'];
    if (imageUrl is Map) {
      final normalizedImageUrl = Map<String, dynamic>.from(imageUrl);
      final rawUrl = '${normalizedImageUrl['url'] ?? ''}'.trim();
      if (rawUrl.isNotEmpty) {
        normalizedImageUrl['url'] = AppEnvironment.resolveUrl(
          rawUrl,
        ).toString();
      }
      messageContent['image_url'] = normalizedImageUrl;
    }
    final inputAudio = messageContent['input_audio'];
    if (inputAudio is Map) {
      final normalizedInputAudio = Map<String, dynamic>.from(inputAudio);
      final rawUrl = '${normalizedInputAudio['url'] ?? ''}'.trim();
      if (rawUrl.isNotEmpty) {
        normalizedInputAudio['url'] = AppEnvironment.resolveUrl(
          rawUrl,
        ).toString();
      }
      messageContent['input_audio'] = normalizedInputAudio;
    }
    normalized['message_content'] = messageContent;
  }
  return normalized;
}
