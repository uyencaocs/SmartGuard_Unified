import '../core/api_client.dart';

class ZoneModel {
  final String id;
  final String name;
  final String description;
  final int deviceCount;

  ZoneModel({
    required this.id,
    required this.name,
    required this.description,
    required this.deviceCount,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> j) => ZoneModel(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        deviceCount: (j['deviceCount'] as num?)?.toInt() ?? 0,
      );
}

class ZoneService {
  static Future<List<ZoneModel>> getZones() async {
    final res = await ApiClient.request('GET', '/api/zones');
    if (res is List) return res.map((e) => ZoneModel.fromJson(e as Map<String, dynamic>)).toList();
    return [];
  }

  static Future<ZoneModel?> createZone({required String name, String description = ''}) async {
    final res = await ApiClient.request('POST', '/api/zones', body: {
      'name': name,
      'description': description,
    });
    if (res is Map<String, dynamic>) return ZoneModel.fromJson(res);
    return null;
  }

  static Future<bool> updateZone(String id, {required String name, String description = ''}) async {
    await ApiClient.request('PUT', '/api/zones/$id', body: {
      'name': name,
      'description': description,
    });
    return true;
  }

  static Future<bool> deleteZone(String id) async {
    await ApiClient.request('DELETE', '/api/zones/$id');
    return true;
  }
}
