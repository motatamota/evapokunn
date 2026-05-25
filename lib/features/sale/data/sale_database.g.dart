// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_database.dart';

// ignore_for_file: type=lint
class $SalesTable extends Sales with TableInfo<$SalesTable, SaleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _startAtMeta =
      const VerificationMeta('startAt');
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
      'start_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
      'end_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _detectedAtMeta =
      const VerificationMeta('detectedAt');
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
      'detected_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, startAt, endAt, title, detectedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(Insertable<SaleRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start_at')) {
      context.handle(_startAtMeta,
          startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta));
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
          _endAtMeta, endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('detected_at')) {
      context.handle(
          _detectedAtMeta,
          detectedAt.isAcceptableOrUnknown(
              data['detected_at']!, _detectedAtMeta));
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SaleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      startAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_at'])!,
      endAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_at']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      detectedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}detected_at'])!,
    );
  }

  @override
  $SalesTable createAlias(String alias) {
    return $SalesTable(attachedDatabase, alias);
  }
}

class SaleRow extends DataClass implements Insertable<SaleRow> {
  final int id;
  final DateTime startAt;
  final DateTime? endAt;
  final String title;
  final DateTime detectedAt;
  const SaleRow(
      {required this.id,
      required this.startAt,
      this.endAt,
      required this.title,
      required this.detectedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['start_at'] = Variable<DateTime>(startAt);
    if (!nullToAbsent || endAt != null) {
      map['end_at'] = Variable<DateTime>(endAt);
    }
    map['title'] = Variable<String>(title);
    map['detected_at'] = Variable<DateTime>(detectedAt);
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      id: Value(id),
      startAt: Value(startAt),
      endAt:
          endAt == null && nullToAbsent ? const Value.absent() : Value(endAt),
      title: Value(title),
      detectedAt: Value(detectedAt),
    );
  }

  factory SaleRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleRow(
      id: serializer.fromJson<int>(json['id']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      endAt: serializer.fromJson<DateTime?>(json['endAt']),
      title: serializer.fromJson<String>(json['title']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startAt': serializer.toJson<DateTime>(startAt),
      'endAt': serializer.toJson<DateTime?>(endAt),
      'title': serializer.toJson<String>(title),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
    };
  }

  SaleRow copyWith(
          {int? id,
          DateTime? startAt,
          Value<DateTime?> endAt = const Value.absent(),
          String? title,
          DateTime? detectedAt}) =>
      SaleRow(
        id: id ?? this.id,
        startAt: startAt ?? this.startAt,
        endAt: endAt.present ? endAt.value : this.endAt,
        title: title ?? this.title,
        detectedAt: detectedAt ?? this.detectedAt,
      );
  SaleRow copyWithCompanion(SalesCompanion data) {
    return SaleRow(
      id: data.id.present ? data.id.value : this.id,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      title: data.title.present ? data.title.value : this.title,
      detectedAt:
          data.detectedAt.present ? data.detectedAt.value : this.detectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleRow(')
          ..write('id: $id, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('title: $title, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startAt, endAt, title, detectedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleRow &&
          other.id == this.id &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.title == this.title &&
          other.detectedAt == this.detectedAt);
}

class SalesCompanion extends UpdateCompanion<SaleRow> {
  final Value<int> id;
  final Value<DateTime> startAt;
  final Value<DateTime?> endAt;
  final Value<String> title;
  final Value<DateTime> detectedAt;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.title = const Value.absent(),
    this.detectedAt = const Value.absent(),
  });
  SalesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startAt,
    this.endAt = const Value.absent(),
    required String title,
    required DateTime detectedAt,
  })  : startAt = Value(startAt),
        title = Value(title),
        detectedAt = Value(detectedAt);
  static Insertable<SaleRow> custom({
    Expression<int>? id,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<String>? title,
    Expression<DateTime>? detectedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (title != null) 'title': title,
      if (detectedAt != null) 'detected_at': detectedAt,
    });
  }

  SalesCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? startAt,
      Value<DateTime?>? endAt,
      Value<String>? title,
      Value<DateTime>? detectedAt}) {
    return SalesCompanion(
      id: id ?? this.id,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      title: title ?? this.title,
      detectedAt: detectedAt ?? this.detectedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('id: $id, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('title: $title, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }
}

class $EventCursorsTable extends EventCursors
    with TableInfo<$EventCursorsTable, EventCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
      'last_seen_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, lastSeenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_cursors';
  @override
  VerificationContext validateIntegrity(Insertable<EventCursor> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  EventCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventCursor(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen_at'])!,
    );
  }

  @override
  $EventCursorsTable createAlias(String alias) {
    return $EventCursorsTable(attachedDatabase, alias);
  }
}

