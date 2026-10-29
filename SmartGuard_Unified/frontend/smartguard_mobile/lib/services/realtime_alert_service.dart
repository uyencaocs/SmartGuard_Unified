import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import '../models/models.dart';
import 'alert_service.dart';
import 'tts_service.dart';

class RealtimeAlertService {
  static final RealtimeAlertService _instance = RealtimeAlertService._internal();
  factory RealtimeAlertService() => _instance;
  RealtimeAlertService._internal();

  Timer? _pollingTimer;
  String? _lastNotifiedAlertId;
  bool _isPolling = false;

  final StreamController<AlertModel> _alertStreamController = StreamController<AlertModel>.broadcast();
  Stream<AlertModel> get onNewAlert => _alertStreamController.stream;

  /// Khởi động dịch vụ lắng nghe cảnh báo thời gian thực (Polling mỗi 4 giây)
  void startMonitoring({Duration interval = const Duration(seconds: 4)}) {
    if (_isPolling) return;
    _isPolling = true;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => _checkForNewAlerts());
    // Kiểm tra ngay lập tức lần đầu
    _checkForNewAlerts();
  }

  /// Tạm dừng dịch vụ lắng nghe
  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
  }

  Future<void> _checkForNewAlerts() async {
    try {
      final alerts = await AlertService.getAlertHistory(limit: 5);
      if (alerts.isEmpty) return;

      final latestAlert = alerts.first;

      // Chỉ thông báo nếu đây là sự kiện mới và trạng thái đang là Triggered
      if (_lastNotifiedAlertId == null) {
        // Lần đầu chạy chỉ lưu lại ID mới nhất để tránh spam các cảnh báo cũ
        _lastNotifiedAlertId = latestAlert.id;
        return;
      }

      if (latestAlert.id != _lastNotifiedAlertId && latestAlert.status.toLowerCase() == 'triggered') {
        _lastNotifiedAlertId = latestAlert.id;

        // Phát ra Stream để giao diện hiển thị Popup / Banner
        _alertStreamController.add(latestAlert);

        // Kích hoạt rung Haptic khẩn cấp
        _triggerHapticAlert();

        // Kích hoạt giọng nói cảnh báo tiếng Việt
        _triggerVoiceAlert(latestAlert);
      }
    } catch (e) {
      debugPrint('RealtimeAlertService poll error: $e');
    }
  }

  Future<void> _triggerHapticAlert() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Mẫu rung SOS khẩn cấp: Rung 500ms, nghỉ 200ms, rung 500ms
        Vibration.vibrate(pattern: [0, 500, 200, 500]);
      }
    } catch (_) {}
  }

  Future<void> _triggerVoiceAlert(AlertModel alert) async {
    try {
      final reason = alert.triggerReason.toUpperCase();
      if (reason.contains('STRANGER') || reason.contains('FACE')) {
        await TtsService.playWarningVoice('NGUOI_LA');
      } else if (reason.contains('KNOWN')) {
        await TtsService.playWarningVoice('NGUOI_QUEN');
      } else {
        await TtsService.playWarningVoice('CHUYEN_DONG');
      }
    } catch (_) {}
  }

  void dispose() {
    stopMonitoring();
    _alertStreamController.close();
  }
}
