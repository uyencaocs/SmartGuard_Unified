import '../core/api_client.dart';
import '../models/models.dart';

class AdaptiveSecurityService {
  /// Lấy danh sách hồ sơ chế độ thích ứng của người dùng (Home, Away, Night)
  static Future<List<AdaptiveProfileModel>> getProfiles() async {
    final res = await ApiClient.request('GET', '/api/adaptivesecurity/profiles');
    if (res is List) {
      return res.map((p) => AdaptiveProfileModel.fromJson(p as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Kích hoạt một chế độ an ninh (POST /api/adaptivesecurity/profiles/{id}/activate)
  static Future<Map<String, dynamic>> activateProfile(String profileId) async {
    final res = await ApiClient.request('POST', '/api/adaptivesecurity/profiles/$profileId/activate');
    return res as Map<String, dynamic>;
  }

  /// Tạm dừng cảnh báo an ninh trong X phút (POST /api/adaptivesecurity/snooze)
  static Future<Map<String, dynamic>> snooze(int minutes) async {
    final res = await ApiClient.request('POST', '/api/adaptivesecurity/snooze', body: {
      'minutes': minutes,
    });
    return res as Map<String, dynamic>;
  }

  /// Hủy bỏ tạm dừng, quay lại canh gác an ninh tức thì (POST /api/adaptivesecurity/cancel-snooze)
  static Future<Map<String, dynamic>> cancelSnooze() async {
    final res = await ApiClient.request('POST', '/api/adaptivesecurity/cancel-snooze');
    return res as Map<String, dynamic>;
  }

  /// Cập nhật quy tắc phân vùng & lịch biểu (PUT /api/adaptivesecurity/profiles/{id})
  static Future<void> updateProfile(String profileId, Map<String, dynamic> data) async {
    await ApiClient.request('PUT', '/api/adaptivesecurity/profiles/$profileId', body: data);
  }
}