class EventCursor extends DataClass implements Insertable<EventCursor> {
  final String key;
  final DateTime lastSeenAt;
  const EventCursor({required this.key, required this.lastSeenAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  EventCursorsCompanion toCompanion(bool nullToAbsent) {
    return EventCursorsCompanion(
      key: Value(key),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory EventCursor.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventCursor(
      key: serializer.fromJson<String>(json['key']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  EventCursor copyWith({String? key, DateTime? lastSeenAt}) => EventCursor(
        key: key ?? this.key,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );
  EventCursor copyWithCompanion(EventCursorsCompanion data) {
    return EventCursor(
      key: data.key.present ? data.key.value : this.key,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventCursor(')
          ..write('key: $key, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventCursor &&
          other.key == this.key &&
          other.lastSeenAt == this.lastSeenAt);
}

class EventCursorsCompanion extends UpdateCompanion<EventCursor> {
  final Value<String> key;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const EventCursorsCompanion({
    this.key = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventCursorsCompanion.insert({
    required String key,
    required DateTime lastSeenAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        lastSeenAt = Value(lastSeenAt);
  static Insertable<EventCursor> custom({
    Expression<String>? key,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventCursorsCompanion copyWith(
      {Value<String>? key, Value<DateTime>? lastSeenAt, Value<int>? rowid}) {
    return EventCursorsCompanion(
      key: key ?? this.key,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventCursorsCompanion(')
          ..write('key: $key, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SaleDatabase extends GeneratedDatabase {
  _$SaleDatabase(QueryExecutor e) : super(e);
  $SaleDatabaseManager get managers => $SaleDatabaseManager(this);
  late final $SalesTable sales = $SalesTable(this);
  late final $EventCursorsTable eventCursors = $EventCursorsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [sales, eventCursors];
}

typedef $$SalesTableCreateCompanionBuilder = SalesCompanion Function({
  Value<int> id,
  required DateTime startAt,
  Value<DateTime?> endAt,
  required String title,
  required DateTime detectedAt,
});
typedef $$SalesTableUpdateCompanionBuilder = SalesCompanion Function({
  Value<int> id,
  Value<DateTime> startAt,
  Value<DateTime?> endAt,
  Value<String> title,
  Value<DateTime> detectedAt,
});

class $$SalesTableFilterComposer extends Composer<_$SaleDatabase, $SalesTable> {
  $$SalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => ColumnFilters(column));
}

class $$SalesTableOrderingComposer
    extends Composer<_$SaleDatabase, $SalesTable> {
  $$SalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => ColumnOrderings(column));
}

class $$SalesTableAnnotationComposer
    extends Composer<_$SaleDatabase, $SalesTable> {
  $$SalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => column);
}

class $$SalesTableTableManager extends RootTableManager<
    _$SaleDatabase,
    $SalesTable,
    SaleRow,
    $$SalesTableFilterComposer,
    $$SalesTableOrderingComposer,
    $$SalesTableAnnotationComposer,
    $$SalesTableCreateCompanionBuilder,
    $$SalesTableUpdateCompanionBuilder,
    (SaleRow, BaseReferences<_$SaleDatabase, $SalesTable, SaleRow>),
    SaleRow,
    PrefetchHooks Function()> {
  $$SalesTableTableManager(_$SaleDatabase db, $SalesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> startAt = const Value.absent(),
            Value<DateTime?> endAt = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<DateTime> detectedAt = const Value.absent(),
          }) =>
              SalesCompanion(
            id: id,
            startAt: startAt,
            endAt: endAt,
            title: title,
            detectedAt: detectedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime startAt,
            Value<DateTime?> endAt = const Value.absent(),
            required String title,
            required DateTime detectedAt,
          }) =>
              SalesCompanion.insert(
            id: id,
            startAt: startAt,
            endAt: endAt,
            title: title,
            detectedAt: detectedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SalesTableProcessedTableManager = ProcessedTableManager<
    _$SaleDatabase,
    $SalesTable,
    SaleRow,
    $$SalesTableFilterComposer,
    $$SalesTableOrderingComposer,
    $$SalesTableAnnotationComposer,
    $$SalesTableCreateCompanionBuilder,
    $$SalesTableUpdateCompanionBuilder,
    (SaleRow, BaseReferences<_$SaleDatabase, $SalesTable, SaleRow>),
    SaleRow,
    PrefetchHooks Function()>;
typedef $$EventCursorsTableCreateCompanionBuilder = EventCursorsCompanion
    Function({
  required String key,
  required DateTime lastSeenAt,
  Value<int> rowid,
});
typedef $$EventCursorsTableUpdateCompanionBuilder = EventCursorsCompanion
    Function({
  Value<String> key,
  Value<DateTime> lastSeenAt,
  Value<int> rowid,
});

class $$EventCursorsTableFilterComposer
    extends Composer<_$SaleDatabase, $EventCursorsTable> {
  $$EventCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));
}

class $$EventCursorsTableOrderingComposer
    extends Composer<_$SaleDatabase, $EventCursorsTable> {
  $$EventCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));
}

class $$EventCursorsTableAnnotationComposer
    extends Composer<_$SaleDatabase, $EventCursorsTable> {
  $$EventCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => column);
}

class $$EventCursorsTableTableManager extends RootTableManager<
    _$SaleDatabase,
    $EventCursorsTable,
    EventCursor,
    $$EventCursorsTableFilterComposer,
    $$EventCursorsTableOrderingComposer,
    $$EventCursorsTableAnnotationComposer,
    $$EventCursorsTableCreateCompanionBuilder,
    $$EventCursorsTableUpdateCompanionBuilder,
    (
      EventCursor,
      BaseReferences<_$SaleDatabase, $EventCursorsTable, EventCursor>
    ),
    EventCursor,
    PrefetchHooks Function()> {
  $$EventCursorsTableTableManager(_$SaleDatabase db, $EventCursorsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<DateTime> lastSeenAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EventCursorsCompanion(
            key: key,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required DateTime lastSeenAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              EventCursorsCompanion.insert(
            key: key,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EventCursorsTableProcessedTableManager = ProcessedTableManager<
    _$SaleDatabase,
    $EventCursorsTable,
    EventCursor,
    $$EventCursorsTableFilterComposer,
    $$EventCursorsTableOrderingComposer,
    $$EventCursorsTableAnnotationComposer,
    $$EventCursorsTableCreateCompanionBuilder,
    $$EventCursorsTableUpdateCompanionBuilder,
    (
      EventCursor,
      BaseReferences<_$SaleDatabase, $EventCursorsTable, EventCursor>
    ),
    EventCursor,
    PrefetchHooks Function()>;

class $SaleDatabaseManager {
  final _$SaleDatabase _db;
  $SaleDatabaseManager(this._db);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
  $$EventCursorsTableTableManager get eventCursors =>
      $$EventCursorsTableTableManager(_db, _db.eventCursors);
}
