import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:ling/src/config/app_environment.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/network/api_response.dart';

typedef TokenRefreshCallback = Future<String> Function();

class ApiBinaryResponse {
  const ApiBinaryResponse({
    required this.bytes,
    required this.statusCode,
    required this.headers,
  });

  final Uint8List bytes;
  final int statusCode;
  final Map<String, String> headers;
}

class ApiClient {
  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const Duration _requestTimeout = Duration(seconds: 60);
  static const _authPaths = {'/oauth2/token', '/oauth2/revoke'};
  static int _requestSequence = 0;

  final http.Client _httpClient;
  String? _accessToken;
  String? _localeCode;
  TokenRefreshCallback? _onTokenRefresh;
  Future<String>? _activeRefresh;

  void setTokenRefreshHandler(TokenRefreshCallback? handler) {
    _onTokenRefresh = handler;
  }

  Future<ApiResponse> get(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    return _send('GET', path, queryParameters: queryParameters);
  }

  Future<ApiBinaryResponse> getBytes(
    String path, {
    Map<String, Object?>? queryParameters,
  }) {
    return _sendBytes('GET', path, queryParameters: queryParameters);
  }

  Future<ApiResponse> post(String path, {Object? body}) {
    return _send('POST', path, body: body);
  }

  Future<ApiResponse> patch(String path, {Object? body}) {
    return _send('PATCH', path, body: body);
  }

  Future<ApiResponse> delete(
    String path, {
    Map<String, Object?>? queryParameters,
  }) {
    return _send('DELETE', path, queryParameters: queryParameters);
  }

