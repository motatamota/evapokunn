import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/evaluation_fetcher.dart';
import '../domain/evaluation.dart';

class EvaluationsState {
  final List<Evaluation> items;
  final DateTime? fetchedAt;
  final bool loading;
  final String? error;
  final bool needsLogin;
  const EvaluationsState({
    this.items = const [],
    this.fetchedAt,
    this.loading = false,
    this.error,
    this.needsLogin = false,
  });

  EvaluationsState copyWith({
    List<Evaluation>? items,
    DateTime? fetchedAt,
    bool? loading,
    Object? error = _sentinel,
    bool? needsLogin,
  }) {
    return EvaluationsState(
      items: items ?? this.items,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      needsLogin: needsLogin ?? this.needsLogin,
    );
  }
}

const _sentinel = Object();

final evaluationsProvider =
    StateNotifierProvider<EvaluationsNotifier, EvaluationsState>((ref) {
  return EvaluationsNotifier(ref);
});

class EvaluationsNotifier extends StateNotifier<EvaluationsState> {
  EvaluationsNotifier(this._ref) : super(const EvaluationsState());

  final Ref _ref;
  Future<void>? _inFlight;

  void setLoading(bool loading) {
    state = state.copyWith(loading: loading, error: null);
  }

  /// Populate state from already-fetched data so the home page card
  /// shows content instantly on startup without a second HTTP call.
  void setData(List<Evaluation> items) {
    state = EvaluationsState(
      items: items,
      fetchedAt: DateTime.now(),
      loading: false,
    );
  }

  void setNeedsLogin() {
    state = state.copyWith(loading: false, needsLogin: true);
  }

  void setError(String error) {
    state = state.copyWith(loading: false, error: error);
  }

  /// Concurrent callers share the same in-flight fetch instead of
  /// no-op'ing the second one — important because the home FAB and the
  /// startup auto-refresh can fire nearly simultaneously.
  Future<void> refresh() {
    return _inFlight ??=
        _doRefresh().whenComplete(() => _inFlight = null);
  }

  Future<void> _doRefresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final fetcher = await _ref.read(evaluationFetcherProvider.future);
      final res = await fetcher.fetch();
      if (res.needsLogin) {
        state = state.copyWith(loading: false, needsLogin: true);
        return;
      }
      if (res.error != null) {
        state = state.copyWith(loading: false, error: res.error);
        return;
      }
      state = EvaluationsState(
        items: res.items,
        fetchedAt: DateTime.now(),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}
