import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../core/session_manager.dart';
import '../../models/models.dart';
import '../camera/camera_guard_screen.dart';
import '../alerts/alerts_history_screen.dart';
import '../zones/zones_screen.dart';
import '../members/members_screen.dart';
import '../admin/admin_screen.dart';
import '../adaptive/adaptive_security_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  bool _serverOnline = false;
  List<DeviceModel> _devices = [];
  int _alertCountToday = 0;

  void reloadDashboard() {
    _loadDashboardData();
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final isOnline = await ApiClient.testConnection();

    if (!isOnline) {
      if (mounted) {
        setState(() {
          _serverOnline = false;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final devicesRes =
          await ApiClient.request('GET', '/api/devices') as List<dynamic>;
      final alertsRes =
          await ApiClient.request('GET', '/api/alerts/history?limit=10')
              as List<dynamic>;

      if (mounted) {
        setState(() {
          _serverOnline = true;
          _devices = devicesRes
              .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _alertCountToday = alertsRes.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverOnline = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final armedCount = _devices.where((d) => d.isArmed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng điều khiển SmartGuard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Quản trị hệ thống (Admin)',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AdminScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Server Status Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _serverOnline
                            ? AppTheme.statusArmed.withValues(alpha: 0.12)
                            : AppTheme.statusAlarm.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _serverOnline
                              ? AppTheme.statusArmed
                              : AppTheme.statusAlarm,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _serverOnline ? Icons.cloud_done : Icons.cloud_off,
                            color: _serverOnline
                                ? AppTheme.statusArmed
                                : AppTheme.statusAlarm,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _serverOnline
                                      ? 'Hệ thống Backend: Hoạt động'
                                      : 'Không kết nối được Máy chủ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _serverOnline
                                        ? AppTheme.statusArmed
                                        : AppTheme.statusAlarm,
                                  ),
                                ),
                                Text(
                                  AppConfig.baseUrl,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Greeting
                    Text(
                      'Xin chào, ${SessionManager.username}!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vai trò: ${SessionManager.isAdmin ? "Quản trị viên (Admin)" : "Chủ sở hữu (Owner)"}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Status Metric Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Thiết bị canh gác',
                            value: '$armedCount/${_devices.length}',
                            icon: Icons.shield,
                            color: AppTheme.statusArmed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Sự kiện gần đây',
                            value: '$_alertCountToday',
                            icon: Icons.warning_amber_rounded,
                            color: AppTheme.statusWarning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Hero Live Camera Guard Action
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryBlue, Color(0xFF1E40AF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Camera AI Giám Sát',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Bật chế độ quan sát trực tiếp, nhận diện khuôn mặt và cảm biến rung lắc chống trộm.',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CameraGuardScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: AppTheme.primaryBlue,
                            ),
                            label: const Text(
                              'Bật Giám Sát Ngay',
                              style: TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Functional Grid Navigation
                    const Text(
                      'Quản lý hệ thống',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _buildNavCard(
                          title: 'Chế độ Thích ứng',
                          subtitle: 'Ở nhà • Rời nhà • Đêm',
                          icon: Icons.tune_rounded,
                          color: const Color(0xFF10B981),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdaptiveSecurityScreen(),
                              ),
                            );
                          },
                        ),
                        _buildNavCard(
                          title: 'Lịch sử cảnh báo',
                          subtitle: 'Xem ảnh bằng chứng',
                          icon: Icons.history,
                          color: AppTheme.accentCyan,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AlertsHistoryScreen(),
                              ),
                            );
                          },
                        ),
                        _buildNavCard(
                          title: 'Khu vực & Thiết bị',
                          subtitle: 'Quản lý phân vùng',
                          icon: Icons.meeting_room_outlined,
                          color: const Color(0xFF8B5CF6),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ZonesScreen(),
                              ),
                            );
                          },
                        ),
                        _buildNavCard(
                          title: 'Chia sẻ thiết bị',
                          subtitle: 'Thành viên gia đình',
                          icon: Icons.group_outlined,
                          color: const Color(0xFFEC4899),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MembersScreen(),
                              ),
                            );
                          },
                        ),
                        _buildNavCard(
                          title: 'Quản trị hệ thống',
                          subtitle: SessionManager.isAdmin
                              ? 'Admin Dashboard'
                              : 'Quản lý tài khoản & ảnh',
                          icon: Icons.admin_panel_settings_outlined,
                          color: const Color(0xFF7C3AED),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
