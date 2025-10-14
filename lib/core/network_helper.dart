import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:my_app/core/toast_utils.dart';

class NetworkHelper {
  // Singleton pattern
  static final NetworkHelper _instance = NetworkHelper._internal();
  factory NetworkHelper() => _instance;
  NetworkHelper._internal();

  /// فحص صامت للاتصال (بدون رسائل)
  static Future<bool> isConnected() async {
    final List<ConnectivityResult> results =
    await Connectivity().checkConnectivity();

    return results.any((result) =>
    result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn);
  }

  /// فحص مع عرض رسالة عند الانقطاع
  static Future<bool> checkAndToastConnection({
    String message = 'Check Your Internet Connection',
  }) async {
    final connected = await isConnected();

    if (!connected) {
      showCustomToast(
        message: message,
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
      );
    }

    return connected;
  }

  /// الاستماع لتغيّرات الاتصال
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  static void listenToConnection(Function(bool isConnected) onChanged) {
    _subscription ??= Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final connected = results.any((result) =>
      result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn);
      onChanged(connected);
    });
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
