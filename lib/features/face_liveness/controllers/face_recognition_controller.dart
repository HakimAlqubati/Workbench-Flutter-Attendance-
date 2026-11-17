import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/network_service.dart';
import '../services/sync_service.dart';

class FaceRecognitionController extends ChangeNotifier {
  final LivenessNetworkService _net = LivenessNetworkService();

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  Map<String, dynamic>? _result;
  Map<String, dynamic>? get result => _result;

  String? _error;
  String? get error => _error;

  /// تصفير الحالة
  void reset() {
    _isBusy = false;
    _result = null;
    _error = null;
    notifyListeners();
  }

  Future<void> recognizeByPath(String imagePath) async {
    if (_isBusy) return;
    _isBusy = true;
    _error = null;
    _result = null;
    notifyListeners();

    try {
      // فحص حالة الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOffline = false;
      if (connectivityResult is List) {
        isOffline = connectivityResult.contains(ConnectivityResult.none);
      } else {
        isOffline = connectivityResult == ConnectivityResult.none;
      }

      if (isOffline) {
        // لا يوجد إنترنت، تخزين محلي
        await SyncService.instance.enqueueRequest(imagePath);
        _result = {
          'isOffline': true,
          'message': 'تم حفظ العملية بنجاح وسيتم رفعها تلقائياً عند توفر الإنترنت',
        };
      } else {
        // إرسال مباشر
        final json = await _net.sendFaceRecognition(imagePath);
        _result = json ?? {'error': 'Invalid response'};
      }
    } catch (e) {
      _error = 'Recognition error: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// تمرير XFile (اختياري للراحة)
  Future<void> recognizeFile(XFile file) => recognizeByPath(file.path);
}
