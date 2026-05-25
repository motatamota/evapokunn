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