  Future<ApiResponse> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    List<int>? fileBytes,
    String fileField = 'file',
    String filename = 'recording.m4a',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      AppEnvironment.endpoint(path),
    );
    request.headers.addAll(
      _headers(
        accept: 'application/json',
        includeAuthorization: !_authPaths.contains(path),
      ),
    );
    request.fields.addAll(fields);

    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(fileField, fileBytes, filename: filename),
      );
    }

    final streamed = await _sendMultipart(request);
    final response = await http.Response.fromStream(
      streamed,
    ).timeout(_requestTimeout);
    return _decodeResponse(response);
  }

  Stream<Map<String, dynamic>> streamJsonEvents(
    String path, {
    required Object body,
    bool logPayloads = true,
    Future<void>? abortTrigger,
  }) {
    return _streamJsonEvents(
      'POST',
      path,
      body: body,
      logPayloads: logPayloads,
      abortTrigger: abortTrigger,
    );
  }

  Stream<Map<String, dynamic>> streamGetJsonEvents(
    String path, {
    Map<String, Object?>? queryParameters,
    bool logPayloads = true,
    Future<void>? abortTrigger,
  }) {
    return _streamJsonEvents(
      'GET',
      path,
      queryParameters: queryParameters,
      logPayloads: logPayloads,
      abortTrigger: abortTrigger,
    );
  }

  Stream<Map<String, dynamic>> _streamJsonEvents(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? queryParameters,
    bool logPayloads = true,
    Future<void>? abortTrigger,
  }) async* {
    final clientRequestId = _nextClientRequestId();
    final request = http.AbortableRequest(
      method,
      AppEnvironment.endpoint(path, queryParameters: queryParameters),
      abortTrigger: abortTrigger,
    );
    request.headers.addAll(
      _headers(
        accept: 'text/event-stream',
        contentType: 'application/json',
        includeAuthorization: !_authPaths.contains(path),
      ),
    );
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final startedAt = DateTime.now();
    AppLogger.info(
      '[Ling][SSE] --> $method ${request.url}',
      category: 'sse',
      fields: _requestLogFields(
        clientRequestId: clientRequestId,
        method: request.method,
        path: path,
        url: request.url,
      ),
    );

    http.StreamedResponse response;
    try {
      response = await _httpClient.send(request).timeout(_requestTimeout);
    } on http.RequestAbortedException {
      AppLogger.info(
        '[Ling][SSE] xx> $method ${request.url} 响应前已中止',
        category: 'sse',
        fields: _requestLogFields(
          clientRequestId: clientRequestId,
          method: request.method,
          path: path,
          url: request.url,
        ),
      );
      return;
    } catch (error) {
      AppLogger.error(
        '[Ling][SSE] xx> $method ${request.url} 请求出错 error=$error',
        category: 'sse',
        fields: _requestLogFields(
          clientRequestId: clientRequestId,
          method: request.method,
          path: path,
          url: request.url,
        ),
      );
      throw ApiException(message: '流式请求失败，请检查网络或后端服务。', cause: error);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final failure = await http.Response.fromStream(response);
      throw _decodeError(failure);
    }
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
    AppLogger.info(
      '[Ling][SSE] <-- $method ${request.url} status=${response.statusCode} ${elapsed}ms',
      category: 'sse',
      fields: _responseLogFields(
        clientRequestId: clientRequestId,
        method: request.method,
        path: path,
        url: request.url,
        statusCode: response.statusCode,
        elapsedMs: elapsed,
        serverRequestId: response.headers['x-request-id'],
      ),
    );

    String? event;
    String? eventId;
    final dataLines = <String>[];
    try {
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.isEmpty) {
          final payload = _decodeSsePayload(
            id: eventId,
            event: event,
            dataLines: dataLines,
          );
          if (payload != null) {
            if (logPayloads) {
              _logSsePayload(payload, clientRequestId: clientRequestId);
            }
            yield payload;
          }
          eventId = null;
          event = null;
          dataLines.clear();
          continue;
        }

        if (line.startsWith('id:')) {
          eventId = line.substring(3).trim();
        } else if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        } else if (line.startsWith(':')) {
          yield <String, dynamic>{
            'event': 'sse_comment',
            'data': <String, dynamic>{'comment': line.substring(1).trim()},
          };
        }
      }
    } on http.RequestAbortedException {
      AppLogger.info(
        '[Ling][SSE] xx> $method ${request.url} 响应流中已中止',
        category: 'sse',
        fields: _requestLogFields(
          clientRequestId: clientRequestId,
          method: request.method,
          path: path,
          url: request.url,
        ),
      );
      return;
    }
    final payload = _decodeSsePayload(
      id: eventId,
      event: event,
      dataLines: dataLines,
    );
    if (payload != null) {
      if (logPayloads) {
        _logSsePayload(payload, clientRequestId: clientRequestId);
      }
      yield payload;
    }
  }

  void setAccessToken(String? accessToken) {
    _accessToken = accessToken;
  }

  void setLocaleCode(String? localeCode) {
    final normalized = (localeCode ?? '').trim();
    _localeCode = normalized.isEmpty ? null : normalized;
  }

  void dispose() {
    _httpClient.close();
  }

  Future<ApiResponse> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? queryParameters,
  }) async {
    try {
      return await _sendOnce(
        method,
        path,
        body: body,
        queryParameters: queryParameters,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401 &&
          _onTokenRefresh != null &&
          !_authPaths.contains(path)) {
        try {
          await _performTokenRefresh();
          return await _sendOnce(
            method,
            path,
            body: body,
            queryParameters: queryParameters,
          );
        } catch (_) {
          throw e;
        }
      }
      rethrow;
    }
  }

  Future<ApiBinaryResponse> _sendBytes(
    String method,
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    try {
      return await _sendBytesOnce(
        method,
        path,
        queryParameters: queryParameters,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401 &&
          _onTokenRefresh != null &&
          !_authPaths.contains(path)) {
        try {
          await _performTokenRefresh();
          return await _sendBytesOnce(
            method,
            path,
            queryParameters: queryParameters,
          );
        } catch (_) {
          throw e;
        }
      }
      rethrow;
    }
  }

  Future<void> _performTokenRefresh() async {
    if (_activeRefresh != null) {
      await _activeRefresh!;
      return;
    }

    final refreshFuture = _onTokenRefresh!().then((newToken) {
      _accessToken = newToken;
      return newToken;
    });
    _activeRefresh = refreshFuture;
    try {
      await refreshFuture;
    } finally {
      _activeRefresh = null;
    }
  }

  Future<ApiResponse> _sendOnce(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? queryParameters,
  }) async {
    final clientRequestId = _nextClientRequestId();
    final request = http.Request(
      method,
      AppEnvironment.endpoint(path, queryParameters: queryParameters),
    );
    request.headers.addAll(
      _headers(
        contentType: 'application/json; charset=UTF-8',
        includeAuthorization: !_authPaths.contains(path),
      ),
    );
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final startedAt = DateTime.now();
    AppLogger.debug(
      '[Ling][Api] --> $method ${request.url}',
      category: 'api',
      fields: _requestLogFields(
        clientRequestId: clientRequestId,
        method: method,
        path: path,
        url: request.url,
      ),
    );

    try {
      final streamed = await _httpClient.send(request).timeout(_requestTimeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(_requestTimeout);
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      AppLogger.debug(
        '[Ling][Api] <-- $method ${request.url} '
        'status=${response.statusCode} ${elapsed}ms',
        category: 'api',
        fields: _responseLogFields(
          clientRequestId: clientRequestId,
          method: method,
          path: path,
          url: request.url,
          statusCode: response.statusCode,
          elapsedMs: elapsed,
          serverRequestId: response.headers['x-request-id'],
        ),
      );
      return _decodeResponse(response);
    } on ApiException {
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      AppLogger.warn(
        '[Ling][Api] xx> $method ${request.url} ApiException ${elapsed}ms',
        category: 'api',
        fields: _requestLogFields(
          clientRequestId: clientRequestId,
          method: method,
          path: path,
          url: request.url,
          elapsedMs: elapsed,
        ),
      );
      rethrow;
    } on TimeoutException catch (error) {
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      AppLogger.warn(
        '[Ling][Api] xx> $method ${request.url} 请求超时 ${elapsed}ms',
        category: 'api',
        fields: _requestLogFields(
          clientRequestId: clientRequestId,
          method: method,
          path: path,
          url: request.url,
          elapsedMs: elapsed,
        ),
      );
      throw ApiException(
        message: _buildTimeoutMessage(request.url),
        cause: error,
      );
    } catch (error) {
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      AppLogger.error(
        '[Ling][Api] xx> $method ${request.url} 请求出错 ${elapsed}ms error=$error',
        category: 'api',
        fields: _requestLogFields(
          clientRequestId: clientRequestId,
          method: method,
          path: path,
          url: request.url,
          elapsedMs: elapsed,
        ),
      );
      throw ApiException(
        message: _buildNetworkFailureMessage(request.url, error),
        cause: error,
      );
    }
  }

  Future<ApiBinaryResponse> _sendBytesOnce(
    String method,
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    final clientRequestId = _nextClientRequestId();
    final request = http.Request(
      method,
      AppEnvironment.endpoint(path, queryParameters: queryParameters),
    );
    request.headers.addAll(
      _headers(
        accept: '*/*',
        contentType: null,
        includeAuthorization: !_authPaths.contains(path),
      ),
    );
    final startedAt = DateTime.now();
    AppLogger.debug(
      '[Ling][Api] --> $method ${request.url}',
      category: 'api',
      fields: _requestLogFields(
        clientRequestId: clientRequestId,
        method: method,
        path: path,
        url: request.url,
      ),
    );

    try {
      final streamed = await _httpClient.send(request).timeout(_requestTimeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(_requestTimeout);
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      AppLogger.debug(
        '[Ling][Api] <-- $method ${request.url} '
        'status=${response.statusCode} ${elapsed}ms bytes=${response.bodyBytes.length}',
        category: 'api',
        fields: _responseLogFields(
          clientRequestId: clientRequestId,
          method: method,
          path: path,
          url: request.url,
          statusCode: response.statusCode,
          elapsedMs: elapsed,
          serverRequestId: response.headers['x-request-id'],
        ),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _decodeError(response);
      }
      return ApiBinaryResponse(
        bytes: Uint8List.fromList(response.bodyBytes),
        statusCode: response.statusCode,
        headers: Map<String, String>.unmodifiable(response.headers),
      );
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiException(
        message: _buildTimeoutMessage(request.url),
        cause: error,
      );
    } catch (error) {
      throw ApiException(
        message: _buildNetworkFailureMessage(request.url, error),
        cause: error,
      );
    }
  }

  Future<http.StreamedResponse> _sendMultipart(
    http.MultipartRequest request,
  ) async {
    final clientRequestId = _nextClientRequestId();
    final startedAt = DateTime.now();
    AppLogger.debug(
      '[Ling][Api] --> ${request.method} ${request.url} multipart 上传',
      category: 'api',
      fields: _requestLogFields(
        clientRequestId: clientRequestId,
        method: request.method,
        path: request.url.path,
        url: request.url,
      ),
    );
    try {
      final response = await _httpClient.send(request).timeout(_requestTimeout);
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      AppLogger.debug(
        '[Ling][Api] <-- ${request.method} ${request.url} '
        'status=${response.statusCode} ${elapsed}ms multipart 上传',
        category: 'api',
        fields: _responseLogFields(
          clientRequestId: clientRequestId,
          method: request.method,
          path: request.url.path,
          url: request.url,
          statusCode: response.statusCode,
          elapsedMs: elapsed,
          serverRequestId: response.headers['x-request-id'],
        ),
      );
      return response;
    } on TimeoutException catch (error) {
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      AppLogger.warn(
        '[Ling][Api] xx> ${request.method} ${request.url} 请求超时 ${elapsed}ms multipart 上传',
        category: 'api',
        fields: _requestLogFields(
          clientRequestId: clientRequestId,
          method: request.method,
          path: request.url.path,
          url: request.url,
          elapsedMs: elapsed,
        ),
      );
      throw ApiException(
        message: _buildTimeoutMessage(request.url),
        cause: error,
      );
    } catch (error) {
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      AppLogger.error(
        '[Ling][Api] xx> ${request.method} ${request.url} 请求出错 ${elapsed}ms multipart 上传 error=$error',
        category: 'api',
        fields: _requestLogFields(
          clientRequestId: clientRequestId,
          method: request.method,
          path: request.url.path,
          url: request.url,
          elapsedMs: elapsed,
        ),
      );
      throw ApiException(
        message: _buildNetworkFailureMessage(request.url, error),
        cause: error,
      );
    }
  }

  ApiResponse _decodeResponse(http.Response response) {
    final payload = _decodePayload(response.bodyBytes);
    if (payload is! Map<String, dynamic>) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          code: response.statusCode,
          message: '',
          data: payload,
          timestamp: null,
        );
      }
      throw ApiException(
        message: _buildUnexpectedErrorMessage(payload),
        statusCode: response.statusCode,
        cause: payload,
      );
    }

    final envelope = ApiResponse.fromJson(payload);
    final hasEnvelopeFields =
        payload.containsKey('code') ||
        payload.containsKey('message') ||
        payload.containsKey('data') ||
        payload.containsKey('timestamp');
    if (!hasEnvelopeFields &&
        response.statusCode >= 200 &&
        response.statusCode < 300) {
      return ApiResponse(
        code: response.statusCode,
        message: '',
        data: payload,
        timestamp: null,
      );
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        !envelope.isSuccess) {
      throw ApiException(
        message: envelope.message.isEmpty ? '接口请求失败' : envelope.message,
        statusCode: response.statusCode,
        cause: payload,
      );
    }

    return envelope;
  }

  ApiException _decodeError(http.Response response) {
    final payload = _decodePayload(response.bodyBytes);
    if (payload is Map<String, dynamic>) {
      final envelope = ApiResponse.fromJson(payload);
      return ApiException(
        message: envelope.message,
        statusCode: response.statusCode,
        cause: payload,
      );
    }
    return ApiException(
      message: _buildUnexpectedErrorMessage(payload),
      statusCode: response.statusCode,
      cause: payload,
    );
  }

  String _buildUnexpectedErrorMessage(Object? payload) {
    final snippet = _payloadSnippet(payload);
    if (snippet.isEmpty) {
      return '接口返回格式异常，响应内容为空。';
    }
    return '接口返回格式异常，响应内容：$snippet';
  }

  String _payloadSnippet(Object? payload) {
    if (payload == null) {
      return '';
    }
    if (payload is String) {
      final text = payload.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) {
        return '';
      }
      return text.length > 160 ? '${text.substring(0, 160)}…' : text;
    }
    if (payload is List) {
      final text = jsonEncode(payload);
      return text.length > 160 ? '${text.substring(0, 160)}…' : text;
    }
    return payload.toString();
  }

  Object? _decodePayload(List<int> bodyBytes) {
    if (bodyBytes.isEmpty) {
      return null;
    }

    final body = utf8.decode(bodyBytes);
    try {
      return jsonDecode(body);
    } catch (error) {
      throw ApiException(message: '接口返回内容不是合法的 JSON。', cause: error);
    }
  }

  Map<String, dynamic>? _decodeSsePayload({
    required String? id,
    required String? event,
    required List<String> dataLines,
  }) {
    if (dataLines.isEmpty) {
      return null;
    }
    final raw = dataLines.join('\n');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final payload = <String, dynamic>{
      'event': event ?? 'message',
      'data': decoded,
    };
    if (id != null && id.isNotEmpty) {
      payload['id'] = id;
    }
    return payload;
  }

  void _logSsePayload(
    Map<String, dynamic> payload, {
    required String clientRequestId,
  }) {
    final eventName = '${payload['event'] ?? 'message'}'.trim();
    final data = payload['data'];
    final encoded = _safeJsonEncode(data);
    final item = data is Map<String, dynamic>
        ? data['item']
        : data is Map
        ? Map<String, dynamic>.from(data)['item']
        : null;
    final isStreamingConversationEntry =
        eventName == 'conversation_entry' &&
        ((item is Map<String, dynamic> && item['is_streaming'] == true) ||
            (item is Map && item['is_streaming'] == true));
    if (isStreamingConversationEntry) {
      AppLogger.debug(
        '[Ling][SSE] event=$eventName data=$encoded',
        category: 'sse',
        fields: <String, Object?>{
          'client_request_id': clientRequestId,
          'event': eventName,
          'payload': data,
        },
      );
      return;
    }
    AppLogger.info(
      '[Ling][SSE] event=$eventName data=$encoded',
      category: 'sse',
      fields: <String, Object?>{
        'client_request_id': clientRequestId,
        'event': eventName,
        'payload': data,
      },
    );
  }

  String _safeJsonEncode(Object? value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return '$value';
    }
  }

  Map<String, String> _headers({
    String accept = 'application/json',
    String? contentType = 'application/json; charset=UTF-8',
    bool includeAuthorization = true,
  }) {
    final headers = <String, String>{'Accept': accept};
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    final localeCode = _localeCode;
    if (localeCode != null && localeCode.isNotEmpty) {
      headers['Accept-Language'] = localeCode;
      headers['X-Ling-Locale'] = localeCode;
    }
    final accessToken = _accessToken;
    if (includeAuthorization && accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  String _buildTimeoutMessage(Uri url) {
    final buffer = StringBuffer('请求超时：$url');
    final hint = _localNetworkHint(url);
    if (hint != null) {
      buffer.write('。$hint');
    }
    return buffer.toString();
  }

  String _buildNetworkFailureMessage(Uri url, Object error) {
    final buffer = StringBuffer('网络请求失败：无法访问 $url');
    final hint = _localNetworkHint(url);
    if (hint != null) {
      buffer.write('。$hint');
    }

    final details = _errorDetails(error);
    if (details != null) {
      buffer.write(' 原因：$details');
    }
    return buffer.toString();
  }

  String? _localNetworkHint(Uri url) {
    if (!_isLocalDevelopmentHost(url.host)) {
      return null;
    }
    return '如果这是 iPhone 真机联调，请确认应用已允许“本地网络”权限，并让手机与电脑连接同一 Wi-Fi';
  }

  bool _isLocalDevelopmentHost(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }

    if (host.startsWith('10.') || host.startsWith('192.168.')) {
      return true;
    }

    final segments = host.split('.');
    if (segments.length != 4 || segments[0] != '172') {
      return false;
    }

    final second = int.tryParse(segments[1]);
    return second != null && second >= 16 && second <= 31;
  }

  String? _errorDetails(Object error) {
    final details = error.toString().trim();
    return details.isEmpty ? null : details;
  }

  String _nextClientRequestId() {
    _requestSequence += 1;
    return 'creq_${DateTime.now().microsecondsSinceEpoch}_$_requestSequence';
  }

  Map<String, Object?> _requestLogFields({
    required String clientRequestId,
    required String method,
    required String path,
    required Uri url,
    int? elapsedMs,
  }) {
    return <String, Object?>{
      'client_request_id': clientRequestId,
      'method': method,
      'path': path,
      'url': url.toString(),
      'elapsed_ms': elapsedMs,
    };
  }

  Map<String, Object?> _responseLogFields({
    required String clientRequestId,
    required String method,
    required String path,
    required Uri url,
    required int statusCode,
    required int elapsedMs,
    String? serverRequestId,
  }) {
    return <String, Object?>{
      'client_request_id': clientRequestId,
      'server_request_id': serverRequestId,
      'method': method,
      'path': path,
      'url': url.toString(),
      'status_code': statusCode,
      'elapsed_ms': elapsedMs,
    };
  }
}
