import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../data/notification_fetcher.dart';
import '../data/notification_parser.dart';
import '../domain/notification_item.dart';

/// State held by [notificationsProvider]. Lives as long as the app
/// process so the notifications list is restored instantly when the
/// user re-opens the page.
class NotificationsState {
  final List<NotificationItem> items;
  final DateTime? fetchedAt;
  final int pagesFetched;
  final bool loading;
  final String? error;

  const NotificationsState({
    this.items = const [],
    this.fetchedAt,
    this.pagesFetched = 0,
    this.loading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<NotificationItem>? items,
    DateTime? fetchedAt,
    int? pagesFetched,
    bool? loading,
    Object? error = _sentinel,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      pagesFetched: pagesFetched ?? this.pagesFetched,
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref);
});

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._ref) : super(const NotificationsState());

  final Ref _ref;
  final _parser = NotificationParser();

  /// True when we've never fetched data in this app session.
  bool get isEmpty => state.fetchedAt == null && state.items.isEmpty;

  Future<void> refresh() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final fetcher = await _ref.read(notificationFetcherProvider.future);
      final pages = _ref.read(fetchPagesProvider);
      final fetched = await fetcher.fetchPages(pages);
      if (fetched.needsLogin) {
        state = state.copyWith(
          loading: false,
          error: 'ログインが必要です (Settings から)',
        );
        return;
      }
      if (fetched.isEmpty) {
        state = state.copyWith(loading: false, error: '取得失敗');
        return;
      }
      final all = <NotificationItem>[];
      for (final p in fetched.pages) {
        if (p.html == null) continue;
        all.addAll(_parser.parseAll(p.html!));
      }
      all.sort((a, b) {
        final ax = a.occurredAt ?? DateTime.fromMicrosecondsSinceEpoch(0);
        final bx = b.occurredAt ?? DateTime.fromMicrosecondsSinceEpoch(0);
        return bx.compareTo(ax);
      });
      state = NotificationsState(
        items: all,
        fetchedAt: DateTime.now(),
        pagesFetched: fetched.pages.length,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}
