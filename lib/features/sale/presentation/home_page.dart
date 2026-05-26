import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_status.dart';
import '../../../core/auth/web_login_page.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/util/jst.dart';
import '../data/evaluation_fetcher.dart';
import '../data/sale_repository.dart';
import '../data/sync_runner.dart';
import '../domain/sale.dart';
import '../domain/sale_predictor.dart';
import '../../settings/settings_page.dart';
import 'evaluations_state.dart';
import 'notifications_state.dart';
import 'history_page.dart';
import 'notifications_page.dart';
import 'raw_html_page.dart';

final _predictorProvider = Provider<SalePredictor>((_) => SalePredictor());

final historyProvider = FutureProvider<List<Sale>>((ref) async {
  final repo = await ref.watch(saleRepositoryProvider.future);
  return repo.history();
});

final lastSyncProvider = StateProvider<DateTime?>((_) => null);

/// Pulls `fetch_pages` worth of notifications and pushes the result
/// into every UI state.
///
/// - **First watch** (home page first build): runs automatically.
/// - **`ref.refresh(homeSyncProvider.future)`**: re-runs on demand,
///   used by pull-to-refresh on home / notifications and by the
///   app-resume hook.
final homeSyncProvider = FutureProvider<void>((ref) async {
  try {
    final repo = await ref.read(saleRepositoryProvider.future);
    final notifier = ref.read(notificationServiceProvider);
    final evalFetcher = await ref.read(evaluationFetcherProvider.future);
    final pages = ref.read(fetchPagesProvider);
    final outcome = await performSync(
      repo: repo,
      notifier: notifier,
      evalFetcher: evalFetcher,
      pages: pages,
    );
    if (!outcome.sale.isError && !outcome.sale.needsLogin) {
      ref.read(notificationsProvider.notifier).setData(
            outcome.sale.allNotifications,
            outcome.sale.pagesFetched,
          );
    }
    if (outcome.evaluations.needsLogin) {
      ref.read(evaluationsProvider.notifier).setNeedsLogin();
    } else if (outcome.evaluations.error != null) {
      ref
          .read(evaluationsProvider.notifier)
          .setError(outcome.evaluations.error!);
    } else {
      ref
          .read(evaluationsProvider.notifier)
          .setData(outcome.evaluations.items);
    }
    ref.read(lastSyncProvider.notifier).state = DateTime.now();
    ref.invalidate(historyProvider);
  } catch (_) {
    // Best effort; user can still manually refresh.
  }
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  static const _datePattern = 'yyyy/MM/dd HH:mm';

  /// Skip auto-resume refresh if we synced very recently — avoids
  /// hammering the intra when the user just switches between apps.
  static const _resumeThrottle = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = ref.read(lastSyncProvider);
    if (last != null && DateTime.now().difference(last) < _resumeThrottle) {
      return;
    }
    ref.invalidate(homeSyncProvider);
  }

  Future<void> _openWebLogin() async {
    final http = await ref.read(httpClientProvider.future);
    if (!mounted) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WebLoginPage(httpClient: http)),
    );
    ref.invalidate(authStatusProvider);
    if (ok == true) {
      ref.invalidate(homeSyncProvider);
      await ref.read(homeSyncProvider.future);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(homeSyncProvider);
      await ref.read(homeSyncProvider.future);
    if (!mounted) return;
    final notif = ref.read(notificationsProvider);
    if (notif.error != null && notif.error!.contains('ログイン')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      _openWebLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trigger startup sync on first build; re-runs whenever the
    // provider is refreshed (pull-to-refresh, app resume).
    ref.watch(homeSyncProvider);
    final history = ref.watch(historyProvider);
    final lastSync = ref.watch(lastSyncProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('えばぽ君.exe'),
        actions: [
          IconButton(
            tooltip: '通知一覧',
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
          IconButton(
            tooltip: 'えばぽせーる 履歴',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            ),
          ),
          IconButton(
            tooltip: 'Raw HTML',
            icon: const Icon(Icons.bug_report),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RawHtmlPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: history.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(
                height: 400,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 400,
                child: Center(child: Text('Error: $e')),
              ),
            ],
          ),
          data: (sales) {
            final ongoing = sales.where((s) => s.endAt == null).toList();
            final closed = sales.where((s) => s.endAt != null).toList();
            final mostRecent = sales.isEmpty ? null : sales.first;
            final prediction = ref.read(_predictorProvider).predict(sales);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle(context, '今後のレビュー予約'),
                _EvaluationsCard(),
                const SizedBox(height: 16),
                _sectionTitle(context, '現在のえばぽせーる'),
                if (ongoing.isNotEmpty)
                  _saleCard(context, ongoing.first, ongoingHighlight: true)
                else
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.toggle_off),
                      title: Text('えばぽせーる 中ではありません'),
                    ),
                  ),
                const SizedBox(height: 16),
                _sectionTitle(context, '直近のえばぽせーる'),
                if (mostRecent != null)
                  _saleCard(context, mostRecent)
                else
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.help_outline),
                      title: Text('履歴はまだありません'),
                    ),
                  ),
                const SizedBox(height: 16),
                _sectionTitle(context, '次回予測'),
                _predictionCard(context, prediction, closed.length),
                const SizedBox(height: 16),
                if (lastSync != null)
                  Text(
                    '最終取得: ${fmtJst(lastSync, _datePattern)}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext c, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: Text(s, style: Theme.of(c).textTheme.titleMedium),
      );

  Widget _saleCard(BuildContext c, Sale s, {bool ongoingHighlight = false}) {
    final color = ongoingHighlight
        ? Theme.of(c).colorScheme.primaryContainer
        : null;
    final endText = s.endAt == null ? '進行中' : fmtJst(s.endAt!, _datePattern);
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title, style: Theme.of(c).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text('開始: ${fmtJst(s.startAt, _datePattern)}'),
            Text('終了: $endText'),
          ],
        ),
      ),
    );
  }

  Widget _predictionCard(BuildContext c, PredictionResult? p, int sampleSize) {
    if (p == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.science_outlined),
          title: const Text('予測には2回以上のえばぽせーる 履歴が必要です'),
          subtitle: Text('現在の履歴: $sampleSize件'),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_available),
        title: Text(fmtJst(p.expectedStart, _datePattern)),
        subtitle: Text(
          '±${p.uncertainty.inHours}時間 (サンプル${p.sampleSize}件)',
        ),
      ),
    );
  }
}

class _EvaluationsCard extends ConsumerWidget {
  static const _pattern = 'MM/dd HH:mm';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(evaluationsProvider);
    if (state.loading && state.fetchedAt == null) {
      return const Card(
        child: ListTile(
          leading: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('レビュー予約を確認中…'),
        ),
      );
    }
    if (state.needsLogin) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('ログインが必要'),
          subtitle: Text('Settings から WebView ログイン'),
        ),
      );
    }
    if (state.error != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text('取得失敗: ${state.error}'),
        ),
      );
    }
    if (state.items.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.event_busy),
          title: Text('レビュー予約はありません'),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (final e in state.items)
            ListTile(
              dense: true,
              leading: const Icon(Icons.assignment_ind, color: Colors.teal),
              title: Text(e.text, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: e.when == null
                  ? null
                  : Text(fmtJst(e.when!, _pattern)),
            ),
        ],
      ),
    );
  }
}
