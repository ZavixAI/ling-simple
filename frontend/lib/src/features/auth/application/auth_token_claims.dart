import 'dart:convert';

String? extractDeviceIdFromAccessToken(String accessToken) {
  final parts = accessToken.trim().split('.');
  if (parts.length < 2) {
    return null;
  }
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final claims = jsonDecode(payload);
    if (claims is! Map) {
      return null;
    }
    final deviceId = '${claims['device_id'] ?? ''}'.trim();
    return deviceId.isEmpty ? null : deviceId;
  } catch (_) {
    return null;
  }
}
