import 'dart:convert';
import 'dart:io';

import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/features/chat/application/agent_file_data.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class AgentFileCacheStore {
  Future<LingAgentFileData?> read(String path);
  Future<void> write(String path, LingAgentFileData data);
  Future<void> clear();
}

class DefaultAgentFileCacheStore implements AgentFileCacheStore {
  const DefaultAgentFileCacheStore();

  static const String _cacheDirectoryName = 'ling_agent_file_cache_v1';

  @override
  Future<LingAgentFileData?> read(String path) async {
    final files = await _cacheFiles(path);
    if (!await files.metadata.exists() || !await files.bytes.exists()) {
      return null;
    }
    try {
      final metadata = jsonDecode(await files.metadata.readAsString());
      if (metadata is! Map<String, Object?>) {
        return null;
      }
      return LingAgentFileData(
        path: '${metadata['path'] ?? path}',
        bytes: await files.bytes.readAsBytes(),
        contentType:
            '${metadata['content_type'] ?? 'application/octet-stream'}',
        filename: '${metadata['filename'] ?? _filenameFromPath(path)}',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String path, LingAgentFileData data) async {
    final files = await _cacheFiles(path);
    await files.directory.create(recursive: true);
    await files.bytes.writeAsBytes(data.bytes, flush: false);
    await files.metadata.writeAsString(
      jsonEncode(<String, Object?>{
        'path': data.path,
        'content_type': data.contentType,
        'filename': data.filename,
      }),
      flush: false,
    );
  }

  @override
  Future<void> clear() async {
    final directory = await _cacheDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<_AgentFileCacheFiles> _cacheFiles(String path) async {
    final directory = await _cacheDirectory();
    final key = _cacheKey(path);
    return _AgentFileCacheFiles(
      directory: directory,
      bytes: File(p.join(directory.path, '$key.bin')),
      metadata: File(p.join(directory.path, '$key.json')),
    );
  }

  Future<Directory> _cacheDirectory() async {
    final directory = await getTemporaryDirectory();
    return Directory(p.join(directory.path, _cacheDirectoryName));
  }

  String _cacheKey(String value) {
    const int offset = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    var hash = offset;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

class _AgentFileCacheFiles {
  const _AgentFileCacheFiles({
    required this.directory,
    required this.bytes,
    required this.metadata,
  });

  final Directory directory;
  final File bytes;
  final File metadata;
}

class AgentFileRepository {
  AgentFileRepository({
    required ApiClient apiClient,
    AgentFileCacheStore? cacheStore,
  }) : _apiClient = apiClient,
       _cacheStore = cacheStore ?? const DefaultAgentFileCacheStore();

  final ApiClient _apiClient;
  final AgentFileCacheStore _cacheStore;
  final Map<String, Future<LingAgentFileData>> _activeLoads =
      <String, Future<LingAgentFileData>>{};

  Future<LingAgentFileData> getFileData(String path) async {
    final normalizedPath = path.trim();
    final activeLoad = _activeLoads[normalizedPath];
    if (activeLoad != null) {
      return activeLoad;
    }
    final future = _getFileData(normalizedPath);
    _activeLoads[normalizedPath] = future;
    return future.whenComplete(() => _activeLoads.remove(normalizedPath));
  }

  Future<LingAgentFileData> _getFileData(String path) async {
    final cached = await _readCache(path);
    if (cached != null) {
      return cached;
    }
    final response = await _apiClient.getBytes(
      '/agent/file/data',
      queryParameters: {'path': path},
    );
    final data = LingAgentFileData(
      path:
          _decodeHeaderPath(response.headers['x-ling-agent-file-path']) ?? path,
      bytes: response.bytes,
      contentType:
          response.headers['content-type'] ?? 'application/octet-stream',
      filename:
          _filenameFromContentDisposition(
            response.headers['content-disposition'],
          ) ??
          _filenameFromPath(path),
    );
    await _writeCache(path, data);
    if (data.path != path) {
      await _writeCache(data.path, data);
    }
    return data;
  }

  Future<LingAgentFileData?> _readCache(String path) async {
    try {
      return await _cacheStore.read(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String path, LingAgentFileData data) async {
    try {
      await _cacheStore.write(path, data);
    } catch (_) {
      return;
    }
  }
}

String? _decodeHeaderPath(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  try {
    return Uri.decodeFull(value);
  } catch (_) {
    return value;
  }
}

String? _filenameFromContentDisposition(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final match = RegExp(
    r"""filename\*?=(?:UTF-8'')?"?([^";]+)"?""",
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  final raw = match.group(1)?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return Uri.decodeComponent(raw);
}

String _filenameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(index + 1) : normalized;
}
