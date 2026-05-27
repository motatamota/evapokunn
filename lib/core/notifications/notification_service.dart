import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'sale_tracker_channel';
  static const _channelName = 'えばぽ君.exe';
  static const _channelDesc = 'えばぽせーる / レビュー予約のリマインダー';

  /// One-shot notification fired the moment we detect a fresh
  /// ongoing sale period (de-duped by sale start time).
  static const _saleOneShotId = 30000;

  /// Persisted marker: ms-since-epoch of the most recent sale whose
  /// "detected" notification we've already fired. Lets us notify once
  /// per sale instance even across background syncs.
  static const _notifiedSaleStartKey = 'notified_sale_start_ms';

  /// Old periodic reminder ID range — cancelled on startup so users
  /// upgrading from the 9/12/15/18 schedule don't keep getting them.
  static const _legacySaleReminderIdBase = 10000;
  static const _legacySaleReminderCount = 28;

  /// Evaluation reminders: every 30 minutes for the next 24 hours.
  static const _evalReminderIdBase = 20000;
  static const _evalReminderIntervalMinutes = 30;
  static const _evalReminderCount = 48;

  /// JST is the only schedule timezone we care about — the app is
  /// Japan-centric and we want reminders to fire at Tokyo wall time
  /// regardless of the device timezone.
  late final tz.Location _jst;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _jst = tz.getLocation('Asia/Tokyo');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Call on every sync. Fires a one-shot notification the first time
  /// we observe a given sale instance (identified by its start time),
  /// then stays silent for that same sale until it ends.
  ///
  /// Passing [saleStartAt] = null means no ongoing sale; resets the
  /// dedup marker so the next sale will fire its own notification.
  Future<void> notifyOngoingSale({DateTime? saleStartAt}) async {
    await init();
    // Sweep any leftover scheduled periodic reminders from older
    // versions (the 9/12/15/18 schedule).
    await _cancelRange(_legacySaleReminderIdBase, _legacySaleReminderCount);

    final prefs = await SharedPreferences.getInstance();
    if (saleStartAt == null) {
      await prefs.remove(_notifiedSaleStartKey);
      return;
    }

    final ms = saleStartAt.millisecondsSinceEpoch;
    if (prefs.getInt(_notifiedSaleStartKey) == ms) return;

    await _plugin.show(
      _saleOneShotId,
      'えばぽせーる開催中!',
      '今がチャンス！レビューしてポイント獲得',
      _details,
    );
    await prefs.setInt(_notifiedSaleStartKey, ms);
  }

  /// Schedules a reminder every 30 minutes for the next 24 hours when
  /// there are pending review reservations.
  Future<void> setEvaluationReminders({required bool hasEvaluations}) async {
    await init();
    await _cancelRange(_evalReminderIdBase, _evalReminderCount);
    if (!hasEvaluations) return;

    final now = tz.TZDateTime.now(_jst);
    var id = _evalReminderIdBase;
    for (var i = 1; i <= _evalReminderCount; i++) {
      final t = now.add(Duration(minutes: i * _evalReminderIntervalMinutes));
      await _scheduleAt(id++, t, 'レビュー予約あり', 'スケジュールを確認してね');
    }
  }

  Future<void> _scheduleAt(
    int id,
    tz.TZDateTime when,
    String title,
    String body,
  ) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (!kReleaseMode) debugPrint('schedule failed at $when: $e');
    }
  }

  Future<void> _cancelRange(int base, int count) async {
    for (var i = 0; i < count; i++) {
      try {
        await _plugin.cancel(base + i);
      } catch (_) {}
    }
  }
}
