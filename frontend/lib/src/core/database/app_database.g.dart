// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProfileSnapshotsTable extends ProfileSnapshots
    with TableInfo<$ProfileSnapshotsTable, ProfileSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProfileSnapshotsTable createAlias(String alias) {
    return $ProfileSnapshotsTable(attachedDatabase, alias);
  }
}

class ProfileSnapshot extends DataClass implements Insertable<ProfileSnapshot> {
  final int id;
  final String payload;
  final DateTime updatedAt;
  const ProfileSnapshot({
    required this.id,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProfileSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ProfileSnapshotsCompanion(
      id: Value(id),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProfileSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileSnapshot(
      id: serializer.fromJson<int>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProfileSnapshot copyWith({int? id, String? payload, DateTime? updatedAt}) =>
      ProfileSnapshot(
        id: id ?? this.id,
        payload: payload ?? this.payload,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ProfileSnapshot copyWithCompanion(ProfileSnapshotsCompanion data) {
    return ProfileSnapshot(
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileSnapshot(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileSnapshot &&
          other.id == this.id &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class ProfileSnapshotsCompanion extends UpdateCompanion<ProfileSnapshot> {
  final Value<int> id;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  const ProfileSnapshotsCompanion({
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ProfileSnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required String payload,
    required DateTime updatedAt,
  }) : payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<ProfileSnapshot> custom({
    Expression<int>? id,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ProfileSnapshotsCompanion copyWith({
    Value<int>? id,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
  }) {
    return ProfileSnapshotsCompanion(
      id: id ?? this.id,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CalendarDayCachesTable extends CalendarDayCaches
    with TableInfo<$CalendarDayCachesTable, CalendarDayCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarDayCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timezoneMeta = const VerificationMeta(
    'timezone',
  );
  @override
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    date,
    timezone,
    payload,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_day_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarDayCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('timezone')) {
      context.handle(
        _timezoneMeta,
        timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timezoneMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  CalendarDayCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarDayCache(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CalendarDayCachesTable createAlias(String alias) {
    return $CalendarDayCachesTable(attachedDatabase, alias);
  }
}

class CalendarDayCache extends DataClass
    implements Insertable<CalendarDayCache> {
  final String cacheKey;
  final String date;
  final String timezone;
  final String payload;
  final DateTime updatedAt;
  const CalendarDayCache({
    required this.cacheKey,
    required this.date,
    required this.timezone,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['date'] = Variable<String>(date);
    map['timezone'] = Variable<String>(timezone);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CalendarDayCachesCompanion toCompanion(bool nullToAbsent) {
    return CalendarDayCachesCompanion(
      cacheKey: Value(cacheKey),
      date: Value(date),
      timezone: Value(timezone),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory CalendarDayCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarDayCache(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      date: serializer.fromJson<String>(json['date']),
      timezone: serializer.fromJson<String>(json['timezone']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'date': serializer.toJson<String>(date),
      'timezone': serializer.toJson<String>(timezone),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CalendarDayCache copyWith({
    String? cacheKey,
    String? date,
    String? timezone,
    String? payload,
    DateTime? updatedAt,
  }) => CalendarDayCache(
    cacheKey: cacheKey ?? this.cacheKey,
    date: date ?? this.date,
    timezone: timezone ?? this.timezone,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CalendarDayCache copyWithCompanion(CalendarDayCachesCompanion data) {
    return CalendarDayCache(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      date: data.date.present ? data.date.value : this.date,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarDayCache(')
          ..write('cacheKey: $cacheKey, ')
          ..write('date: $date, ')
          ..write('timezone: $timezone, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, date, timezone, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarDayCache &&
          other.cacheKey == this.cacheKey &&
          other.date == this.date &&
          other.timezone == this.timezone &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class CalendarDayCachesCompanion extends UpdateCompanion<CalendarDayCache> {
  final Value<String> cacheKey;
  final Value<String> date;
  final Value<String> timezone;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CalendarDayCachesCompanion({
    this.cacheKey = const Value.absent(),
    this.date = const Value.absent(),
    this.timezone = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarDayCachesCompanion.insert({
    required String cacheKey,
    required String date,
    required String timezone,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       date = Value(date),
       timezone = Value(timezone),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<CalendarDayCache> custom({
    Expression<String>? cacheKey,
    Expression<String>? date,
    Expression<String>? timezone,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (date != null) 'date': date,
      if (timezone != null) 'timezone': timezone,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarDayCachesCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? date,
    Value<String>? timezone,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CalendarDayCachesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      date: date ?? this.date,
      timezone: timezone ?? this.timezone,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarDayCachesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('date: $date, ')
          ..write('timezone: $timezone, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarMonthCachesTable extends CalendarMonthCaches
    with TableInfo<$CalendarMonthCachesTable, CalendarMonthCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarMonthCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timezoneMeta = const VerificationMeta(
    'timezone',
  );
  @override
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedDateMeta = const VerificationMeta(
    'selectedDate',
  );
  @override
  late final GeneratedColumn<String> selectedDate = GeneratedColumn<String>(
    'selected_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    month,
    timezone,
    selectedDate,
    payload,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_month_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarMonthCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('timezone')) {
      context.handle(
        _timezoneMeta,
        timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timezoneMeta);
    }
    if (data.containsKey('selected_date')) {
      context.handle(
        _selectedDateMeta,
        selectedDate.isAcceptableOrUnknown(
          data['selected_date']!,
          _selectedDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectedDateMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  CalendarMonthCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarMonthCache(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      )!,
      selectedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_date'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CalendarMonthCachesTable createAlias(String alias) {
    return $CalendarMonthCachesTable(attachedDatabase, alias);
  }
}

class CalendarMonthCache extends DataClass
    implements Insertable<CalendarMonthCache> {
  final String cacheKey;
  final String month;
  final String timezone;
  final String selectedDate;
  final String payload;
  final DateTime updatedAt;
  const CalendarMonthCache({
    required this.cacheKey,
    required this.month,
    required this.timezone,
    required this.selectedDate,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['month'] = Variable<String>(month);
    map['timezone'] = Variable<String>(timezone);
    map['selected_date'] = Variable<String>(selectedDate);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CalendarMonthCachesCompanion toCompanion(bool nullToAbsent) {
    return CalendarMonthCachesCompanion(
      cacheKey: Value(cacheKey),
      month: Value(month),
      timezone: Value(timezone),
      selectedDate: Value(selectedDate),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory CalendarMonthCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarMonthCache(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      month: serializer.fromJson<String>(json['month']),
      timezone: serializer.fromJson<String>(json['timezone']),
      selectedDate: serializer.fromJson<String>(json['selectedDate']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'month': serializer.toJson<String>(month),
      'timezone': serializer.toJson<String>(timezone),
      'selectedDate': serializer.toJson<String>(selectedDate),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CalendarMonthCache copyWith({
    String? cacheKey,
    String? month,
    String? timezone,
    String? selectedDate,
    String? payload,
    DateTime? updatedAt,
  }) => CalendarMonthCache(
    cacheKey: cacheKey ?? this.cacheKey,
    month: month ?? this.month,
    timezone: timezone ?? this.timezone,
    selectedDate: selectedDate ?? this.selectedDate,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CalendarMonthCache copyWithCompanion(CalendarMonthCachesCompanion data) {
    return CalendarMonthCache(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      month: data.month.present ? data.month.value : this.month,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      selectedDate: data.selectedDate.present
          ? data.selectedDate.value
          : this.selectedDate,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarMonthCache(')
          ..write('cacheKey: $cacheKey, ')
          ..write('month: $month, ')
          ..write('timezone: $timezone, ')
          ..write('selectedDate: $selectedDate, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(cacheKey, month, timezone, selectedDate, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarMonthCache &&
          other.cacheKey == this.cacheKey &&
          other.month == this.month &&
          other.timezone == this.timezone &&
          other.selectedDate == this.selectedDate &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class CalendarMonthCachesCompanion extends UpdateCompanion<CalendarMonthCache> {
  final Value<String> cacheKey;
  final Value<String> month;
  final Value<String> timezone;
  final Value<String> selectedDate;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CalendarMonthCachesCompanion({
    this.cacheKey = const Value.absent(),
    this.month = const Value.absent(),
    this.timezone = const Value.absent(),
    this.selectedDate = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarMonthCachesCompanion.insert({
    required String cacheKey,
    required String month,
    required String timezone,
    required String selectedDate,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       month = Value(month),
       timezone = Value(timezone),
       selectedDate = Value(selectedDate),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<CalendarMonthCache> custom({
    Expression<String>? cacheKey,
    Expression<String>? month,
    Expression<String>? timezone,
    Expression<String>? selectedDate,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (month != null) 'month': month,
      if (timezone != null) 'timezone': timezone,
      if (selectedDate != null) 'selected_date': selectedDate,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarMonthCachesCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? month,
    Value<String>? timezone,
    Value<String>? selectedDate,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CalendarMonthCachesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      month: month ?? this.month,
      timezone: timezone ?? this.timezone,
      selectedDate: selectedDate ?? this.selectedDate,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (selectedDate.present) {
      map['selected_date'] = Variable<String>(selectedDate.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarMonthCachesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('month: $month, ')
          ..write('timezone: $timezone, ')
          ..write('selectedDate: $selectedDate, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationSessionsTable extends ConversationSessions
    with TableInfo<$ConversationSessionsTable, ConversationSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _storageScopeMeta = const VerificationMeta(
    'storageScope',
  );
  @override
  late final GeneratedColumn<String> storageScope = GeneratedColumn<String>(
    'storage_scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [storageScope, sessionId, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('storage_scope')) {
      context.handle(
        _storageScopeMeta,
        storageScope.isAcceptableOrUnknown(
          data['storage_scope']!,
          _storageScopeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storageScopeMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {storageScope};
  @override
  ConversationSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationSession(
      storageScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_scope'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ConversationSessionsTable createAlias(String alias) {
    return $ConversationSessionsTable(attachedDatabase, alias);
  }
}

class ConversationSession extends DataClass
    implements Insertable<ConversationSession> {
  final String storageScope;
  final String? sessionId;
  final DateTime updatedAt;
  const ConversationSession({
    required this.storageScope,
    this.sessionId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['storage_scope'] = Variable<String>(storageScope);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationSessionsCompanion toCompanion(bool nullToAbsent) {
    return ConversationSessionsCompanion(
      storageScope: Value(storageScope),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConversationSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationSession(
      storageScope: serializer.fromJson<String>(json['storageScope']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'storageScope': serializer.toJson<String>(storageScope),
      'sessionId': serializer.toJson<String?>(sessionId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConversationSession copyWith({
    String? storageScope,
    Value<String?> sessionId = const Value.absent(),
    DateTime? updatedAt,
  }) => ConversationSession(
    storageScope: storageScope ?? this.storageScope,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConversationSession copyWithCompanion(ConversationSessionsCompanion data) {
    return ConversationSession(
      storageScope: data.storageScope.present
          ? data.storageScope.value
          : this.storageScope,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationSession(')
          ..write('storageScope: $storageScope, ')
          ..write('sessionId: $sessionId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(storageScope, sessionId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationSession &&
          other.storageScope == this.storageScope &&
          other.sessionId == this.sessionId &&
          other.updatedAt == this.updatedAt);
}

class ConversationSessionsCompanion
    extends UpdateCompanion<ConversationSession> {
  final Value<String> storageScope;
  final Value<String?> sessionId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationSessionsCompanion({
    this.storageScope = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationSessionsCompanion.insert({
    required String storageScope,
    this.sessionId = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : storageScope = Value(storageScope),
       updatedAt = Value(updatedAt);
  static Insertable<ConversationSession> custom({
    Expression<String>? storageScope,
    Expression<String>? sessionId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (storageScope != null) 'storage_scope': storageScope,
      if (sessionId != null) 'session_id': sessionId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationSessionsCompanion copyWith({
    Value<String>? storageScope,
    Value<String?>? sessionId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationSessionsCompanion(
      storageScope: storageScope ?? this.storageScope,
      sessionId: sessionId ?? this.sessionId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (storageScope.present) {
      map['storage_scope'] = Variable<String>(storageScope.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationSessionsCompanion(')
          ..write('storageScope: $storageScope, ')
          ..write('sessionId: $sessionId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationEntriesTable extends ConversationEntries
    with TableInfo<$ConversationEntriesTable, ConversationEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _storageScopeMeta = const VerificationMeta(
    'storageScope',
  );
  @override
  late final GeneratedColumn<String> storageScope = GeneratedColumn<String>(
    'storage_scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isStreamingMeta = const VerificationMeta(
    'isStreaming',
  );
  @override
  late final GeneratedColumn<bool> isStreaming = GeneratedColumn<bool>(
    'is_streaming',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_streaming" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storageScope,
    orderIndex,
    entryId,
    isStreaming,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('storage_scope')) {
      context.handle(
        _storageScopeMeta,
        storageScope.isAcceptableOrUnknown(
          data['storage_scope']!,
          _storageScopeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storageScopeMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('is_streaming')) {
      context.handle(
        _isStreamingMeta,
        isStreaming.isAcceptableOrUnknown(
          data['is_streaming']!,
          _isStreamingMeta,
        ),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      storageScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_scope'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      isStreaming: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_streaming'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $ConversationEntriesTable createAlias(String alias) {
    return $ConversationEntriesTable(attachedDatabase, alias);
  }
}

class ConversationEntry extends DataClass
    implements Insertable<ConversationEntry> {
  final int id;
  final String storageScope;
  final int orderIndex;
  final String entryId;
  final bool isStreaming;
  final String payload;
  const ConversationEntry({
    required this.id,
    required this.storageScope,
    required this.orderIndex,
    required this.entryId,
    required this.isStreaming,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['storage_scope'] = Variable<String>(storageScope);
    map['order_index'] = Variable<int>(orderIndex);
    map['entry_id'] = Variable<String>(entryId);
    map['is_streaming'] = Variable<bool>(isStreaming);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  ConversationEntriesCompanion toCompanion(bool nullToAbsent) {
    return ConversationEntriesCompanion(
      id: Value(id),
      storageScope: Value(storageScope),
      orderIndex: Value(orderIndex),
      entryId: Value(entryId),
      isStreaming: Value(isStreaming),
      payload: Value(payload),
    );
  }

  factory ConversationEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationEntry(
      id: serializer.fromJson<int>(json['id']),
      storageScope: serializer.fromJson<String>(json['storageScope']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      entryId: serializer.fromJson<String>(json['entryId']),
      isStreaming: serializer.fromJson<bool>(json['isStreaming']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'storageScope': serializer.toJson<String>(storageScope),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'entryId': serializer.toJson<String>(entryId),
      'isStreaming': serializer.toJson<bool>(isStreaming),
      'payload': serializer.toJson<String>(payload),
    };
  }

  ConversationEntry copyWith({
    int? id,
    String? storageScope,
    int? orderIndex,
    String? entryId,
    bool? isStreaming,
    String? payload,
  }) => ConversationEntry(
    id: id ?? this.id,
    storageScope: storageScope ?? this.storageScope,
    orderIndex: orderIndex ?? this.orderIndex,
    entryId: entryId ?? this.entryId,
    isStreaming: isStreaming ?? this.isStreaming,
    payload: payload ?? this.payload,
  );
  ConversationEntry copyWithCompanion(ConversationEntriesCompanion data) {
    return ConversationEntry(
      id: data.id.present ? data.id.value : this.id,
      storageScope: data.storageScope.present
          ? data.storageScope.value
          : this.storageScope,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      isStreaming: data.isStreaming.present
          ? data.isStreaming.value
          : this.isStreaming,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationEntry(')
          ..write('id: $id, ')
          ..write('storageScope: $storageScope, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('entryId: $entryId, ')
          ..write('isStreaming: $isStreaming, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, storageScope, orderIndex, entryId, isStreaming, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationEntry &&
          other.id == this.id &&
          other.storageScope == this.storageScope &&
          other.orderIndex == this.orderIndex &&
          other.entryId == this.entryId &&
          other.isStreaming == this.isStreaming &&
          other.payload == this.payload);
}

class ConversationEntriesCompanion extends UpdateCompanion<ConversationEntry> {
  final Value<int> id;
  final Value<String> storageScope;
  final Value<int> orderIndex;
  final Value<String> entryId;
  final Value<bool> isStreaming;
  final Value<String> payload;
  const ConversationEntriesCompanion({
    this.id = const Value.absent(),
    this.storageScope = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.entryId = const Value.absent(),
    this.isStreaming = const Value.absent(),
    this.payload = const Value.absent(),
  });
  ConversationEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String storageScope,
    required int orderIndex,
    required String entryId,
    this.isStreaming = const Value.absent(),
    required String payload,
  }) : storageScope = Value(storageScope),
       orderIndex = Value(orderIndex),
       entryId = Value(entryId),
       payload = Value(payload);
  static Insertable<ConversationEntry> custom({
    Expression<int>? id,
    Expression<String>? storageScope,
    Expression<int>? orderIndex,
    Expression<String>? entryId,
    Expression<bool>? isStreaming,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storageScope != null) 'storage_scope': storageScope,
      if (orderIndex != null) 'order_index': orderIndex,
      if (entryId != null) 'entry_id': entryId,
      if (isStreaming != null) 'is_streaming': isStreaming,
      if (payload != null) 'payload': payload,
    });
  }

  ConversationEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? storageScope,
    Value<int>? orderIndex,
    Value<String>? entryId,
    Value<bool>? isStreaming,
    Value<String>? payload,
  }) {
    return ConversationEntriesCompanion(
      id: id ?? this.id,
      storageScope: storageScope ?? this.storageScope,
      orderIndex: orderIndex ?? this.orderIndex,
      entryId: entryId ?? this.entryId,
      isStreaming: isStreaming ?? this.isStreaming,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (storageScope.present) {
      map['storage_scope'] = Variable<String>(storageScope.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (isStreaming.present) {
      map['is_streaming'] = Variable<bool>(isStreaming.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationEntriesCompanion(')
          ..write('id: $id, ')
          ..write('storageScope: $storageScope, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('entryId: $entryId, ')
          ..write('isStreaming: $isStreaming, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

class $DebugLogEventsTable extends DebugLogEvents
    with TableInfo<$DebugLogEventsTable, DebugLogEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebugLogEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batchStateMeta = const VerificationMeta(
    'batchState',
  );
  @override
  late final GeneratedColumn<String> batchState = GeneratedColumn<String>(
    'batch_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldsJsonMeta = const VerificationMeta(
    'fieldsJson',
  );
  @override
  late final GeneratedColumn<String> fieldsJson = GeneratedColumn<String>(
    'fields_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _stackTraceMeta = const VerificationMeta(
    'stackTrace',
  );
  @override
  late final GeneratedColumn<String> stackTrace = GeneratedColumn<String>(
    'stack_trace',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _approxBytesMeta = const VerificationMeta(
    'approxBytes',
  );
  @override
  late final GeneratedColumn<int> approxBytes = GeneratedColumn<int>(
    'approx_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    batchState,
    level,
    category,
    message,
    fieldsJson,
    stackTrace,
    approxBytes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debug_log_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<DebugLogEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('batch_state')) {
      context.handle(
        _batchStateMeta,
        batchState.isAcceptableOrUnknown(data['batch_state']!, _batchStateMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('fields_json')) {
      context.handle(
        _fieldsJsonMeta,
        fieldsJson.isAcceptableOrUnknown(data['fields_json']!, _fieldsJsonMeta),
      );
    }
    if (data.containsKey('stack_trace')) {
      context.handle(
        _stackTraceMeta,
        stackTrace.isAcceptableOrUnknown(data['stack_trace']!, _stackTraceMeta),
      );
    }
    if (data.containsKey('approx_bytes')) {
      context.handle(
        _approxBytesMeta,
        approxBytes.isAcceptableOrUnknown(
          data['approx_bytes']!,
          _approxBytesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DebugLogEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebugLogEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      batchState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_state'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      fieldsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fields_json'],
      )!,
      stackTrace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stack_trace'],
      ),
      approxBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}approx_bytes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DebugLogEventsTable createAlias(String alias) {
    return $DebugLogEventsTable(attachedDatabase, alias);
  }
}

class DebugLogEvent extends DataClass implements Insertable<DebugLogEvent> {
  final String id;
  final String batchState;
  final String level;
  final String category;
  final String message;
  final String fieldsJson;
  final String? stackTrace;
  final int approxBytes;
  final DateTime createdAt;
  const DebugLogEvent({
    required this.id,
    required this.batchState,
    required this.level,
    required this.category,
    required this.message,
    required this.fieldsJson,
    this.stackTrace,
    required this.approxBytes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['batch_state'] = Variable<String>(batchState);
    map['level'] = Variable<String>(level);
    map['category'] = Variable<String>(category);
    map['message'] = Variable<String>(message);
    map['fields_json'] = Variable<String>(fieldsJson);
    if (!nullToAbsent || stackTrace != null) {
      map['stack_trace'] = Variable<String>(stackTrace);
    }
    map['approx_bytes'] = Variable<int>(approxBytes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DebugLogEventsCompanion toCompanion(bool nullToAbsent) {
    return DebugLogEventsCompanion(
      id: Value(id),
      batchState: Value(batchState),
      level: Value(level),
      category: Value(category),
      message: Value(message),
      fieldsJson: Value(fieldsJson),
      stackTrace: stackTrace == null && nullToAbsent
          ? const Value.absent()
          : Value(stackTrace),
      approxBytes: Value(approxBytes),
      createdAt: Value(createdAt),
    );
  }

  factory DebugLogEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebugLogEvent(
      id: serializer.fromJson<String>(json['id']),
      batchState: serializer.fromJson<String>(json['batchState']),
      level: serializer.fromJson<String>(json['level']),
      category: serializer.fromJson<String>(json['category']),
      message: serializer.fromJson<String>(json['message']),
      fieldsJson: serializer.fromJson<String>(json['fieldsJson']),
      stackTrace: serializer.fromJson<String?>(json['stackTrace']),
      approxBytes: serializer.fromJson<int>(json['approxBytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'batchState': serializer.toJson<String>(batchState),
      'level': serializer.toJson<String>(level),
      'category': serializer.toJson<String>(category),
      'message': serializer.toJson<String>(message),
      'fieldsJson': serializer.toJson<String>(fieldsJson),
      'stackTrace': serializer.toJson<String?>(stackTrace),
      'approxBytes': serializer.toJson<int>(approxBytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DebugLogEvent copyWith({
    String? id,
    String? batchState,
    String? level,
    String? category,
    String? message,
    String? fieldsJson,
    Value<String?> stackTrace = const Value.absent(),
    int? approxBytes,
    DateTime? createdAt,
  }) => DebugLogEvent(
    id: id ?? this.id,
    batchState: batchState ?? this.batchState,
    level: level ?? this.level,
    category: category ?? this.category,
    message: message ?? this.message,
    fieldsJson: fieldsJson ?? this.fieldsJson,
    stackTrace: stackTrace.present ? stackTrace.value : this.stackTrace,
    approxBytes: approxBytes ?? this.approxBytes,
    createdAt: createdAt ?? this.createdAt,
  );
  DebugLogEvent copyWithCompanion(DebugLogEventsCompanion data) {
    return DebugLogEvent(
      id: data.id.present ? data.id.value : this.id,
      batchState: data.batchState.present
          ? data.batchState.value
          : this.batchState,
      level: data.level.present ? data.level.value : this.level,
      category: data.category.present ? data.category.value : this.category,
      message: data.message.present ? data.message.value : this.message,
      fieldsJson: data.fieldsJson.present
          ? data.fieldsJson.value
          : this.fieldsJson,
      stackTrace: data.stackTrace.present
          ? data.stackTrace.value
          : this.stackTrace,
      approxBytes: data.approxBytes.present
          ? data.approxBytes.value
          : this.approxBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebugLogEvent(')
          ..write('id: $id, ')
          ..write('batchState: $batchState, ')
          ..write('level: $level, ')
          ..write('category: $category, ')
          ..write('message: $message, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('stackTrace: $stackTrace, ')
          ..write('approxBytes: $approxBytes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    batchState,
    level,
    category,
    message,
    fieldsJson,
    stackTrace,
    approxBytes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebugLogEvent &&
          other.id == this.id &&
          other.batchState == this.batchState &&
          other.level == this.level &&
          other.category == this.category &&
          other.message == this.message &&
          other.fieldsJson == this.fieldsJson &&
          other.stackTrace == this.stackTrace &&
          other.approxBytes == this.approxBytes &&
          other.createdAt == this.createdAt);
}

class DebugLogEventsCompanion extends UpdateCompanion<DebugLogEvent> {
  final Value<String> id;
  final Value<String> batchState;
  final Value<String> level;
  final Value<String> category;
  final Value<String> message;
  final Value<String> fieldsJson;
  final Value<String?> stackTrace;
  final Value<int> approxBytes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DebugLogEventsCompanion({
    this.id = const Value.absent(),
    this.batchState = const Value.absent(),
    this.level = const Value.absent(),
    this.category = const Value.absent(),
    this.message = const Value.absent(),
    this.fieldsJson = const Value.absent(),
    this.stackTrace = const Value.absent(),
    this.approxBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebugLogEventsCompanion.insert({
    required String id,
    this.batchState = const Value.absent(),
    required String level,
    required String category,
    required String message,
    this.fieldsJson = const Value.absent(),
    this.stackTrace = const Value.absent(),
    this.approxBytes = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       level = Value(level),
       category = Value(category),
       message = Value(message),
       createdAt = Value(createdAt);
  static Insertable<DebugLogEvent> custom({
    Expression<String>? id,
    Expression<String>? batchState,
    Expression<String>? level,
    Expression<String>? category,
    Expression<String>? message,
    Expression<String>? fieldsJson,
    Expression<String>? stackTrace,
    Expression<int>? approxBytes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (batchState != null) 'batch_state': batchState,
      if (level != null) 'level': level,
      if (category != null) 'category': category,
      if (message != null) 'message': message,
      if (fieldsJson != null) 'fields_json': fieldsJson,
      if (stackTrace != null) 'stack_trace': stackTrace,
      if (approxBytes != null) 'approx_bytes': approxBytes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebugLogEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? batchState,
    Value<String>? level,
    Value<String>? category,
    Value<String>? message,
    Value<String>? fieldsJson,
    Value<String?>? stackTrace,
    Value<int>? approxBytes,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DebugLogEventsCompanion(
      id: id ?? this.id,
      batchState: batchState ?? this.batchState,
      level: level ?? this.level,
      category: category ?? this.category,
      message: message ?? this.message,
      fieldsJson: fieldsJson ?? this.fieldsJson,
      stackTrace: stackTrace ?? this.stackTrace,
      approxBytes: approxBytes ?? this.approxBytes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (batchState.present) {
      map['batch_state'] = Variable<String>(batchState.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (fieldsJson.present) {
      map['fields_json'] = Variable<String>(fieldsJson.value);
    }
    if (stackTrace.present) {
      map['stack_trace'] = Variable<String>(stackTrace.value);
    }
    if (approxBytes.present) {
      map['approx_bytes'] = Variable<int>(approxBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebugLogEventsCompanion(')
          ..write('id: $id, ')
          ..write('batchState: $batchState, ')
          ..write('level: $level, ')
          ..write('category: $category, ')
          ..write('message: $message, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('stackTrace: $stackTrace, ')
          ..write('approxBytes: $approxBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebugLogUploadCursorTable extends DebugLogUploadCursor
    with TableInfo<$DebugLogUploadCursorTable, DebugLogUploadCursorData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebugLogUploadCursorTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonIdMeta = const VerificationMeta(
    'singletonId',
  );
  @override
  late final GeneratedColumn<int> singletonId = GeneratedColumn<int>(
    'singleton_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUploadedAtMeta = const VerificationMeta(
    'lastUploadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUploadedAt =
      GeneratedColumn<DateTime>(
        'last_uploaded_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastBatchIdMeta = const VerificationMeta(
    'lastBatchId',
  );
  @override
  late final GeneratedColumn<String> lastBatchId = GeneratedColumn<String>(
    'last_batch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    singletonId,
    lastUploadedAt,
    lastBatchId,
    retryCount,
    nextRetryAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debug_log_upload_cursor';
  @override
  VerificationContext validateIntegrity(
    Insertable<DebugLogUploadCursorData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton_id')) {
      context.handle(
        _singletonIdMeta,
        singletonId.isAcceptableOrUnknown(
          data['singleton_id']!,
          _singletonIdMeta,
        ),
      );
    }
    if (data.containsKey('last_uploaded_at')) {
      context.handle(
        _lastUploadedAtMeta,
        lastUploadedAt.isAcceptableOrUnknown(
          data['last_uploaded_at']!,
          _lastUploadedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_batch_id')) {
      context.handle(
        _lastBatchIdMeta,
        lastBatchId.isAcceptableOrUnknown(
          data['last_batch_id']!,
          _lastBatchIdMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singletonId};
  @override
  DebugLogUploadCursorData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebugLogUploadCursorData(
      singletonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton_id'],
      )!,
      lastUploadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_uploaded_at'],
      ),
      lastBatchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_batch_id'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
    );
  }

  @override
  $DebugLogUploadCursorTable createAlias(String alias) {
    return $DebugLogUploadCursorTable(attachedDatabase, alias);
  }
}

class DebugLogUploadCursorData extends DataClass
    implements Insertable<DebugLogUploadCursorData> {
  final int singletonId;
  final DateTime? lastUploadedAt;
  final String? lastBatchId;
  final int retryCount;
  final DateTime? nextRetryAt;
  const DebugLogUploadCursorData({
    required this.singletonId,
    this.lastUploadedAt,
    this.lastBatchId,
    required this.retryCount,
    this.nextRetryAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton_id'] = Variable<int>(singletonId);
    if (!nullToAbsent || lastUploadedAt != null) {
      map['last_uploaded_at'] = Variable<DateTime>(lastUploadedAt);
    }
    if (!nullToAbsent || lastBatchId != null) {
      map['last_batch_id'] = Variable<String>(lastBatchId);
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    return map;
  }

  DebugLogUploadCursorCompanion toCompanion(bool nullToAbsent) {
    return DebugLogUploadCursorCompanion(
      singletonId: Value(singletonId),
      lastUploadedAt: lastUploadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUploadedAt),
      lastBatchId: lastBatchId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastBatchId),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
    );
  }

  factory DebugLogUploadCursorData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebugLogUploadCursorData(
      singletonId: serializer.fromJson<int>(json['singletonId']),
      lastUploadedAt: serializer.fromJson<DateTime?>(json['lastUploadedAt']),
      lastBatchId: serializer.fromJson<String?>(json['lastBatchId']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singletonId': serializer.toJson<int>(singletonId),
      'lastUploadedAt': serializer.toJson<DateTime?>(lastUploadedAt),
      'lastBatchId': serializer.toJson<String?>(lastBatchId),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
    };
  }

  DebugLogUploadCursorData copyWith({
    int? singletonId,
    Value<DateTime?> lastUploadedAt = const Value.absent(),
    Value<String?> lastBatchId = const Value.absent(),
    int? retryCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
  }) => DebugLogUploadCursorData(
    singletonId: singletonId ?? this.singletonId,
    lastUploadedAt: lastUploadedAt.present
        ? lastUploadedAt.value
        : this.lastUploadedAt,
    lastBatchId: lastBatchId.present ? lastBatchId.value : this.lastBatchId,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
  );
  DebugLogUploadCursorData copyWithCompanion(
    DebugLogUploadCursorCompanion data,
  ) {
    return DebugLogUploadCursorData(
      singletonId: data.singletonId.present
          ? data.singletonId.value
          : this.singletonId,
      lastUploadedAt: data.lastUploadedAt.present
          ? data.lastUploadedAt.value
          : this.lastUploadedAt,
      lastBatchId: data.lastBatchId.present
          ? data.lastBatchId.value
          : this.lastBatchId,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebugLogUploadCursorData(')
          ..write('singletonId: $singletonId, ')
          ..write('lastUploadedAt: $lastUploadedAt, ')
          ..write('lastBatchId: $lastBatchId, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    singletonId,
    lastUploadedAt,
    lastBatchId,
    retryCount,
    nextRetryAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebugLogUploadCursorData &&
          other.singletonId == this.singletonId &&
          other.lastUploadedAt == this.lastUploadedAt &&
          other.lastBatchId == this.lastBatchId &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt);
}

class DebugLogUploadCursorCompanion
    extends UpdateCompanion<DebugLogUploadCursorData> {
  final Value<int> singletonId;
  final Value<DateTime?> lastUploadedAt;
  final Value<String?> lastBatchId;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  const DebugLogUploadCursorCompanion({
    this.singletonId = const Value.absent(),
    this.lastUploadedAt = const Value.absent(),
    this.lastBatchId = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
  });
  DebugLogUploadCursorCompanion.insert({
    this.singletonId = const Value.absent(),
    this.lastUploadedAt = const Value.absent(),
    this.lastBatchId = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
  });
  static Insertable<DebugLogUploadCursorData> custom({
    Expression<int>? singletonId,
    Expression<DateTime>? lastUploadedAt,
    Expression<String>? lastBatchId,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
  }) {
    return RawValuesInsertable({
      if (singletonId != null) 'singleton_id': singletonId,
      if (lastUploadedAt != null) 'last_uploaded_at': lastUploadedAt,
      if (lastBatchId != null) 'last_batch_id': lastBatchId,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
    });
  }

  DebugLogUploadCursorCompanion copyWith({
    Value<int>? singletonId,
    Value<DateTime?>? lastUploadedAt,
    Value<String?>? lastBatchId,
    Value<int>? retryCount,
    Value<DateTime?>? nextRetryAt,
  }) {
    return DebugLogUploadCursorCompanion(
      singletonId: singletonId ?? this.singletonId,
      lastUploadedAt: lastUploadedAt ?? this.lastUploadedAt,
      lastBatchId: lastBatchId ?? this.lastBatchId,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singletonId.present) {
      map['singleton_id'] = Variable<int>(singletonId.value);
    }
    if (lastUploadedAt.present) {
      map['last_uploaded_at'] = Variable<DateTime>(lastUploadedAt.value);
    }
    if (lastBatchId.present) {
      map['last_batch_id'] = Variable<String>(lastBatchId.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebugLogUploadCursorCompanion(')
          ..write('singletonId: $singletonId, ')
          ..write('lastUploadedAt: $lastUploadedAt, ')
          ..write('lastBatchId: $lastBatchId, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfileSnapshotsTable profileSnapshots = $ProfileSnapshotsTable(
    this,
  );
  late final $CalendarDayCachesTable calendarDayCaches =
      $CalendarDayCachesTable(this);
  late final $CalendarMonthCachesTable calendarMonthCaches =
      $CalendarMonthCachesTable(this);
  late final $ConversationSessionsTable conversationSessions =
      $ConversationSessionsTable(this);
  late final $ConversationEntriesTable conversationEntries =
      $ConversationEntriesTable(this);
  late final $DebugLogEventsTable debugLogEvents = $DebugLogEventsTable(this);
  late final $DebugLogUploadCursorTable debugLogUploadCursor =
      $DebugLogUploadCursorTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profileSnapshots,
    calendarDayCaches,
    calendarMonthCaches,
    conversationSessions,
    conversationEntries,
    debugLogEvents,
    debugLogUploadCursor,
  ];
}

typedef $$ProfileSnapshotsTableCreateCompanionBuilder =
    ProfileSnapshotsCompanion Function({
      Value<int> id,
      required String payload,
      required DateTime updatedAt,
    });
typedef $$ProfileSnapshotsTableUpdateCompanionBuilder =
    ProfileSnapshotsCompanion Function({
      Value<int> id,
      Value<String> payload,
      Value<DateTime> updatedAt,
    });

class $$ProfileSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $ProfileSnapshotsTable> {
  $$ProfileSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfileSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfileSnapshotsTable> {
  $$ProfileSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfileSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfileSnapshotsTable> {
  $$ProfileSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProfileSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfileSnapshotsTable,
          ProfileSnapshot,
          $$ProfileSnapshotsTableFilterComposer,
          $$ProfileSnapshotsTableOrderingComposer,
          $$ProfileSnapshotsTableAnnotationComposer,
          $$ProfileSnapshotsTableCreateCompanionBuilder,
          $$ProfileSnapshotsTableUpdateCompanionBuilder,
          (
            ProfileSnapshot,
            BaseReferences<
              _$AppDatabase,
              $ProfileSnapshotsTable,
              ProfileSnapshot
            >,
          ),
          ProfileSnapshot,
          PrefetchHooks Function()
        > {
  $$ProfileSnapshotsTableTableManager(
    _$AppDatabase db,
    $ProfileSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProfileSnapshotsCompanion(
                id: id,
                payload: payload,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String payload,
                required DateTime updatedAt,
              }) => ProfileSnapshotsCompanion.insert(
                id: id,
                payload: payload,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfileSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfileSnapshotsTable,
      ProfileSnapshot,
      $$ProfileSnapshotsTableFilterComposer,
      $$ProfileSnapshotsTableOrderingComposer,
      $$ProfileSnapshotsTableAnnotationComposer,
      $$ProfileSnapshotsTableCreateCompanionBuilder,
      $$ProfileSnapshotsTableUpdateCompanionBuilder,
      (
        ProfileSnapshot,
        BaseReferences<_$AppDatabase, $ProfileSnapshotsTable, ProfileSnapshot>,
      ),
      ProfileSnapshot,
      PrefetchHooks Function()
    >;
typedef $$CalendarDayCachesTableCreateCompanionBuilder =
    CalendarDayCachesCompanion Function({
      required String cacheKey,
      required String date,
      required String timezone,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CalendarDayCachesTableUpdateCompanionBuilder =
    CalendarDayCachesCompanion Function({
      Value<String> cacheKey,
      Value<String> date,
      Value<String> timezone,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CalendarDayCachesTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarDayCachesTable> {
  $$CalendarDayCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarDayCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarDayCachesTable> {
  $$CalendarDayCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarDayCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarDayCachesTable> {
  $$CalendarDayCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CalendarDayCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarDayCachesTable,
          CalendarDayCache,
          $$CalendarDayCachesTableFilterComposer,
          $$CalendarDayCachesTableOrderingComposer,
          $$CalendarDayCachesTableAnnotationComposer,
          $$CalendarDayCachesTableCreateCompanionBuilder,
          $$CalendarDayCachesTableUpdateCompanionBuilder,
          (
            CalendarDayCache,
            BaseReferences<
              _$AppDatabase,
              $CalendarDayCachesTable,
              CalendarDayCache
            >,
          ),
          CalendarDayCache,
          PrefetchHooks Function()
        > {
  $$CalendarDayCachesTableTableManager(
    _$AppDatabase db,
    $CalendarDayCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarDayCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarDayCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarDayCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> timezone = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarDayCachesCompanion(
                cacheKey: cacheKey,
                date: date,
                timezone: timezone,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String date,
                required String timezone,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CalendarDayCachesCompanion.insert(
                cacheKey: cacheKey,
                date: date,
                timezone: timezone,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarDayCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarDayCachesTable,
      CalendarDayCache,
      $$CalendarDayCachesTableFilterComposer,
      $$CalendarDayCachesTableOrderingComposer,
      $$CalendarDayCachesTableAnnotationComposer,
      $$CalendarDayCachesTableCreateCompanionBuilder,
      $$CalendarDayCachesTableUpdateCompanionBuilder,
      (
        CalendarDayCache,
        BaseReferences<
          _$AppDatabase,
          $CalendarDayCachesTable,
          CalendarDayCache
        >,
      ),
      CalendarDayCache,
      PrefetchHooks Function()
    >;
typedef $$CalendarMonthCachesTableCreateCompanionBuilder =
    CalendarMonthCachesCompanion Function({
      required String cacheKey,
      required String month,
      required String timezone,
      required String selectedDate,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CalendarMonthCachesTableUpdateCompanionBuilder =
    CalendarMonthCachesCompanion Function({
      Value<String> cacheKey,
      Value<String> month,
      Value<String> timezone,
      Value<String> selectedDate,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CalendarMonthCachesTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarMonthCachesTable> {
  $$CalendarMonthCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedDate => $composableBuilder(
    column: $table.selectedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarMonthCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarMonthCachesTable> {
  $$CalendarMonthCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedDate => $composableBuilder(
    column: $table.selectedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarMonthCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarMonthCachesTable> {
  $$CalendarMonthCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);

  GeneratedColumn<String> get selectedDate => $composableBuilder(
    column: $table.selectedDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CalendarMonthCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarMonthCachesTable,
          CalendarMonthCache,
          $$CalendarMonthCachesTableFilterComposer,
          $$CalendarMonthCachesTableOrderingComposer,
          $$CalendarMonthCachesTableAnnotationComposer,
          $$CalendarMonthCachesTableCreateCompanionBuilder,
          $$CalendarMonthCachesTableUpdateCompanionBuilder,
          (
            CalendarMonthCache,
            BaseReferences<
              _$AppDatabase,
              $CalendarMonthCachesTable,
              CalendarMonthCache
            >,
          ),
          CalendarMonthCache,
          PrefetchHooks Function()
        > {
  $$CalendarMonthCachesTableTableManager(
    _$AppDatabase db,
    $CalendarMonthCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarMonthCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarMonthCachesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CalendarMonthCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<String> timezone = const Value.absent(),
                Value<String> selectedDate = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarMonthCachesCompanion(
                cacheKey: cacheKey,
                month: month,
                timezone: timezone,
                selectedDate: selectedDate,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String month,
                required String timezone,
                required String selectedDate,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CalendarMonthCachesCompanion.insert(
                cacheKey: cacheKey,
                month: month,
                timezone: timezone,
                selectedDate: selectedDate,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarMonthCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarMonthCachesTable,
      CalendarMonthCache,
      $$CalendarMonthCachesTableFilterComposer,
      $$CalendarMonthCachesTableOrderingComposer,
      $$CalendarMonthCachesTableAnnotationComposer,
      $$CalendarMonthCachesTableCreateCompanionBuilder,
      $$CalendarMonthCachesTableUpdateCompanionBuilder,
      (
        CalendarMonthCache,
        BaseReferences<
          _$AppDatabase,
          $CalendarMonthCachesTable,
          CalendarMonthCache
        >,
      ),
      CalendarMonthCache,
      PrefetchHooks Function()
    >;
typedef $$ConversationSessionsTableCreateCompanionBuilder =
    ConversationSessionsCompanion Function({
      required String storageScope,
      Value<String?> sessionId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ConversationSessionsTableUpdateCompanionBuilder =
    ConversationSessionsCompanion Function({
      Value<String> storageScope,
      Value<String?> sessionId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ConversationSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationSessionsTable> {
  $$ConversationSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get storageScope => $composableBuilder(
    column: $table.storageScope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationSessionsTable> {
  $$ConversationSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get storageScope => $composableBuilder(
    column: $table.storageScope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationSessionsTable> {
  $$ConversationSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get storageScope => $composableBuilder(
    column: $table.storageScope,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConversationSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationSessionsTable,
          ConversationSession,
          $$ConversationSessionsTableFilterComposer,
          $$ConversationSessionsTableOrderingComposer,
          $$ConversationSessionsTableAnnotationComposer,
          $$ConversationSessionsTableCreateCompanionBuilder,
          $$ConversationSessionsTableUpdateCompanionBuilder,
          (
            ConversationSession,
            BaseReferences<
              _$AppDatabase,
              $ConversationSessionsTable,
              ConversationSession
            >,
          ),
          ConversationSession,
          PrefetchHooks Function()
        > {
  $$ConversationSessionsTableTableManager(
    _$AppDatabase db,
    $ConversationSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationSessionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> storageScope = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationSessionsCompanion(
                storageScope: storageScope,
                sessionId: sessionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String storageScope,
                Value<String?> sessionId = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationSessionsCompanion.insert(
                storageScope: storageScope,
                sessionId: sessionId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationSessionsTable,
      ConversationSession,
      $$ConversationSessionsTableFilterComposer,
      $$ConversationSessionsTableOrderingComposer,
      $$ConversationSessionsTableAnnotationComposer,
      $$ConversationSessionsTableCreateCompanionBuilder,
      $$ConversationSessionsTableUpdateCompanionBuilder,
      (
        ConversationSession,
        BaseReferences<
          _$AppDatabase,
          $ConversationSessionsTable,
          ConversationSession
        >,
      ),
      ConversationSession,
      PrefetchHooks Function()
    >;
typedef $$ConversationEntriesTableCreateCompanionBuilder =
    ConversationEntriesCompanion Function({
      Value<int> id,
      required String storageScope,
      required int orderIndex,
      required String entryId,
      Value<bool> isStreaming,
      required String payload,
    });
typedef $$ConversationEntriesTableUpdateCompanionBuilder =
    ConversationEntriesCompanion Function({
      Value<int> id,
      Value<String> storageScope,
      Value<int> orderIndex,
      Value<String> entryId,
      Value<bool> isStreaming,
      Value<String> payload,
    });

class $$ConversationEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationEntriesTable> {
  $$ConversationEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storageScope => $composableBuilder(
    column: $table.storageScope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isStreaming => $composableBuilder(
    column: $table.isStreaming,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationEntriesTable> {
  $$ConversationEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storageScope => $composableBuilder(
    column: $table.storageScope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isStreaming => $composableBuilder(
    column: $table.isStreaming,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationEntriesTable> {
  $$ConversationEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get storageScope => $composableBuilder(
    column: $table.storageScope,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<bool> get isStreaming => $composableBuilder(
    column: $table.isStreaming,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$ConversationEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationEntriesTable,
          ConversationEntry,
          $$ConversationEntriesTableFilterComposer,
          $$ConversationEntriesTableOrderingComposer,
          $$ConversationEntriesTableAnnotationComposer,
          $$ConversationEntriesTableCreateCompanionBuilder,
          $$ConversationEntriesTableUpdateCompanionBuilder,
          (
            ConversationEntry,
            BaseReferences<
              _$AppDatabase,
              $ConversationEntriesTable,
              ConversationEntry
            >,
          ),
          ConversationEntry,
          PrefetchHooks Function()
        > {
  $$ConversationEntriesTableTableManager(
    _$AppDatabase db,
    $ConversationEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> storageScope = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<bool> isStreaming = const Value.absent(),
                Value<String> payload = const Value.absent(),
              }) => ConversationEntriesCompanion(
                id: id,
                storageScope: storageScope,
                orderIndex: orderIndex,
                entryId: entryId,
                isStreaming: isStreaming,
                payload: payload,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String storageScope,
                required int orderIndex,
                required String entryId,
                Value<bool> isStreaming = const Value.absent(),
                required String payload,
              }) => ConversationEntriesCompanion.insert(
                id: id,
                storageScope: storageScope,
                orderIndex: orderIndex,
                entryId: entryId,
                isStreaming: isStreaming,
                payload: payload,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationEntriesTable,
      ConversationEntry,
      $$ConversationEntriesTableFilterComposer,
      $$ConversationEntriesTableOrderingComposer,
      $$ConversationEntriesTableAnnotationComposer,
      $$ConversationEntriesTableCreateCompanionBuilder,
      $$ConversationEntriesTableUpdateCompanionBuilder,
      (
        ConversationEntry,
        BaseReferences<
          _$AppDatabase,
          $ConversationEntriesTable,
          ConversationEntry
        >,
      ),
      ConversationEntry,
      PrefetchHooks Function()
    >;
typedef $$DebugLogEventsTableCreateCompanionBuilder =
    DebugLogEventsCompanion Function({
      required String id,
      Value<String> batchState,
      required String level,
      required String category,
      required String message,
      Value<String> fieldsJson,
      Value<String?> stackTrace,
      Value<int> approxBytes,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$DebugLogEventsTableUpdateCompanionBuilder =
    DebugLogEventsCompanion Function({
      Value<String> id,
      Value<String> batchState,
      Value<String> level,
      Value<String> category,
      Value<String> message,
      Value<String> fieldsJson,
      Value<String?> stackTrace,
      Value<int> approxBytes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$DebugLogEventsTableFilterComposer
    extends Composer<_$AppDatabase, $DebugLogEventsTable> {
  $$DebugLogEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get batchState => $composableBuilder(
    column: $table.batchState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stackTrace => $composableBuilder(
    column: $table.stackTrace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get approxBytes => $composableBuilder(
    column: $table.approxBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DebugLogEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $DebugLogEventsTable> {
  $$DebugLogEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get batchState => $composableBuilder(
    column: $table.batchState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stackTrace => $composableBuilder(
    column: $table.stackTrace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get approxBytes => $composableBuilder(
    column: $table.approxBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DebugLogEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebugLogEventsTable> {
  $$DebugLogEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get batchState => $composableBuilder(
    column: $table.batchState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get fieldsJson => $composableBuilder(
    column: $table.fieldsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stackTrace => $composableBuilder(
    column: $table.stackTrace,
    builder: (column) => column,
  );

  GeneratedColumn<int> get approxBytes => $composableBuilder(
    column: $table.approxBytes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DebugLogEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DebugLogEventsTable,
          DebugLogEvent,
          $$DebugLogEventsTableFilterComposer,
          $$DebugLogEventsTableOrderingComposer,
          $$DebugLogEventsTableAnnotationComposer,
          $$DebugLogEventsTableCreateCompanionBuilder,
          $$DebugLogEventsTableUpdateCompanionBuilder,
          (
            DebugLogEvent,
            BaseReferences<_$AppDatabase, $DebugLogEventsTable, DebugLogEvent>,
          ),
          DebugLogEvent,
          PrefetchHooks Function()
        > {
  $$DebugLogEventsTableTableManager(
    _$AppDatabase db,
    $DebugLogEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebugLogEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebugLogEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebugLogEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> batchState = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String> fieldsJson = const Value.absent(),
                Value<String?> stackTrace = const Value.absent(),
                Value<int> approxBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebugLogEventsCompanion(
                id: id,
                batchState: batchState,
                level: level,
                category: category,
                message: message,
                fieldsJson: fieldsJson,
                stackTrace: stackTrace,
                approxBytes: approxBytes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> batchState = const Value.absent(),
                required String level,
                required String category,
                required String message,
                Value<String> fieldsJson = const Value.absent(),
                Value<String?> stackTrace = const Value.absent(),
                Value<int> approxBytes = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => DebugLogEventsCompanion.insert(
                id: id,
                batchState: batchState,
                level: level,
                category: category,
                message: message,
                fieldsJson: fieldsJson,
                stackTrace: stackTrace,
                approxBytes: approxBytes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DebugLogEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DebugLogEventsTable,
      DebugLogEvent,
      $$DebugLogEventsTableFilterComposer,
      $$DebugLogEventsTableOrderingComposer,
      $$DebugLogEventsTableAnnotationComposer,
      $$DebugLogEventsTableCreateCompanionBuilder,
      $$DebugLogEventsTableUpdateCompanionBuilder,
      (
        DebugLogEvent,
        BaseReferences<_$AppDatabase, $DebugLogEventsTable, DebugLogEvent>,
      ),
      DebugLogEvent,
      PrefetchHooks Function()
    >;
typedef $$DebugLogUploadCursorTableCreateCompanionBuilder =
    DebugLogUploadCursorCompanion Function({
      Value<int> singletonId,
      Value<DateTime?> lastUploadedAt,
      Value<String?> lastBatchId,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
    });
typedef $$DebugLogUploadCursorTableUpdateCompanionBuilder =
    DebugLogUploadCursorCompanion Function({
      Value<int> singletonId,
      Value<DateTime?> lastUploadedAt,
      Value<String?> lastBatchId,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
    });

class $$DebugLogUploadCursorTableFilterComposer
    extends Composer<_$AppDatabase, $DebugLogUploadCursorTable> {
  $$DebugLogUploadCursorTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUploadedAt => $composableBuilder(
    column: $table.lastUploadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastBatchId => $composableBuilder(
    column: $table.lastBatchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DebugLogUploadCursorTableOrderingComposer
    extends Composer<_$AppDatabase, $DebugLogUploadCursorTable> {
  $$DebugLogUploadCursorTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUploadedAt => $composableBuilder(
    column: $table.lastUploadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastBatchId => $composableBuilder(
    column: $table.lastBatchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DebugLogUploadCursorTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebugLogUploadCursorTable> {
  $$DebugLogUploadCursorTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUploadedAt => $composableBuilder(
    column: $table.lastUploadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastBatchId => $composableBuilder(
    column: $table.lastBatchId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );
}

class $$DebugLogUploadCursorTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DebugLogUploadCursorTable,
          DebugLogUploadCursorData,
          $$DebugLogUploadCursorTableFilterComposer,
          $$DebugLogUploadCursorTableOrderingComposer,
          $$DebugLogUploadCursorTableAnnotationComposer,
          $$DebugLogUploadCursorTableCreateCompanionBuilder,
          $$DebugLogUploadCursorTableUpdateCompanionBuilder,
          (
            DebugLogUploadCursorData,
            BaseReferences<
              _$AppDatabase,
              $DebugLogUploadCursorTable,
              DebugLogUploadCursorData
            >,
          ),
          DebugLogUploadCursorData,
          PrefetchHooks Function()
        > {
  $$DebugLogUploadCursorTableTableManager(
    _$AppDatabase db,
    $DebugLogUploadCursorTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebugLogUploadCursorTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebugLogUploadCursorTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DebugLogUploadCursorTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<DateTime?> lastUploadedAt = const Value.absent(),
                Value<String?> lastBatchId = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
              }) => DebugLogUploadCursorCompanion(
                singletonId: singletonId,
                lastUploadedAt: lastUploadedAt,
                lastBatchId: lastBatchId,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
              ),
          createCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<DateTime?> lastUploadedAt = const Value.absent(),
                Value<String?> lastBatchId = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
              }) => DebugLogUploadCursorCompanion.insert(
                singletonId: singletonId,
                lastUploadedAt: lastUploadedAt,
                lastBatchId: lastBatchId,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DebugLogUploadCursorTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DebugLogUploadCursorTable,
      DebugLogUploadCursorData,
      $$DebugLogUploadCursorTableFilterComposer,
      $$DebugLogUploadCursorTableOrderingComposer,
      $$DebugLogUploadCursorTableAnnotationComposer,
      $$DebugLogUploadCursorTableCreateCompanionBuilder,
      $$DebugLogUploadCursorTableUpdateCompanionBuilder,
      (
        DebugLogUploadCursorData,
        BaseReferences<
          _$AppDatabase,
          $DebugLogUploadCursorTable,
          DebugLogUploadCursorData
        >,
      ),
      DebugLogUploadCursorData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfileSnapshotsTableTableManager get profileSnapshots =>
      $$ProfileSnapshotsTableTableManager(_db, _db.profileSnapshots);
  $$CalendarDayCachesTableTableManager get calendarDayCaches =>
      $$CalendarDayCachesTableTableManager(_db, _db.calendarDayCaches);
  $$CalendarMonthCachesTableTableManager get calendarMonthCaches =>
      $$CalendarMonthCachesTableTableManager(_db, _db.calendarMonthCaches);
  $$ConversationSessionsTableTableManager get conversationSessions =>
      $$ConversationSessionsTableTableManager(_db, _db.conversationSessions);
  $$ConversationEntriesTableTableManager get conversationEntries =>
      $$ConversationEntriesTableTableManager(_db, _db.conversationEntries);
  $$DebugLogEventsTableTableManager get debugLogEvents =>
      $$DebugLogEventsTableTableManager(_db, _db.debugLogEvents);
  $$DebugLogUploadCursorTableTableManager get debugLogUploadCursor =>
      $$DebugLogUploadCursorTableTableManager(_db, _db.debugLogUploadCursor);
}
