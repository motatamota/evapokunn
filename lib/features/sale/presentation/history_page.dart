import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'home_page.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  static final _fmt = DateFormat('yyyy/MM/dd HH:mm', 'ja');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('えばぽせーる 履歴')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sales) {
          if (sales.isEmpty) {
            return const Center(child: Text('履歴はまだありません'));
          }
          return ListView.separated(
            itemCount: sales.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final s = sales[i];
              final dur = s.duration;
              final durText = dur == null
                  ? '進行中'
                  : '${dur.inHours}時間 ${dur.inMinutes.remainder(60)}分';
              return ListTile(
                title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${_fmt.format(s.startAt.toLocal())} → '
                  '${s.endAt == null ? '...' : _fmt.format(s.endAt!.toLocal())}',
                ),
                trailing: Text(durText),
              );
            },
          );
        },
      ),
    );
  }
}
