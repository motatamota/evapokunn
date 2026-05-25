import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_settings.dart';
import '../data/sale_repository.dart';
import '../domain/sale.dart';
import '../domain/sale_predictor.dart';
import '../../settings/settings_page.dart';
import 'history_page.dart';
import 'notifications_page.dart';
import 'raw_html_page.dart';

final _predictorProvider = Provider<SalePredictor>((_) => SalePredictor());

final historyProvider = FutureProvider<List<Sale>>((ref) async {
  final repo = await ref.watch(saleRepositoryProvider.future);
  return repo.history();
});

final lastSyncProvider = StateProvider<DateTime?>((_) => null);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static final _dateFmt = DateFormat('yyyy/MM/dd HH:mm', 'ja');

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final repo = await ref.read(saleRepositoryProvider.future);
    final pages = ref.read(fetchPagesProvider);
    final result = await repo.sync(pages: pages);
    ref.read(lastSyncProvider.notifier).state = DateTime.now();
    ref.invalidate(historyProvider);
    if (!context.mounted) return;
    if (result.needsLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です (Settings から)')),
      );
    } else if (result.isError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('取得失敗: ${result.errorMessage}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          '$pagesページ確認 / 新規 ${result.newEvents.length}件',
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _refresh(context, ref),
        icon: const Icon(Icons.refresh),
        label: const Text('更新'),
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sales) {
          final ongoing = sales.where((s) => s.endAt == null).toList();
          final closed = sales.where((s) => s.endAt != null).toList();
          final mostRecent = sales.isEmpty ? null : sales.first;
          final prediction = ref.read(_predictorProvider).predict(sales);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                  '最終取得: ${_dateFmt.format(lastSync)}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
            ],
          );
        },
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
    final endText = s.endAt == null ? '進行中' : _dateFmt.format(s.endAt!.toLocal());
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title, style: Theme.of(c).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text('開始: ${_dateFmt.format(s.startAt.toLocal())}'),
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
        title: Text(_dateFmt.format(p.expectedStart.toLocal())),
        subtitle: Text(
          '±${p.uncertainty.inHours}時間 (サンプル${p.sampleSize}件)',
        ),
      ),
    );
  }
}
