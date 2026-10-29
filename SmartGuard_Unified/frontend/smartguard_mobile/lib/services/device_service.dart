import '../core/api_client.dart';
import '../models/models.dart';

class DeviceService {
  /// Lấy danh sách tất cả thiết bị (sở hữu & được chia sẻ)
  static Future<List<DeviceModel>> getDevices() async {
    final res = await ApiClient.request('GET', '/api/devices');
    if (res is List) {
      return res.map((item) => DeviceModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Lấy chi tiết một thiết bị theo ID
  static Future<DeviceModel?> getDevice(String id) async {
    try {
      final res = await ApiClient.request('GET', '/api/devices/$id');
      if (res is Map<String, dynamic>) {
        return DeviceModel.fromJson(res);
      }
    } catch (_) {}
    return null;
  }

  /// Chuyển đổi trạng thái Bật / Tắt canh gác an ninh (PATCH /api/devices/{id}/toggle-arm)
  static Future<Map<String, dynamic>> toggleArm(String deviceId) async {
    final res = await ApiClient.request('PATCH', '/api/devices/$deviceId/toggle-arm');
    return res as Map<String, dynamic>;
  }

  /// Ghép nối thiết bị mới bằng mã code phần cứng (POST /api/devices/pair)
  static Future<Map<String, dynamic>> pairDevice(String deviceCode) async {
    final res = await ApiClient.request(
      'POST',
      '/api/devices/pair',
      body: deviceCode.trim().toUpperCase(),
    );
    return res as Map<String, dynamic>;
  }

  /// Đăng ký thêm thiết bị thủ công (POST /api/devices)
  static Future<DeviceModel> createDevice({
    required String name,
    String description = '',
    String? zoneId,
    double noiseThreshold = 70.0,
    double motionThreshold = 3.5,
  }) async {
    final res = await ApiClient.request('POST', '/api/devices', body: {
      'name': name.trim(),
      'description': description.trim(),
      'zoneId': zoneId,
      'noiseThreshold': noiseThreshold,
      'motionThreshold': motionThreshold,
    }) as Map<String, dynamic>;

    return DeviceModel.fromJson(res);
  }

  /// Cập nhật thông số ngưỡng cảm biến rung / âm thanh (PUT /api/devices/{id})
  static Future<void> updateDevice(
    String deviceId, {
    String? name,
    String? description,
    String? zoneId,
    bool? isArmed,
    double? noiseThreshold,
    double? motionThreshold,
  }) async {
    await ApiClient.request('PUT', '/api/devices/$deviceId', body: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (zoneId != null) 'zoneId': zoneId,
      if (isArmed != null) 'isArmed': isArmed,
      if (noiseThreshold != null) 'noiseThreshold': noiseThreshold,
      if (motionThreshold != null) 'motionThreshold': motionThreshold,
    });
  }

  /// Xóa thiết bị khỏi hệ thống (DELETE /api/devices/{id})
  static Future<void> deleteDevice(String deviceId) async {
    await ApiClient.request('DELETE', '/api/devices/$deviceId');
  }
}
