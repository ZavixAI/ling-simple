import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/logging/log_event.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/api_exception.dart';

void main() {
  test(
    'streamJsonEvents preserves event/data semantics for normal SSE',
    () async {
      final client = ApiClient(
        httpClient: _FakeHttpClient((request) async {
          expect(request.method, 'POST');
          return http.StreamedResponse(
            Stream<List<int>>.value(
              utf8.encode('event: update\ndata: {"step":1}\n\n'),
            ),
            200,
          );
        }),
      );

      final events = await client
          .streamJsonEvents('/agent/sse', body: {})
          .toList();

      expect(events, hasLength(1));
      expect(events.single['event'], 'update');
      expect(events.single['data'], {'step': 1});
    },
  );

  test('streamJsonEvents preserves SSE ids when present', () async {
    final client = ApiClient(
      httpClient: _FakeHttpClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.value(
            utf8.encode('id: 42-0\nevent: update\ndata: {"step":1}\n\n'),
          ),
          200,
        );
      }),
    );

    final events = await client
        .streamJsonEvents('/agent/sse', body: {})
        .toList();

    expect(events.single['id'], '42-0');
    expect(events.single['event'], 'update');
    expect(events.single['data'], {'step': 1});
  });

  test('streamJsonEvents emits SSE comments for heartbeat tracking', () async {
    final client = ApiClient(
      httpClient: _FakeHttpClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode(': heartbeat\n\n')),
          200,
        );
      }),
    );

    final events = await client
        .streamJsonEvents('/agent/sse', body: {}, logPayloads: false)
        .toList();

    expect(events, hasLength(1));
    expect(events.single['event'], 'sse_comment');
    expect(events.single['data'], {'comment': 'heartbeat'});
  });

  test('streamGetJsonEvents uses GET and query parameters', () async {
    final client = ApiClient(
      httpClient: _FakeHttpClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/ling-api/agent/events');
        expect(request.url.queryParameters['last_event_id'], '42-0');
        return http.StreamedResponse(
          Stream<List<int>>.value(
            utf8.encode('id: 43-0\nevent: agent_event\ndata: {"ok":true}\n\n'),
          ),
          200,
        );
      }),
    );

    final events = await client
        .streamGetJsonEvents(
          '/agent/events',
          queryParameters: const <String, Object?>{'last_event_id': '42-0'},
        )
        .toList();

    expect(events.single['id'], '43-0');
    expect(events.single['event'], 'agent_event');
    expect(events.single['data'], {'ok': true});
  });

  test(
    'streamJsonEvents flushes the final SSE event without trailing blank line',
    () async {
      final client = ApiClient(
        httpClient: _FakeHttpClient((request) async {
          return http.StreamedResponse(
            Stream<List<int>>.value(
              utf8.encode('event: update\ndata: {"step":2}'),
            ),
            200,
          );
        }),
      );

      final events = await client
          .streamJsonEvents('/agent/sse', body: {})
          .toList();

      expect(events, hasLength(1));
      expect(events.single['event'], 'update');
      expect(events.single['data'], {'step': 2});
    },
  );

  test(
    'streamJsonEvents still yields events when payload logging is disabled',
    () async {
      final client = ApiClient(
        httpClient: _FakeHttpClient((request) async {
          return http.StreamedResponse(
            Stream<List<int>>.value(
              utf8.encode('event: update\ndata: {"step":3}\n\n'),
            ),
            200,
          );
        }),
      );

      final events = await client
          .streamJsonEvents('/agent/sse', body: {}, logPayloads: false)
          .toList();

      expect(events, hasLength(1));
      expect(events.single['event'], 'update');
      expect(events.single['data'], {'step': 3});
    },
  );

  test('streamJsonEvents throws ApiException for non-2xx responses', () async {
    final client = ApiClient(
      httpClient: _FakeHttpClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.value(
            utf8.encode(
              '{"success":false,"message":"bad request","data":null}',
            ),
          ),
          500,
        );
      }),
    );

    expect(
      () => client.streamJsonEvents('/agent/sse', body: {}).toList(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'bad request',
        ),
      ),
    );
  });

  test(
    'streamJsonEvents treats local request abortion as normal SSE close',
    () async {
      final abortTrigger = Completer<void>();
      final client = ApiClient(
        httpClient: _FakeHttpClient((request) async {
          final abortableRequest = request as http.Abortable;
          final controller = StreamController<List<int>>();
          abortableRequest.abortTrigger!.then((_) {
            controller.addError(http.RequestAbortedException(request.url));
            unawaited(controller.close());
          });
          return http.StreamedResponse(controller.stream, 200);
        }),
      );

      final eventsFuture = client
          .streamJsonEvents(
            '/agent/sse',
            body: const {'prompt': 'hello'},
            abortTrigger: abortTrigger.future,
          )
          .toList();
      abortTrigger.complete();

      await expectLater(eventsFuture, completion(isEmpty));
    },
  );

  test(
    'delete rethrows the original 401 without leaking refresh failures globally',
    () async {
      final unhandledErrors = <Object>[];
      await runZonedGuarded(
        () async {
          final client = ApiClient(
            httpClient: _FakeHttpClient((request) async {
              if (request.url.path.endsWith('/me/push-devices/device-1')) {
                return http.StreamedResponse(
                  Stream<List<int>>.value(
                    utf8.encode(
                      jsonEncode(<String, Object?>{
                        'code': 401,
                        'message': 'access token expired',
                        'data': null,
                      }),
                    ),
                  ),
                  401,
                );
              }
              if (request.url.path.endsWith('/oauth2/token')) {
                return http.StreamedResponse(
                  Stream<List<int>>.value(
                    utf8.encode(
                      jsonEncode(<String, Object?>{
                        'code': 401,
                        'message': 'Invalid refresh token',
                        'data': null,
                      }),
                    ),
                  ),
                  401,
                );
              }
              throw StateError('Unexpected request: ${request.url}');
            }),
          );
          client
            ..setAccessToken('expired-access-token')
            ..setTokenRefreshHandler(() async {
              final response = await client.post(
                '/oauth2/token',
                body: const <String, Object?>{
                  'provider_id': 'local',
                  'grant_type': 'refresh_token',
                  'refresh_token': 'expired-refresh-token',
                },
              );
              return response.data as String;
            });

          await expectLater(
            client.delete('/me/push-devices/device-1'),
            throwsA(
              isA<ApiException>()
                  .having((error) => error.statusCode, 'statusCode', 401)
                  .having(
                    (error) => error.message,
                    'message',
                    'access token expired',
                  ),
            ),
          );
          await Future<void>.delayed(Duration.zero);
        },
        (error, stackTrace) {
          unhandledErrors.add(error);
        },
      );

      expect(unhandledErrors, isEmpty);
    },
  );

  test('auth token endpoint omits stale authorization header', () async {
    final observedHeaders = <String, Map<String, String>>{};
    final client = ApiClient(
      httpClient: _FakeHttpClient((request) async {
        observedHeaders[request.url.path] = Map<String, String>.from(
          request.headers,
        );
        return http.StreamedResponse(
          Stream<List<int>>.value(
            utf8.encode(
              jsonEncode(<String, Object?>{
                'code': 200,
                'message': 'success',
                'data': <String, Object?>{'ok': true},
              }),
            ),
          ),
          200,
        );
      }),
    )..setAccessToken('stale-access-token');

    await client.post(
      '/oauth2/token',
      body: const <String, Object?>{
        'provider_id': 'local',
        'grant_type': 'refresh_token',
        'refresh_token': 'valid-refresh-token',
      },
    );
    await client.get('/me');

    final tokenHeaders = _headersForPath(observedHeaders, '/oauth2/token');
    expect(_hasHeader(tokenHeaders, 'authorization'), isFalse);

    final profileHeaders = _headersForPath(observedHeaders, '/me');
    expect(
      _headerValue(profileHeaders, 'authorization'),
      'Bearer stale-access-token',
    );
  });

  test('get emits structured api log fields with request ids', () async {
    final capturedLogs = <LogEvent>[];
    final sinkToken = AppLogger.registerSink(
      capturedLogs.add,
      replayBacklog: false,
    );
    addTearDown(() => AppLogger.unregisterSink(sinkToken));

    final client = ApiClient(
      httpClient: _FakeHttpClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.value(
            utf8.encode(
              jsonEncode(<String, Object?>{
                'code': 200,
                'message': 'success',
                'data': <String, Object?>{'ok': true},
              }),
            ),
          ),
          200,
          headers: const <String, String>{'x-request-id': 'srv_123'},
        );
      }),
    );

    await client.get('/health');

    final responseLog = capturedLogs.lastWhere(
      (log) => log.category == 'api' && log.fields['status_code'] == 200,
    );
    expect(responseLog.fields['client_request_id'], isA<String>());
    expect(responseLog.fields['server_request_id'], 'srv_123');
    expect(responseLog.fields['path'], '/health');
  });
}

Map<String, String> _headersForPath(
  Map<String, Map<String, String>> observedHeaders,
  String suffix,
) {
  return observedHeaders.entries
      .singleWhere((entry) => entry.key.endsWith(suffix))
      .value;
}

bool _hasHeader(Map<String, String> headers, String name) {
  return headers.keys.any((key) => key.toLowerCase() == name.toLowerCase());
}

String? _headerValue(Map<String, String> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) {
      return entry.value;
    }
  }
  return null;
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}
