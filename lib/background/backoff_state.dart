import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists exponential-backoff state across worker invocations.
///
/// Schedule per spec §6:
///   step 0 -> 5 min, 1 -> 15 min, 2 -> 60 min, anything more -> next periodic run.
/// On 429/503 force a minimum 6h cooldown.
class BackoffState {
  static const _stepKey = 'bo_step';
  static const _untilKey = 'bo_until';
  static const _etagKey = 'bo_etag';
  static const _lastModKey = 'bo_last_mod';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _steps = <Duration>[
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(hours: 1),
  ];

  Future<bool> shouldSkip() async {
    final v = await _storage.read(key: _untilKey);
    if (v == null) return false;
    final until = DateTime.tryParse(v);
    if (until == null) return false;
    return DateTime.now().toUtc().isBefore(until);
  }

  Future<void> noteSuccess() async {
    await _storage.delete(key: _stepKey);
    await _storage.delete(key: _untilKey);
  }

  Future<void> noteFailure({bool rateLimited = false}) async {
    if (rateLimited) {
      final until = DateTime.now().toUtc().add(const Duration(hours: 6));
      await _storage.write(key: _untilKey, value: until.toIso8601String());
      await _storage.write(key: _stepKey, value: '99');
      return;
    }
    final stepStr = await _storage.read(key: _stepKey);
    final step = int.tryParse(stepStr ?? '0') ?? 0;
    if (step >= _steps.length) {
      await _storage.write(key: _stepKey, value: '${step + 1}');
      return;
    }
    final wait = _steps[step];
    final until = DateTime.now().toUtc().add(wait);
    await _storage.write(key: _stepKey, value: '${step + 1}');
    await _storage.write(key: _untilKey, value: until.toIso8601String());
  }

  Future<({String? etag, String? lastModified})> readCacheValidators() async {
    return (
      etag: await _storage.read(key: _etagKey),
      lastModified: await _storage.read(key: _lastModKey),
    );
  }

  Future<void> writeCacheValidators({
    String? etag,
    String? lastModified,
  }) async {
    if (etag != null) await _storage.write(key: _etagKey, value: etag);
    if (lastModified != null) {
      await _storage.write(key: _lastModKey, value: lastModified);
    }
  }
}
