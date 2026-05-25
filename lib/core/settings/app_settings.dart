import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFetchPagesKey = 'fetch_pages';
const _kFetchPagesDefault = 1;
const _kFetchPagesMin = 1;
const _kFetchPagesMax = 30;

/// Overridden in `main()` with a real SharedPreferences instance loaded
/// before runApp, so any provider that reads it during the first build
/// gets the persisted value (not the default).
final sharedPrefsProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError('Override in ProviderScope before runApp');
});

final fetchPagesProvider =
    StateNotifierProvider<FetchPagesNotifier, int>((ref) {
  return FetchPagesNotifier(ref.watch(sharedPrefsProvider));
});

class FetchPagesNotifier extends StateNotifier<int> {
  FetchPagesNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static int _load(SharedPreferences prefs) {
    final v = prefs.getInt(_kFetchPagesKey) ?? _kFetchPagesDefault;
    return v.clamp(_kFetchPagesMin, _kFetchPagesMax);
  }

  Future<void> set(int value) async {
    final v = value.clamp(_kFetchPagesMin, _kFetchPagesMax);
    state = v;
    await _prefs.setInt(_kFetchPagesKey, v);
  }

  int get min => _kFetchPagesMin;
  int get max => _kFetchPagesMax;
}
