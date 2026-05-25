import '../../../core/notifications/notification_service.dart';
import 'evaluation_fetcher.dart';
import 'sale_repository.dart';

/// Aggregated result of one sync cycle. UI callers pull out the fetched
/// notifications and evaluations to update their state notifiers — that
/// way the startup sync and the manual refresh use the same HTTP calls
/// that drive both the sale DB and the on-screen list state.
class SyncOutcome {
  final SyncResult sale;
  final EvaluationsResult evaluations;
  const SyncOutcome({required this.sale, required this.evaluations});
}

Future<SyncOutcome> performSync({
  required SaleRepository repo,
  required NotificationService notifier,
  required EvaluationFetcher evalFetcher,
  required int pages,
}) async {
  final saleResult = await repo.sync(pages: pages);

  // Always attempt evaluations even on sale errors — they're independent
  // requests and we still want the reservation list to be fresh.
  final evalResult = await evalFetcher.fetch();

  if (!saleResult.isError && !saleResult.needsLogin) {
    final ongoing = await repo.ongoing();
    await notifier.setOngoingSaleReminders(ongoing: ongoing != null);
  }
  if (!evalResult.needsLogin && evalResult.error == null) {
    await notifier.setEvaluationReminders(
      hasEvaluations: evalResult.items.isNotEmpty,
    );
  }

  return SyncOutcome(sale: saleResult, evaluations: evalResult);
}
