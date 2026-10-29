import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String defaultLanUrl =
      'https://lfqpdt8w-44321.asse.devtunnels.ms';
  static const String emulatorUrl = 'http://10.0.2.2:5235';
  static const String localhostUrl = 'http://localhost:5235';

  static String _activeBaseUrl = defaultLanUrl;
  static const String _prefKeyBaseUrl = 'smartguard_base_url';

  static String get baseUrl => _activeBaseUrl;

  static const double faceMatchThreshold = 0.80;
  static const double defaultMotionThreshold = 3.5;
  static const double defaultNoiseThreshold = 70.0;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKeyBaseUrl);
      if (saved != null && saved.trim().isNotEmpty && !saved.contains('192.168.2.6')) {
        _activeBaseUrl = saved.trim();
      } else {
        _activeBaseUrl = defaultLanUrl;
        await prefs.setString(_prefKeyBaseUrl, defaultLanUrl);
      }
    } catch (_) {}
  }

  static Future<void> setBaseUrl(String url) async {
    var trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    _activeBaseUrl = trimmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyBaseUrl, trimmed);
    } catch (_) {}
  }

  static Future<bool> pingServer([String? testUrl]) async {
    try {
      final url = testUrl ?? _activeBaseUrl;
      final uri = Uri.parse(url).resolve('api/devices');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      return res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
