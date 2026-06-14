import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/features/chat/application/agent_file_data.dart';
import 'package:ling/src/features/chat/data/agent_file_repository.dart';

void main() {
  test('getFileData returns local cached file data without network', () async {
    final cacheStore = _MemoryAgentFileCacheStore();
    final cached = LingAgentFileData(
      path: 'reports/minimax.md',
      bytes: Uint8List.fromList(utf8.encode('# MiniMax\n\n复盘内容')),
      contentType: 'text/markdown; charset=utf-8',
      filename: 'minimax.md',
    );
    cacheStore.files[cached.path] = cached;
    final repository = AgentFileRepository(
      apiClient: _ThrowingApiClient(),
      cacheStore: cacheStore,
    );

    final data = await repository.getFileData('reports/minimax.md');

    expect(data.text, contains('复盘内容'));
    expect(cacheStore.readPaths, <String>['reports/minimax.md']);
    expect(cacheStore.writePaths, isEmpty);
  });

  test('getFileData writes network response and reuses cache', () async {
    final cacheStore = _MemoryAgentFileCacheStore();
    final apiClient = _RecordingApiClient(
      LingAgentFileData(
        path: 'reports/daily.html',
        bytes: Uint8List.fromList(utf8.encode('<h1>日报</h1>')),
        contentType: 'text/html; charset=utf-8',
        filename: 'daily.html',
      ),
    );
    final repository = AgentFileRepository(
      apiClient: apiClient,
      cacheStore: cacheStore,
    );

    final first = await repository.getFileData('reports/daily.html');
    final second = await repository.getFileData('reports/daily.html');

    expect(first.text, second.text);
    expect(apiClient.requestedPaths, <String>['reports/daily.html']);
    expect(cacheStore.writePaths, <String>['reports/daily.html']);
    expect(cacheStore.readPaths, <String>[
      'reports/daily.html',
      'reports/daily.html',
    ]);
  });

  test('getFileData coalesces concurrent requests for same path', () async {
    final cacheStore = _MemoryAgentFileCacheStore();
    final apiClient = _RecordingApiClient(
      LingAgentFileData(
        path: 'upload_files/share.png',
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lXg1uwAAAABJRU5ErkJggg==',
        ),
        contentType: 'image/png',
        filename: 'share.png',
      ),
      delay: const Duration(milliseconds: 10),
    );
    final repository = AgentFileRepository(
      apiClient: apiClient,
      cacheStore: cacheStore,
    );

    final results = await Future.wait<LingAgentFileData>([
      repository.getFileData('upload_files/share.png'),
      repository.getFileData('upload_files/share.png'),
    ]);

    expect(results.first.bytes, results.last.bytes);
    expect(apiClient.requestedPaths, <String>['upload_files/share.png']);
    expect(cacheStore.writePaths, <String>['upload_files/share.png']);
  });
}

class _MemoryAgentFileCacheStore implements AgentFileCacheStore {
  final Map<String, LingAgentFileData> files = <String, LingAgentFileData>{};
  final List<String> readPaths = <String>[];
  final List<String> writePaths = <String>[];
  var clearCount = 0;

  @override
  Future<LingAgentFileData?> read(String path) async {
    readPaths.add(path);
    return files[path];
  }

  @override
  Future<void> write(String path, LingAgentFileData data) async {
    writePaths.add(path);
    files[path] = data;
  }

  @override
  Future<void> clear() async {
    clearCount += 1;
    files.clear();
  }
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient(this.data, {this.delay});

  final LingAgentFileData data;
  final Duration? delay;
  final List<String> requestedPaths = <String>[];

  @override
  Future<ApiBinaryResponse> getBytes(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    requestedPaths.add('${queryParameters?['path'] ?? ''}');
    final wait = delay;
    if (wait != null) {
      await Future<void>.delayed(wait);
    }
    return ApiBinaryResponse(
      bytes: data.bytes,
      statusCode: 200,
      headers: <String, String>{
        'content-type': data.contentType,
        'content-disposition': 'attachment; filename="${data.filename}"',
        'x-ling-agent-file-path': Uri.encodeFull(data.path),
      },
    );
  }
}

class _ThrowingApiClient extends ApiClient {
  @override
  Future<ApiBinaryResponse> getBytes(
    String path, {
    Map<String, Object?>? queryParameters,
  }) {
    throw StateError('network should not be called');
  }
}
