import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_status.dart';
import '../../core/auth/web_login_page.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/theme_mode.dart';
import '../sale/data/sale_repository.dart';
import '../sale/presentation/home_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _openLogin(BuildContext context, WidgetRef ref) async {
    final http = await ref.read(httpClientProvider.future);
    if (!context.mounted) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WebLoginPage(httpClient: http)),
    );
    ref.invalidate(authStatusProvider);
    ref.invalidate(usernameProvider);
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログイン成功')),
      );
    }
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('履歴を削除しますか？'),
        content: const Text(
          'えばぽせーる履歴の DB を空にします。'
          '次回更新時に再構築されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = await ref.read(saleRepositoryProvider.future);
    final n = await repo.clearHistory();
    ref.invalidate(historyProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n件削除しました')),
      );
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final auth = await ref.read(authServiceProvider.future);
    await auth.logout();
    ref.invalidate(authStatusProvider);
    ref.invalidate(usernameProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログアウトしました')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authStatusProvider);
    final username = ref.watch(usernameProvider);
    final pages = ref.watch(fetchPagesProvider);
    final notifier = ref.read(fetchPagesProvider.notifier);
    final theme = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: status.when(
                data: (ok) => Icon(
                  ok ? Icons.check_circle : Icons.cancel,
                  color: ok ? Colors.green : Colors.orange,
                ),
                loading: () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Icon(Icons.error),
              ),
              title: Text(
                status.maybeWhen(
                  data: (ok) {
                    if (!ok) return '未ログイン';
                    final name = username.asData?.value;
                    return name != null ? 'ログイン中: $name' : 'ログイン中';
                  },
                  orElse: () => '確認中…',
                ),
              ),
              subtitle: const Text('profile.intra.42.fr'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ログイン画面の「Remember me」にチェックを入れてからログインしてください。'
                      'チェックなしだとセッションがすぐ切れて再ログインが頻繁になります。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _openLogin(context, ref),
            icon: const Icon(Icons.login),
            label: const Text('ログイン (WebView を開く)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Cookie を消去 (ログアウト)'),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _clearHistory(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('えばぽせーる履歴を削除'),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.brightness_6),
                      const SizedBox(width: 8),
                      Text('テーマ', style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto),
                        label: Text('自動'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('ライト'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('ダーク'),
                      ),
                    ],
                    selected: {theme},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).set(s.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.layers),
                      const SizedBox(width: 8),
                      Text(
                        '読み込みページ数: $pages',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  Slider(
                    value: pages.toDouble(),
                    min: notifier.min.toDouble(),
                    max: notifier.max.toDouble(),
                    divisions: notifier.max - notifier.min,
                    label: '$pagesページ',
                    onChanged: (v) => notifier.set(v.round()),
                  ),
                  const Text(
                    '/notifications を何ページ分まで遡るか。多いほど過去のえばぽせーる が拾えますが、'
                    'リクエスト数も増えます。',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '初回および Cookie 期限切れ時はログインボタンから WebView を開いて'
            '通常通りログインしてください (2FA も WebView 内で完了します)。'
            'ログイン後はパスワードは保存されず、セッション Cookie のみが'
            'デバイスに暗号化保存されます。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
