import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/sale/domain/sale.dart';
import '../../features/sale/domain/sale_predictor.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'sale_tracker_channel';
  static const _channelName = 'えばぽ君.exe';
  static const _channelDesc = 'えばぽせーる 開始 / 終了 / 次回予測の通知';

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    final android =
        _plugin.resolvePlatformSpecificImplementation<
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

  String _fmt(DateTime dt) =>
      DateFormat('MM/dd HH:mm', 'ja').format(dt.toLocal());

  Future<void> notifySaleStarted(Sale sale) async {
    await init();
    await _plugin.show(
      _idFor('start', sale.id),
      'えばぽせーる が開始しました',
      '${_fmt(sale.startAt)} ・ ${sale.title}',
      _details,
    );
  }

  Future<void> notifySaleEnded(Sale sale) async {
    await init();
    final end = sale.endAt;
    if (end == null) return;
    await _plugin.show(
      _idFor('end', sale.id),
      'えばぽせーる が終了しました',
      '${_fmt(end)} ・ ${sale.title}',
      _details,
    );
  }

  Future<void> notifyPredictedSale(PredictionResult prediction) async {
    await init();
    final hours = prediction.uncertainty.inHours;
    final note = hours > 0 ? ' (±${hours}h)' : '';
    await _plugin.show(
      _idFor('predict', 0),
      '次回えばぽせーる の予測',
      '${_fmt(prediction.expectedStart)} 頃$note',
      _details,
    );
  }

  int _idFor(String kind, int id) {
    // Stable IDs prevent duplicate notifications across retries.
    final h = '$kind:$id'.hashCode;
    return h.abs() & 0x7fffffff;
  }
}

// Background isolates can't read providers; expose a top-level helper too.
Future<void> initNotifications() async {
  if (kReleaseMode) {
    // keep secure storage / creds out of logs
  }
}
