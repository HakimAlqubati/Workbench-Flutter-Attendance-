import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

import '../services/network_service.dart';

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

  /// تمرير مسار الصورة مباشرة
  Future<void> recognizeByPath(String imagePath) async {
    if (_isBusy) return;
    _isBusy = true;
    _error = null;
    _result = null;
    notifyListeners();

    try {
      final json = await _net.sendFaceRecognition(imagePath);
      _result = json ?? {'error': 'Invalid response'};
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
