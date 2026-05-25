import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/auth/auth_service.dart';
import '../core/http/http_client.dart';
import '../core/notifications/notification_service.dart';
import '../features/sale/data/evaluation_fetcher.dart';
import '../features/sale/data/notification_fetcher.dart';
import '../features/sale/data/notification_parser.dart';
import '../features/sale/data/sale_database.dart';
import '../features/sale/data/sale_repository.dart';
import '../features/sale/data/sync_runner.dart';
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

Future<void> runSaleCheck() async {
  final backoff = BackoffState();
  if (await backoff.shouldSkip()) {
    if (!kReleaseMode) debugPrint('skip due to backoff');
    return;
  }

  final http = await HttpClient.create();
  final auth = AuthService(http: http);
  final fetcher = NotificationFetcher(http: http, auth: auth);
  final evalFetcher = EvaluationFetcher(http: http, auth: auth);
  final parser = NotificationParser();
  final db = SaleDatabase();
  final repo = SaleRepository(fetcher: fetcher, parser: parser, db: db);
  final notifier = NotificationService();
  await notifier.init();

  try {
    final prefs = await SharedPreferences.getInstance();
    final pages = prefs.getInt('fetch_pages') ?? 1;
    final result = await performSync(
      repo: repo,
      notifier: notifier,
      evalFetcher: evalFetcher,
      pages: pages,
    );
    final sale = result.sale;
    if (sale.needsLogin) return;
    if (sale.isError || sale.isRateLimited) {
      await backoff.noteFailure(rateLimited: sale.isRateLimited);
      return;
    }
    await backoff.noteSuccess();
  } finally {
    await db.close();
  }
}
