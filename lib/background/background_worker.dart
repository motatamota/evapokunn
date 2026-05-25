import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/auth_service.dart';
import '../core/http/http_client.dart';
import '../core/notifications/notification_service.dart';
import '../features/sale/data/notification_fetcher.dart';
import '../features/sale/data/notification_parser.dart';
import '../features/sale/data/sale_database.dart';
import '../features/sale/data/sale_repository.dart';
import '../features/sale/domain/sale_event.dart';
import '../features/sale/domain/sale_predictor.dart';
import 'backoff_state.dart';

const saleCheckTask = 'checkSale';
const saleCheckUniqueName = 'sale-check';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, data) async {
    try {
      await runSaleCheck();
      return true;
    } catch (e, st) {
      if (!kReleaseMode) {
        debugPrint('background error: $e\n$st');
      }
      return false;
    }
  });
}

/// Runs one sync cycle. Called from both the background worker and a
/// manual refresh path so the logic stays in one place.
Future<void> runSaleCheck() async {
  final backoff = BackoffState();
  if (await backoff.shouldSkip()) {
    if (!kReleaseMode) debugPrint('skip due to backoff');
    return;
  }

  final http = await HttpClient.create();
  final auth = AuthService(http: http);
  final fetcher = NotificationFetcher(http: http, auth: auth);
  final parser = NotificationParser();
  final db = SaleDatabase();
  final repo = SaleRepository(fetcher: fetcher, parser: parser, db: db);
  final notifier = NotificationService();
  await notifier.init();

  try {
    final prefs = await SharedPreferences.getInstance();
    final pages = prefs.getInt('fetch_pages') ?? 1;
    final result = await repo.sync(pages: pages);

    if (result.needsLogin) {
      // Can't open WebView from background; defer until user opens app.
      return;
    }
    if (result.isError || result.isRateLimited) {
      await backoff.noteFailure(rateLimited: result.isRateLimited);
      return;
    }
    await backoff.noteSuccess();

    final history = await repo.history();
    for (final ev in result.newEvents) {
      if (ev.type == SaleEventType.start) {
        final match = history.firstWhere(
          (s) => s.startAt.toUtc() == ev.occurredAt.toUtc(),
          orElse: () => history.first,
        );
        await notifier.notifySaleStarted(match);
      } else {
        final closed = history.where((s) => s.endAt != null).toList();
        if (closed.isNotEmpty) {
          await notifier.notifySaleEnded(closed.first);
        }
      }
    }

    final hasNewStart =
        result.newEvents.any((e) => e.type == SaleEventType.start);
    if (hasNewStart) {
      final prediction = SalePredictor().predict(history);
      if (prediction != null) {
        await notifier.notifyPredictedSale(prediction);
      }
    }
  } finally {
    await db.close();
  }
}
