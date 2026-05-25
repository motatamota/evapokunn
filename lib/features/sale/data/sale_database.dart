import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/sale.dart';
import '../domain/sale_event.dart';

part 'sale_database.g.dart';

@DataClassName('SaleRow')
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime().nullable()();
  TextColumn get title => text()();
  DateTimeColumn get detectedAt => dateTime()();
}

/// Tracks the most recent observation of an event so we can skip duplicates.
class EventCursors extends Table {
  TextColumn get key => text()();
  DateTimeColumn get lastSeenAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Sales, EventCursors])
class SaleDatabase extends _$SaleDatabase {
  SaleDatabase() : super(_openConnection());
  SaleDatabase.test(super.executor);

  @override
  int get schemaVersion => 1;

  Future<List<Sale>> allSales() async {
    final rows = await (select(sales)
          ..orderBy([(t) => OrderingTerm.desc(t.startAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  Future<Sale?> mostRecent() async {
    final row = await (select(sales)
          ..orderBy([(t) => OrderingTerm.desc(t.startAt)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<Sale?> ongoing() async {
    final row = await (select(sales)
          ..where((t) => t.endAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startAt)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Apply a list of parsed events, idempotently.
  /// - A start event becomes a new Sale row (skipped if start time matches existing).
  /// - An end event closes the most recent open Sale, or creates a closed one
  ///   if no matching open Sale is found.
  /// Returns the events that produced new DB changes (for notification purposes).
  Future<List<SaleEvent>> applyEvents(List<SaleEvent> events) async {
    final byTime = [...events]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final newOrChanged = <SaleEvent>[];
    final now = DateTime.now().toUtc();
    await transaction(() async {
      for (final ev in byTime) {
        if (ev.type == SaleEventType.start) {
          final existing = await (select(sales)
                ..where((t) => t.startAt.equals(ev.occurredAt))
                ..limit(1))
              .getSingleOrNull();
          if (existing != null) continue;
          await into(sales).insert(SalesCompanion.insert(
            startAt: ev.occurredAt,
            title: ev.rawTitle,
            detectedAt: now,
          ));
          newOrChanged.add(ev);
        } else {
          final open = await (select(sales)
                ..where((t) =>
                    t.endAt.isNull() & t.startAt.isSmallerThanValue(ev.occurredAt))
                ..orderBy([(t) => OrderingTerm.desc(t.startAt)])
                ..limit(1))
              .getSingleOrNull();
          if (open != null) {
            await (update(sales)..where((t) => t.id.equals(open.id)))
                .write(SalesCompanion(endAt: Value(ev.occurredAt)));
            newOrChanged.add(ev);
          } else {
            // End without a known start: record a same-instant zero-length sale
            // so the history is at least visible.
            await into(sales).insert(SalesCompanion.insert(
              startAt: ev.occurredAt,
              endAt: Value(ev.occurredAt),
              title: ev.rawTitle,
              detectedAt: now,
            ));
            newOrChanged.add(ev);
          }
        }
      }
    });
    return newOrChanged;
  }

  Sale _toDomain(SaleRow row) => Sale(
        id: row.id,
        startAt: row.startAt,
        endAt: row.endAt,
        title: row.title,
        detectedAt: row.detectedAt,
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'sales.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
