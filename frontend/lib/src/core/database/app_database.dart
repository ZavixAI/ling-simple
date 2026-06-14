import 'dart:convert' as json;

import 'package:drift/drift.dart';
import 'package:ling/src/core/database/database_connection.dart';
import 'package:ling/src/core/logging/log_event.dart';

part 'app_database.g.dart';

enum DebugLogBatchState { pending, uploading, uploaded }

class StoredJsonSnapshot {
  const StoredJsonSnapshot({required this.payload, required this.updatedAt});

  final String payload;
  final DateTime updatedAt;

  bool isFresh(Duration maxAge) =>
      DateTime.now().difference(updatedAt) <= maxAge;
}

class StoredConversationEntryRecord {
  const StoredConversationEntryRecord({
    required this.id,
    required this.isStreaming,
    required this.payload,
  });

  final String id;
  final bool isStreaming;
  final String payload;
}

class StoredConversationStateSnapshot {
  const StoredConversationStateSnapshot({
    required this.storageScope,
    required this.updatedAt,
    required this.conversation,
    this.sessionId,
  });

  final String storageScope;
  final String? sessionId;
  final DateTime updatedAt;
  final List<StoredConversationEntryRecord> conversation;
}

class StoredDebugLogEvent {
  const StoredDebugLogEvent({
    required this.id,
    required this.batchState,
    required this.level,
    required this.category,
    required this.message,
    required this.fields,
    required this.stackTrace,
    required this.createdAt,
    required this.approxBytes,
  });

  final String id;
  final DebugLogBatchState batchState;
  final LogLevel level;
  final String category;
  final String message;
  final Map<String, Object?> fields;
  final String? stackTrace;
  final DateTime createdAt;
  final int approxBytes;
}

class StoredDebugLogUploadCursor {
  const StoredDebugLogUploadCursor({
    required this.lastUploadedAt,
    required this.lastBatchId,
    required this.retryCount,
    required this.nextRetryAt,
  });

  final DateTime? lastUploadedAt;
  final String? lastBatchId;
  final int retryCount;
  final DateTime? nextRetryAt;
}

class StoredAnalyticsEventRecord {
  const StoredAnalyticsEventRecord({
    required this.id,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String payload;
  final DateTime createdAt;
}

class PendingDebugLogStats {
  const PendingDebugLogStats({required this.count, required this.approxBytes});

  final int count;
  final int approxBytes;
}

class ProfileSnapshots extends Table {
  IntColumn get id => integer()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CalendarDayCaches extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get date => text()();
  TextColumn get timezone => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}

class CalendarMonthCaches extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get month => text()();
  TextColumn get timezone => text()();
  TextColumn get selectedDate => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}

class ConversationSessions extends Table {
  TextColumn get storageScope => text()();
  TextColumn get sessionId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {storageScope};
}

class ConversationEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get storageScope => text()();
  IntColumn get orderIndex => integer()();
  TextColumn get entryId => text()();
  BoolColumn get isStreaming => boolean().withDefault(const Constant(false))();
  TextColumn get payload => text()();
}

