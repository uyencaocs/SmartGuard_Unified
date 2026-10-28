import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('vi-VN');
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      _initialized = true;
    } catch (_) {}
  }

  static Future<void> speak(String text) async {
    await init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  static Future<void> playWarningVoice(String reason) async {
    final String msg;
    if (reason == 'NGUOI_LA') {
      msg = 'Cảnh báo! Phát hiện người lạ xâm nhập khu vực an ninh. Hệ thống đang ghi hình và báo động!';
    } else if (reason == 'NGUOI_QUEN') {
      msg = 'Đã nhận diện khuôn mặt người quen. Hệ thống đã tắt còi báo động và tạm dừng cảnh báo.';
    } else {
      msg = 'Cảnh báo! Phát hiện rung lắc hoặc di chuyển thiết bị trái phép!';
    }
    await speak(msg);
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
