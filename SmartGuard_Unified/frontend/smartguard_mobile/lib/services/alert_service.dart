import '../core/api_client.dart';
import '../models/models.dart';

class AlertService {
  /// Lấy toàn bộ lịch sử cảnh báo an ninh (GET /api/alerts/history?limit=50)
  static Future<List<AlertModel>> getAlertHistory({int limit = 50}) async {
    final res = await ApiClient.request('GET', '/api/alerts/history', queryParams: {
      'limit': limit.toString(),
    });

    if (res is List) {
      return res.map((item) => AlertModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Phát động kích hoạt cảnh báo an ninh từ Camera / Client AI (POST /api/alerts/trigger)
  static Future<Map<String, dynamic>> triggerAlert({
    required String deviceId,
    required String triggerReason,
    double triggerScore = 1.0,
    String severity = 'High',
    String? imageUrl,
  }) async {
    final res = await ApiClient.request('POST', '/api/alerts/trigger', body: {
      'deviceId': deviceId,
      'triggerReason': triggerReason,
      'triggerScore': triggerScore,
      'severity': severity,
      'imageUrl': imageUrl,
    });
    return res as Map<String, dynamic>;
  }

  /// Kiểm tra trạng thái an ninh & cảnh báo thời gian thực của thiết bị (GET /api/alerts/device/{id}/status)
  static Future<Map<String, dynamic>> getDeviceAlertStatus(String deviceId) async {
    final res = await ApiClient.request('GET', '/api/alerts/device/$deviceId/status');
    return res as Map<String, dynamic>;
  }

  /// Thực thi hành động xử lý cảnh báo khẩn cấp (POST /api/alerts/{id}/action)
  /// Actions: "known" (Người quen), "stranger" (Người lạ), "mute" (Tắt chuông), "dismiss" (Bỏ qua)
  static Future<Map<String, dynamic>> acknowledgeAlert(
    String alertId, {
    required String action,
  }) async {
    final res = await ApiClient.request('POST', '/api/alerts/$alertId/action', body: {
      'action': action,
    });
    return res as Map<String, dynamic>;
  }
}
