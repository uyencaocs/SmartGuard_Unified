import '../core/api_client.dart';

class AdminStatsModel {
  final int totalUsers;
  final int totalDevices;
  final int totalAlertsToday;
  final int activeArmedDevices;

  AdminStatsModel({
    required this.totalUsers,
    required this.totalDevices,
    required this.totalAlertsToday,
    required this.activeArmedDevices,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> j) => AdminStatsModel(
        totalUsers: (j['totalUsers'] as num?)?.toInt() ?? 0,
        totalDevices: (j['totalDevices'] as num?)?.toInt() ?? 0,
        totalAlertsToday: (j['totalAlertsToday'] as num?)?.toInt() ?? 0,
        activeArmedDevices: (j['activeArmedDevices'] as num?)?.toInt() ?? 0,
      );
}

class AdminUserModel {
  final String id;
  final String email;
  final String username;
  final String role;
  final bool isLocked;
  final String createdAt;

  AdminUserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
    required this.isLocked,
    required this.createdAt,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> j) => AdminUserModel(
        id: j['id']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        username: j['username']?.toString() ?? '',
        role: j['role']?.toString() ?? 'Owner',
        isLocked: (j['isLocked'] as bool?) ?? false,
        createdAt: j['createdAt']?.toString() ?? '',
      );
}

class AdminSystemInfo {
  final String serverTime;
  final String osVersion;
  final String machineName;
  final String dotnetVersion;
  final double workingSetMemoryMb;
  final int threads;
  final double uptimeSeconds;

  AdminSystemInfo({
    required this.serverTime,
    required this.osVersion,
    required this.machineName,
    required this.dotnetVersion,
    required this.workingSetMemoryMb,
    required this.threads,
    required this.uptimeSeconds,
  });

  factory AdminSystemInfo.fromJson(Map<String, dynamic> j) => AdminSystemInfo(
        serverTime: j['serverTime']?.toString() ?? '',
        osVersion: j['osVersion']?.toString() ?? '',
        machineName: j['machineName']?.toString() ?? '',
        dotnetVersion: j['dotnetVersion']?.toString() ?? '',
        workingSetMemoryMb: (j['workingSetMemoryMb'] as num?)?.toDouble() ?? 0,
        threads: (j['threads'] as num?)?.toInt() ?? 0,
        uptimeSeconds: (j['uptimeSeconds'] as num?)?.toDouble() ?? 0,
      );

  String get uptimeFormatted {
    final d = Duration(seconds: uptimeSeconds.toInt());
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class AdminService {
  static Future<AdminStatsModel?> getStats() async {
    final res = await ApiClient.request('GET', '/api/admin/stats');
    if (res is Map<String, dynamic>) return AdminStatsModel.fromJson(res);
    return null;
  }

  static Future<List<AdminUserModel>> getUsers() async {
    final res = await ApiClient.request('GET', '/api/admin/users');
    if (res is List) return res.map((e) => AdminUserModel.fromJson(e as Map<String, dynamic>)).toList();
    return [];
  }

  static Future<bool> updateUserStatus(String id, {bool? isLocked, String? role}) async {
    final body = <String, dynamic>{};
    if (isLocked != null) body['isLocked'] = isLocked;
    if (role != null) body['role'] = role;
    await ApiClient.request('PATCH', '/api/admin/users/$id/status', body: body);
    return true;
  }

  static Future<bool> deleteUser(String id) async {
    await ApiClient.request('DELETE', '/api/admin/users/$id');
    return true;
  }

  static Future<AdminSystemInfo?> getSystemInfo() async {
    final res = await ApiClient.request('GET', '/api/admin/system');
    if (res is Map<String, dynamic>) return AdminSystemInfo.fromJson(res);
    return null;
  }
}