class DebugLogEvents extends Table {
  TextColumn get id => text()();
  TextColumn get batchState => text().withDefault(const Constant('pending'))();
  TextColumn get level => text()();
  TextColumn get category => text()();
  TextColumn get message => text()();
  TextColumn get fieldsJson => text().withDefault(const Constant('{}'))();
  TextColumn get stackTrace => text().nullable()();
  IntColumn get approxBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DebugLogUploadCursor extends Table {
  IntColumn get singletonId => integer()();
  DateTimeColumn get lastUploadedAt => dateTime().nullable()();
  TextColumn get lastBatchId => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {singletonId};
}

@DriftDatabase(
  tables: [
    ProfileSnapshots,
    CalendarDayCaches,
    CalendarMonthCaches,
    ConversationSessions,
    ConversationEntries,
    DebugLogEvents,
    DebugLogUploadCursor,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? openDatabaseConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createAnalyticsEventQueue();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(debugLogEvents);
        await m.createTable(debugLogUploadCursor);
      }
      if (from < 3) {
        await _createAnalyticsEventQueue();
      }
    },
  );

  Future<void> saveProfilePayload(String payload) async {
    await into(profileSnapshots).insertOnConflictUpdate(
      ProfileSnapshotsCompanion.insert(
        id: const Value(1),
        payload: payload,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<StoredJsonSnapshot?> readProfilePayload({Duration? maxAge}) async {
    final row = await (select(
      profileSnapshots,
    )..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    if (!_isFresh(row.updatedAt, maxAge)) {
      return null;
    }
    return StoredJsonSnapshot(payload: row.payload, updatedAt: row.updatedAt);
  }

  Future<void> clearProfile() async {
    await delete(profileSnapshots).go();
  }

  Future<void> saveCalendarDayPayload({
    required String date,
    required String timezone,
    required String payload,
  }) async {
    final cacheKey = _calendarDayKey(date, timezone);
    await into(calendarDayCaches).insertOnConflictUpdate(
      CalendarDayCachesCompanion.insert(
        cacheKey: cacheKey,
        date: date,
        timezone: timezone,
        payload: payload,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<StoredJsonSnapshot?> readCalendarDayPayload({
    required String date,
    required String timezone,
    Duration? maxAge,
  }) async {
    final row =
        await (select(calendarDayCaches)..where(
              (tbl) => tbl.cacheKey.equals(_calendarDayKey(date, timezone)),
            ))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }
    if (!_isFresh(row.updatedAt, maxAge)) {
      return null;
    }
    return StoredJsonSnapshot(payload: row.payload, updatedAt: row.updatedAt);
  }

  Future<void> saveCalendarMonthPayload({
    required String month,
    required String timezone,
    required String selectedDate,
    required String payload,
  }) async {
    final cacheKey = _calendarMonthKey(month, timezone, selectedDate);
    await into(calendarMonthCaches).insertOnConflictUpdate(
      CalendarMonthCachesCompanion.insert(
        cacheKey: cacheKey,
        month: month,
        timezone: timezone,
        selectedDate: selectedDate,
        payload: payload,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<StoredJsonSnapshot?> readCalendarMonthPayload({
    required String month,
    required String timezone,
    required String selectedDate,
    Duration? maxAge,
  }) async {
    final row =
        await (select(calendarMonthCaches)..where(
              (tbl) => tbl.cacheKey.equals(
                _calendarMonthKey(month, timezone, selectedDate),
              ),
            ))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }
    if (!_isFresh(row.updatedAt, maxAge)) {
      return null;
    }
    return StoredJsonSnapshot(payload: row.payload, updatedAt: row.updatedAt);
  }

  Future<void> clearCalendarDayCaches() async {
    await delete(calendarDayCaches).go();
  }

  Future<void> clearCalendarMonthCaches() async {
    await delete(calendarMonthCaches).go();
  }

  Future<void> saveConversationState({
    required String storageScope,
    required String? sessionId,
    required List<StoredConversationEntryRecord> conversation,
    DateTime? updatedAtOverride,
  }) async {
    await transaction(() async {
      await into(conversationSessions).insertOnConflictUpdate(
        ConversationSessionsCompanion.insert(
          storageScope: storageScope,
          sessionId: Value(sessionId),
          updatedAt: updatedAtOverride ?? DateTime.now(),
        ),
      );
      await (delete(
        conversationEntries,
      )..where((tbl) => tbl.storageScope.equals(storageScope))).go();
      for (var index = 0; index < conversation.length; index += 1) {
        final entry = conversation[index];
        await into(conversationEntries).insert(
          ConversationEntriesCompanion.insert(
            storageScope: storageScope,
            orderIndex: index,
            entryId: entry.id,
            isStreaming: Value(entry.isStreaming),
            payload: entry.payload,
          ),
        );
      }
    });
  }

  Future<StoredConversationStateSnapshot?> readConversationState(
    String storageScope,
  ) async {
    final session = await (select(
      conversationSessions,
    )..where((tbl) => tbl.storageScope.equals(storageScope))).getSingleOrNull();
    if (session == null) {
      return null;
    }
    final rows =
        await (select(conversationEntries)
              ..where((tbl) => tbl.storageScope.equals(storageScope))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.orderIndex)]))
            .get();
    final conversation = rows
        .map(
          (row) => StoredConversationEntryRecord(
            id: row.entryId,
            isStreaming: row.isStreaming,
            payload: row.payload,
          ),
        )
        .toList(growable: false);
    return StoredConversationStateSnapshot(
      storageScope: storageScope,
      sessionId: session.sessionId,
      updatedAt: session.updatedAt,
      conversation: conversation,
    );
  }

  Future<void> clearConversationState(String storageScope) async {
    await transaction(() async {
      await (delete(
        conversationEntries,
      )..where((tbl) => tbl.storageScope.equals(storageScope))).go();
      await (delete(
        conversationSessions,
      )..where((tbl) => tbl.storageScope.equals(storageScope))).go();
    });
  }

  Future<void> insertDebugLogEvent(LogEvent event) async {
    final fieldsJson = _encodeJson(event.fields);
    await into(debugLogEvents).insert(
      DebugLogEventsCompanion.insert(
        id: event.id,
        batchState: Value(DebugLogBatchState.pending.name),
        level: event.levelLabel,
        category: event.category,
        message: event.message,
        fieldsJson: Value(fieldsJson),
        stackTrace: Value(event.stackTrace),
        approxBytes: Value(
          event.message.length +
              fieldsJson.length +
              (event.stackTrace?.length ?? 0),
        ),
        createdAt: event.createdAt,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> ensureDebugLogCursor() async {
    await into(debugLogUploadCursor).insertOnConflictUpdate(
      DebugLogUploadCursorCompanion.insert(
        singletonId: const Value(1),
        retryCount: Value(0),
      ),
    );
  }

  Future<StoredDebugLogUploadCursor?> readDebugLogUploadCursor() async {
    final row = await (select(
      debugLogUploadCursor,
    )..where((tbl) => tbl.singletonId.equals(1))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return StoredDebugLogUploadCursor(
      lastUploadedAt: row.lastUploadedAt,
      lastBatchId: row.lastBatchId,
      retryCount: row.retryCount,
      nextRetryAt: row.nextRetryAt,
    );
  }

  Future<void> upsertDebugLogUploadCursor({
    DateTime? lastUploadedAt,
    String? lastBatchId,
    int? retryCount,
    DateTime? nextRetryAt,
  }) async {
    await ensureDebugLogCursor();
    await into(debugLogUploadCursor).insertOnConflictUpdate(
      DebugLogUploadCursorCompanion(
        singletonId: const Value(1),
        lastUploadedAt: Value(lastUploadedAt),
        lastBatchId: Value(lastBatchId),
        retryCount: Value(retryCount ?? 0),
        nextRetryAt: Value(nextRetryAt),
      ),
    );
  }

  Future<PendingDebugLogStats> readPendingDebugLogStats() async {
    final rows =
        await (select(debugLogEvents)..where(
              (tbl) => tbl.batchState.equals(DebugLogBatchState.pending.name),
            ))
            .get();
    final approxBytes = rows.fold<int>(
      0,
      (total, row) => total + row.approxBytes,
    );
    return PendingDebugLogStats(count: rows.length, approxBytes: approxBytes);
  }

  Future<List<StoredDebugLogEvent>> readDebugLogEventsByState(
    DebugLogBatchState state,
  ) async {
    final rows =
        await (select(debugLogEvents)
              ..where((tbl) => tbl.batchState.equals(state.name))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
            .get();
    return rows.map(_mapDebugLogEventRow).toList(growable: false);
  }

  Future<List<StoredDebugLogEvent>> readAllDebugLogEvents() async {
    final rows = await (select(
      debugLogEvents,
    )..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)])).get();
    return rows.map(_mapDebugLogEventRow).toList(growable: false);
  }

  Future<void> updateDebugLogBatchState(
    List<String> ids,
    DebugLogBatchState state,
  ) async {
    if (ids.isEmpty) {
      return;
    }
    await (update(debugLogEvents)..where((tbl) => tbl.id.isIn(ids))).write(
      DebugLogEventsCompanion(batchState: Value(state.name)),
    );
  }

  Future<void> deleteDebugLogEventsByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await (delete(debugLogEvents)..where((tbl) => tbl.id.isIn(ids))).go();
  }

  Future<void> deleteDebugLogEventsOlderThan(DateTime before) async {
    await (delete(
      debugLogEvents,
    )..where((tbl) => tbl.createdAt.isSmallerThanValue(before))).go();
  }

  Future<void> clearAllDebugLogs() async {
    await transaction(() async {
      await delete(debugLogEvents).go();
      await delete(debugLogUploadCursor).go();
    });
  }

  Future<void> enqueueAnalyticsEvent({
    required String id,
    required String payload,
  }) async {
    await customInsert(
      '''
      INSERT OR REPLACE INTO analytics_event_queue (id, payload, created_at)
      VALUES (?, ?, ?)
      ''',
      variables: [
        Variable<String>(id),
        Variable<String>(payload),
        Variable<String>(DateTime.now().toIso8601String()),
      ],
    );
  }

  Future<List<StoredAnalyticsEventRecord>> readPendingAnalyticsEvents({
    int limit = 100,
  }) async {
    final rows = await customSelect(
      '''
      SELECT id, payload, created_at
      FROM analytics_event_queue
      ORDER BY created_at ASC
      LIMIT ?
      ''',
      variables: [Variable<int>(limit)],
      readsFrom: const {},
    ).get();
    return rows
        .map((row) {
          return StoredAnalyticsEventRecord(
            id: row.read<String>('id'),
            payload: row.read<String>('payload'),
            createdAt:
                DateTime.tryParse(row.read<String>('created_at')) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          );
        })
        .toList(growable: false);
  }

  Future<void> deleteAnalyticsEventsByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final placeholders = List<String>.filled(ids.length, '?').join(', ');
    await customStatement(
      'DELETE FROM analytics_event_queue WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<void> clearAllUserData() async {
    await transaction(() async {
      await delete(profileSnapshots).go();
      await delete(calendarDayCaches).go();
      await delete(calendarMonthCaches).go();
      await delete(conversationEntries).go();
      await delete(conversationSessions).go();
      await delete(debugLogEvents).go();
      await delete(debugLogUploadCursor).go();
      await customStatement('DELETE FROM analytics_event_queue');
    });
  }

  Future<void> _createAnalyticsEventQueue() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS analytics_event_queue (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS ix_analytics_event_queue_created_at '
      'ON analytics_event_queue (created_at)',
    );
  }

  String _calendarDayKey(String date, String timezone) => '$date::$timezone';

  String _calendarMonthKey(
    String month,
    String timezone,
    String selectedDate,
  ) => '$month::$timezone::$selectedDate';

  bool _isFresh(DateTime updatedAt, Duration? maxAge) {
    if (maxAge == null) {
      return true;
    }
    return DateTime.now().difference(updatedAt) <= maxAge;
  }

  StoredDebugLogEvent _mapDebugLogEventRow(DebugLogEvent row) {
    final level = switch (row.level.trim().toUpperCase()) {
      'DEBUG' => LogLevel.debug,
      'WARN' => LogLevel.warn,
      'ERROR' => LogLevel.error,
      _ => LogLevel.info,
    };
    final batchState = switch (row.batchState.trim()) {
      'uploading' => DebugLogBatchState.uploading,
      'uploaded' => DebugLogBatchState.uploaded,
      _ => DebugLogBatchState.pending,
    };
    return StoredDebugLogEvent(
      id: row.id,
      batchState: batchState,
      level: level,
      category: row.category,
      message: row.message,
      fields: _decodeFields(row.fieldsJson),
      stackTrace: row.stackTrace,
      createdAt: row.createdAt,
      approxBytes: row.approxBytes,
    );
  }

  Map<String, Object?> _decodeFields(String fieldsJson) {
    final decoded = _decodeJson(fieldsJson);
    if (decoded is Map<String, dynamic>) {
      return decoded.map((key, value) => MapEntry(key, value));
    }
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
    return const <String, Object?>{};
  }

  Object? _decodeJson(String value) {
    try {
      return json.jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  String _encodeJson(Map<String, Object?> value) {
    return json.jsonEncode(value);
  }
}
