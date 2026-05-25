import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notification_item.dart';
import '../domain/sale.dart';
import '../domain/sale_event.dart';
import 'notification_fetcher.dart';
import 'notification_parser.dart';
import 'sale_database.dart';

final saleDatabaseProvider = Provider<SaleDatabase>((ref) {
  final db = SaleDatabase();
  ref.onDispose(db.close);
  return db;
});

final saleRepositoryProvider = FutureProvider<SaleRepository>((ref) async {
  return SaleRepository(
    fetcher: await ref.watch(notificationFetcherProvider.future),
    parser: NotificationParser(),
    db: ref.watch(saleDatabaseProvider),
  );
});

class SyncResult {
  final int httpStatus;
  final int parsedEvents;
  final List<SaleEvent> newEvents;
  final List<NotificationItem> allNotifications;
  final int pagesFetched;
  final String? errorMessage;
  final bool needsLogin;
  const SyncResult({
    required this.httpStatus,
    required this.parsedEvents,
    required this.newEvents,
    this.allNotifications = const [],
    this.pagesFetched = 0,
    this.errorMessage,
    this.needsLogin = false,
  });

  bool get isError => errorMessage != null;
  bool get isRateLimited => httpStatus == 429 || httpStatus == 503;
}

class SaleRepository {
  SaleRepository({
    required NotificationFetcher fetcher,
    required NotificationParser parser,
    required SaleDatabase db,
  })  : _fetcher = fetcher,
        _parser = parser,
        _db = db;

  final NotificationFetcher _fetcher;
  final NotificationParser _parser;
  final SaleDatabase _db;

  /// Fetches [pages] pages of /notifications, parses every page,
  /// dedupes events and applies them to the DB.
  Future<SyncResult> sync({required int pages}) async {
    try {
      final fetched = await _fetcher.fetchPages(pages);
      if (fetched.needsLogin) {
        return const SyncResult(
          httpStatus: 401,
          parsedEvents: 0,
          newEvents: [],
          needsLogin: true,
          errorMessage: 'ログインが必要です',
        );
      }
      if (fetched.isEmpty) {
        return const SyncResult(
          httpStatus: 0,
          parsedEvents: 0,
          newEvents: [],
          errorMessage: 'no pages fetched',
        );
      }
      final allEvents = <SaleEvent>[];
      final allNotifications = <NotificationItem>[];
      for (final p in fetched.pages) {
        if (p.html == null) continue;
        allEvents.addAll(_parser.parse(p.html!));
        allNotifications.addAll(_parser.parseAll(p.html!));
      }
      // Dedup by (type, occurredAt) — same event may appear once per page
      // because intra lists older + newer items together depending on view.
      final unique = <String, SaleEvent>{};
      for (final e in allEvents) {
        unique['${e.type.name}:${e.occurredAt.toIso8601String()}'] = e;
      }
      final applied = await _db.applyEvents(unique.values.toList());
      return SyncResult(
        httpStatus: 200,
        parsedEvents: unique.length,
        newEvents: applied,
        allNotifications: allNotifications,
        pagesFetched: fetched.pages.length,
      );
    } catch (e) {
      return SyncResult(
        httpStatus: 0,
        parsedEvents: 0,
        newEvents: const [],
        errorMessage: e.toString(),
      );
    }
  }

  Future<List<Sale>> history() => _db.allSales();
  Future<Sale?> ongoing() => _db.ongoing();
  Future<Sale?> mostRecent() => _db.mostRecent();
  Future<int> clearHistory() => _db.clearAll();
}
