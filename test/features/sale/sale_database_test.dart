import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_tracker/features/sale/data/sale_database.dart';
import 'package:sale_tracker/features/sale/domain/sale_event.dart';
import 'package:sqlite3/open.dart' as sqlite_open;

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      sqlite_open.open.overrideForAll(
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  late SaleDatabase db;

  setUp(() {
    db = SaleDatabase.test(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('SaleDatabase.applyEvents', () {
    test('start event creates a new ongoing sale', () async {
      final start = DateTime.utc(2026, 5, 20, 1, 0);
      await db.applyEvents([
        SaleEvent(
          type: SaleEventType.start,
          occurredAt: start,
          rawTitle: 'sale が開始しました',
        ),
      ]);
      final ongoing = await db.ongoing();
      expect(ongoing, isNotNull);
      expect(ongoing!.startAt.toUtc(), start);
      expect(ongoing.endAt, isNull);
    });

    test('end event closes the matching ongoing sale', () async {
      final start = DateTime.utc(2026, 5, 20, 1, 0);
      final end = DateTime.utc(2026, 5, 22, 9, 0);
      await db.applyEvents([
        SaleEvent(
            type: SaleEventType.start, occurredAt: start, rawTitle: 'started'),
        SaleEvent(
            type: SaleEventType.end, occurredAt: end, rawTitle: 'ended'),
      ]);
      expect(await db.ongoing(), isNull);
      final history = await db.allSales();
      expect(history, hasLength(1));
      expect(history.first.endAt!.toUtc(), end);
    });

    test('duplicate start with same timestamp is ignored', () async {
      final start = DateTime.utc(2026, 5, 20, 1, 0);
      final ev = SaleEvent(
        type: SaleEventType.start,
        occurredAt: start,
        rawTitle: 'sale started',
      );
      await db.applyEvents([ev]);
      await db.applyEvents([ev]);
      final history = await db.allSales();
      expect(history, hasLength(1));
    });

    test('end event is idempotent — same end applied twice does not '
        'close a second open sale', () async {
      final realStart = DateTime.utc(2026, 5, 20, 4, 10); // 13:10 JST
      final realEnd = DateTime.utc(2026, 5, 20, 9, 25);   // 18:25 JST
      final staleOpenStart = DateTime.utc(2026, 5, 18, 4, 10);

      // A stale open sale row from earlier (e.g. wrongly recorded
      // announcement before the fix).
      await db.applyEvents([
        SaleEvent(
            type: SaleEventType.start,
            occurredAt: staleOpenStart,
            rawTitle: 'stale'),
        SaleEvent(
            type: SaleEventType.start,
            occurredAt: realStart,
            rawTitle: 'real'),
      ]);
      // First end: closes the most recent open (realStart).
      await db.applyEvents([
        SaleEvent(
            type: SaleEventType.end, occurredAt: realEnd, rawTitle: 'end'),
      ]);
      // Second application of the same end (e.g. user refreshed again).
      await db.applyEvents([
        SaleEvent(
            type: SaleEventType.end, occurredAt: realEnd, rawTitle: 'end'),
      ]);

      final all = await db.allSales();
      // Should still be: stale=open, real=closed.
      expect(all.length, 2);
      final closed = all.where((s) => s.endAt != null).toList();
      expect(closed, hasLength(1));
      expect(closed.first.startAt.toUtc(), realStart);
    });

    test('end with no matching open sale creates a zero-length sale', () async {
      final end = DateTime.utc(2026, 5, 22, 9, 0);
      await db.applyEvents([
        SaleEvent(
            type: SaleEventType.end, occurredAt: end, rawTitle: 'ended'),
      ]);
      final history = await db.allSales();
      expect(history, hasLength(1));
      expect(history.first.startAt.toUtc(), end);
      expect(history.first.endAt!.toUtc(), end);
    });
  });
}
