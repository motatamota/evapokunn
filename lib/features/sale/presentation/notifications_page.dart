import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/jst.dart';
import 'home_page.dart';
import 'notifications_state.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  static const _pattern = 'MM/dd HH:mm';

  bool _saleOnly = false;

  @override
  void initState() {
    super.initState();
    // If startup sync hasn't populated us yet (e.g. user opened the
    // page mid-startup or startup failed), trigger a fetch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(notificationsProvider);
      if (state.fetchedAt == null && !state.loading) {
        ref.read(notificationsProvider.notifier).refresh();
      }
    });
  }

  Future<void> _onPullRefresh() async {
    ref.invalidate(homeSyncProvider);
    await ref.read(homeSyncProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final visible = _saleOnly
        ? state.items.where((i) => i.isSaleRelated).toList()
        : state.items;
    final totalCount = state.items.length;
    final saleCount = state.items.where((i) => i.isSaleRelated).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知一覧'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.notifications_none, size: 18),
                  label: Text('全部 ($totalCount)'),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.local_offer, size: 18),
                  label: Text('えばぽせーる ($saleCount)'),
                ),
              ],
              selected: {_saleOnly},
              onSelectionChanged: (s) => setState(() => _saleOnly = s.first),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onPullRefresh,
        child: Column(
          children: [
            if (state.loading) const LinearProgressIndicator(),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Error: ${state.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (state.fetchedAt != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  '取得: ${fmtJst(state.fetchedAt!, _pattern)} '
                  '・ ${state.pagesFetched}ページ ・ 表示 ${visible.length}件',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Expanded(child: _scrollableBody(visible, state)),
          ],
        ),
      ),
    );
  }

  /// Returns a scrollable widget so [RefreshIndicator] always has a
  /// scrollable child — even for the empty / first-load states.
  Widget _scrollableBody(List visible, NotificationsState state) {
    if (state.items.isEmpty && !state.loading && state.error == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 400,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_down, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('下にスワイプで通知を取得'),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (visible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 400,
            child: Center(child: Text('該当する通知はありません')),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (_, i) {
        final n = visible[i];
        final when = n.occurredAt;
        return ListTile(
          leading: n.isSaleRelated
              ? const Icon(Icons.local_offer, color: Colors.orange)
              : const Icon(Icons.notifications_none),
          title: Text(
            n.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: when == null ? null : Text(fmtJst(when, _pattern)),
        );
      },
    );
  }
}
