import 'dart:convert';
import 'dart:typed_data';

class LingAgentFileData {
  const LingAgentFileData({
    required this.path,
    required this.bytes,
    required this.contentType,
    required this.filename,
  });

  final String path;
  final Uint8List bytes;
  final String contentType;
  final String filename;

  String get text => utf8.decode(bytes, allowMalformed: true);
}
