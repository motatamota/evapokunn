import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'background/background_worker.dart';
import 'core/notifications/notification_service.dart';
import 'core/settings/app_settings.dart';

Future<void> main() async {
  // Anything that throws here would otherwise leave iOS on a blank
  // launch screen — wrap so we always render *something*.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('ja', null);
    final prefs = await SharedPreferences.getInstance();

    // Notification channel + permission. Best-effort; not fatal.
    try {
      await NotificationService().init();
    } catch (e, st) {
      debugPrint('NotificationService init failed: $e\n$st');
    }

    // Background scheduler. Only used on Android; iOS's BGTaskScheduler
    // requires entitlements that AltStore-signed builds don't get, and
    // the registration call has been observed to crash on launch.
    if (Platform.isAndroid) {
      try {
        await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
        await Workmanager().registerPeriodicTask(
          saleCheckUniqueName,
          saleCheckTask,
          frequency: const Duration(hours: 2),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingWorkPolicy.keep,
        );
      } catch (e, st) {
        debugPrint('Workmanager init failed: $e\n$st');
      }
    }

    runApp(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const App(),
    ));
  } catch (e, st) {
    runApp(_FatalErrorApp(error: e, stack: st));
  }
}

class _FatalErrorApp extends StatelessWidget {
  const _FatalErrorApp({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('起動エラー')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'アプリ起動に失敗しました。以下をスクリーンショットして報告してください。',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SelectableText('$error'),
              const SizedBox(height: 12),
              SelectableText(
                '$stack',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
