import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  static const _saleReminderIdBase = 10000;
  static const _evalReminderIdBase = 20000;
  static const _saleReminderHours = [9, 12, 15, 18];
  static const _saleReminderDaysAhead = 7;
  static const _evalReminderHoursAhead = 24;

  /// JST is the only schedule timezone we care about — the app is
  /// Japan-centric and we want reminders to fire at "9 AM Tokyo"
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

  /// Reschedule sale reminders.
  ///
  /// [ongoing] true → cancel previous reminders and book a new set at
  /// 9/12/15/18 JST for the next [_saleReminderDaysAhead] days.
  /// [ongoing] false → just cancel all booked sale reminders.
  Future<void> setOngoingSaleReminders({required bool ongoing}) async {
    await init();
    await _cancelRange(
      _saleReminderIdBase,
      _saleReminderDaysAhead * _saleReminderHours.length,
    );
    if (!ongoing) return;

    final now = tz.TZDateTime.now(_jst);
    var id = _saleReminderIdBase;
    for (var d = 0; d < _saleReminderDaysAhead; d++) {
      for (final h in _saleReminderHours) {
        final t = tz.TZDateTime(_jst, now.year, now.month, now.day, h)
            .add(Duration(days: d));
        if (!t.isAfter(now)) continue;
        await _scheduleAt(
          id++,
          t,
          'えばぽせーる開催中',
          'まだ間に合う！レビューしてポイント獲得',
        );
      }
    }
  }

  /// Reschedule evaluation reminders (hourly for the next 24h).
  Future<void> setEvaluationReminders({required bool hasEvaluations}) async {
    await init();
    await _cancelRange(_evalReminderIdBase, _evalReminderHoursAhead);
    if (!hasEvaluations) return;

    final now = tz.TZDateTime.now(_jst);
    var id = _evalReminderIdBase;
    for (var h = 1; h <= _evalReminderHoursAhead; h++) {
      final t = now.add(Duration(hours: h));
      await _scheduleAt(
        id++,
        t,
        'レビュー予約あり',
        'スケジュールを確認してね',
      );
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
