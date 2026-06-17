import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'features/settings/settings_store.dart';
import 'package:my_app/features/face_liveness/services/sync_service.dart';
import 'package:my_app/core/config/base_url_store.dart';
import 'package:my_app/features/face_liveness/constants.dart';
import 'package:my_app/core/network_helper.dart';
import 'package:my_app/core/database/sync_database.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final url = await BaseUrlStore.get();
      if (url != null) {
         kApiBaseUrl = url;
      }
      await SettingsStore.I.init();
      await SyncService.instance.syncPendingRequests();
      return Future.value(true);
    } catch (e) {
      debugPrint('Background sync error: $e');
      return Future.value(false);
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false, 
  );
  Workmanager().registerPeriodicTask(
    "offlineSyncTask",
    "offlineSyncTask",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await WakelockPlus.enable();
  await SettingsStore.I.init();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Clean up failed sync logs older than 7 days and initialize badge count
  await SyncDatabase.instance.deleteOldFailedLogs(7);
  await SyncDatabase.instance.updateFailedLogsCount();

  // Trigger sync on startup if base URL is available
  final url = await BaseUrlStore.get();
  if (url != null) {
      kApiBaseUrl = url;
      SyncService.instance.syncPendingRequests();
  }

  // Listen to connectivity changes to trigger real-time sync when online
  NetworkHelper.listenToConnection((isConnected) {
    if (isConnected) {
      debugPrint('📶 Connectivity changed to online. Triggering real-time sync...');
      SyncService.instance.syncPendingRequests();
    }
  });

  runApp(const MyApp());
}
