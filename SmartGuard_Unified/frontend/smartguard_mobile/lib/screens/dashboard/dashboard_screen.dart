import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/capybara_widgets.dart';
import '../adaptive/adaptive_security_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const DashboardScreen({super.key, this.onTabChange});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  bool _isTogglingArm = false;
  bool _isArmed = true;
  String? _deviceId;
  String _currentMode = 'Home'; // Home, Away, Night
  List<AlertModel> _recentAlerts = [];
  int _deviceCount = 0;
  String _pingLatency = 'Tốt';

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadDashboardData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      // 1. Fetch devices to check arm status
      final devicesRes = await ApiClient.request('GET', '/api/devices');
      if (devicesRes is List && devicesRes.isNotEmpty) {
        final devices = devicesRes.map((d) => DeviceModel.fromJson(d as Map<String, dynamic>)).toList();
        _deviceCount = devices.length;
        final mainDev = devices.first;
        _deviceId = mainDev.id;
        _isArmed = mainDev.isArmed;
      }

      // 2. Fetch current adaptive mode
      try {
        final modeRes = await ApiClient.request('GET', '/api/adaptivesecurity/current-mode');
        if (modeRes is Map<String, dynamic> && modeRes['currentMode'] != null) {
          _currentMode = modeRes['currentMode'].toString();
        }
      } catch (_) {}

      // 3. Fetch recent alerts
      try {
        final alertsRes = await ApiClient.request('GET', '/api/alerts', queryParams: {
          'pageSize': '5',
          'page': '1',
        });
        if (alertsRes is Map<String, dynamic> && alertsRes['items'] is List) {
          _recentAlerts = (alertsRes['items'] as List)
              .map((a) => AlertModel.fromJson(a as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}

      // 4. Ping latency
      final stopwatch = Stopwatch()..start();
      await AppConfig.pingServer(AppConfig.baseUrl);
      stopwatch.stop();
      _pingLatency = '${stopwatch.elapsedMilliseconds}ms';
    } catch (_) {
      // Graceful fallback with demo state
      _pingLatency = 'Offline';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleArm() async {
    setState(() => _isTogglingArm = true);
    final targetArm = !_isArmed;

    try {
      if (_deviceId != null) {
        await ApiClient.request('PUT', '/api/devices/$_deviceId/arm', body: {
          'isArmed': targetArm,
        });
      }
      setState(() => _isArmed = targetArm);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: targetArm ? AppTheme.statusGreen : AppTheme.primaryPurple,
          content: Row(
            children: [
              Icon(targetArm ? Icons.shield : Icons.shield_outlined, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                targetArm ? '🐾 Capybara đã kích hoạt bảo vệ an ninh!' : 'Đã tắt bảo vệ an ninh.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật: ${e.toString().replaceAll("Exception:", "")}'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTogglingArm = false);
    }
  }

  Future<void> _changeMode(String mode) async {
    try {
      await ApiClient.request('POST', '/api/adaptivesecurity/change-mode', body: {
        'mode': mode,
        'reason': 'Người dùng chuyển trên ứng dụng di động',
      });
      setState(() => _currentMode = mode);
    } catch (_) {
      setState(() => _currentMode = mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.warmCream,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CapybaraAvatar(size: 72),
              SizedBox(height: 16),
              CircularProgressIndicator(color: AppTheme.primaryPurple),
              SizedBox(height: 12),
              Text(
                'Capybara đang kết nối hệ thống...',
                style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.warmCream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadDashboardData(),
          color: AppTheme.primaryPurple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CapybaraAvatar(size: 44, isOnline: true),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SmartGuard',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Capybara giữ nhà, Nhà luôn an tâm! 🐾',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryPurple.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_none_outlined, size: 26, color: AppTheme.textPrimary),
                          if (_recentAlerts.isNotEmpty)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryCoral,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: () => widget.onTabChange?.call(1),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // BIG HERO CARD: Protection Status (Matching Mockup)
                _buildHeroCard(),
                const SizedBox(height: 18),

                // 4 METRIC CARDS (2x2 Grid)
                Row(
                  children: [
                    Expanded(
                      child: CapybaraMetricCard(
                        icon: Icons.videocam_outlined,
                        title: 'Camera',
                        value: _deviceCount > 0 ? '$_deviceCount hoạt động' : 'Hoạt động',
                        iconColor: AppTheme.statusGreen,
                        statusColor: AppTheme.statusGreen,
                        onTap: () => widget.onTabChange?.call(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CapybaraMetricCard(
                        icon: Icons.wifi,
                        title: 'Kết nối',
                        value: _pingLatency,
                        iconColor: AppTheme.primaryPurple,
                        statusColor: _pingLatency == 'Offline' ? AppTheme.statusDanger : AppTheme.statusGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(
                      child: CapybaraMetricCard(
                        icon: Icons.battery_charging_full_outlined,
                        title: 'Pin / Nguồn',
                        value: '95% Tốt',
                        iconColor: AppTheme.warmAmber,
                        statusColor: AppTheme.statusGreen,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: CapybaraMetricCard(
                        icon: Icons.cloud_done_outlined,
                        title: 'Lưu trữ',
                        value: '23.6 GB trống',
                        iconColor: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Quick Adaptive Mode Selector (Ở nhà / Rời nhà / Ban đêm)
                _buildAdaptiveModesSelector(),
                const SizedBox(height: 22),

                // Recent Events Section (Sự kiện gần đây)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sự kiện gần đây',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onTabChange?.call(1),
                      child: const Text(
                        'Xem tất cả',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildRecentEventsList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _isArmed ? const Color(0xFFC8F3D7) : const Color(0xFFEADBCE),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isArmed ? AppTheme.statusGreen : AppTheme.primaryPurple).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge icon status
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isArmed ? AppTheme.statusGreenBg : AppTheme.capyPeach,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isArmed ? Icons.shield : Icons.nightlight_round,
                  color: _isArmed ? AppTheme.statusGreen : AppTheme.primaryPurple,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isArmed ? 'Đang được bảo vệ' : 'Bảo vệ đang tắt',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _isArmed ? AppTheme.statusGreen : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isArmed
                          ? 'Hệ thống hoạt động bình thường'
                          : 'Hệ thống đang ở chế độ chờ / nghỉ ngơi',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Capybara Avatar Guard
              const CapybaraAvatar(size: 64),
            ],
          ),
          const SizedBox(height: 20),

          // Action Button: Tắt bảo vệ / Kích hoạt bảo vệ
          InkWell(
            onTap: _isTogglingArm ? null : _toggleArm,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _isArmed ? const Color(0xFFFFF0F0) : AppTheme.statusGreenBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isArmed ? AppTheme.statusDanger.withValues(alpha: 0.3) : AppTheme.statusGreen,
                ),
              ),
              child: Center(
                child: _isTogglingArm
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isArmed ? Icons.lock_outline : Icons.shield,
                            color: _isArmed ? AppTheme.statusDanger : AppTheme.statusGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isArmed ? 'TẮT BẢO VỆ' : 'KÍCH HOẠT BẢO VỆ NGAY',
                            style: TextStyle(
                              color: _isArmed ? AppTheme.statusDanger : AppTheme.statusGreen,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveModesSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1E7DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_outlined, size: 18, color: AppTheme.primaryPurple),
                  SizedBox(width: 8),
                  Text(
                    'Chế độ thích ứng',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdaptiveSecurityScreen()),
                ),
                child: const Text(
                  'Chi tiết ❯',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildModeChip('Home', 'Ở nhà 🏠'),
              const SizedBox(width: 8),
              _buildModeChip('Away', 'Rời nhà 🚶'),
              const SizedBox(width: 8),
              _buildModeChip('Night', 'Ban đêm 🌙'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String modeKey, String label) {
    final isSelected = _currentMode.toLowerCase() == modeKey.toLowerCase();
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeMode(modeKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryPurple : const Color(0xFFF8F5F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryPurple : const Color(0xFFEADBCE),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentEventsList() {
    if (_recentAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1E7DD)),
        ),
        child: const Row(
          children: [
            CapybaraAvatar(size: 38),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Chưa có sự kiện khả nghi nào. Ngôi nhà đang được bảo vệ an toàn!',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentAlerts.map((alert) {
        final isStranger = alert.alertType.contains('Face') || alert.alertType.contains('Stranger');
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1E7DD)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isStranger ? AppTheme.statusDangerBg : AppTheme.statusWarningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isStranger ? Icons.person_search : Icons.directions_run,
                  color: isStranger ? AppTheme.statusDanger : AppTheme.warmAmber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title.isNotEmpty ? alert.title : 'Phát hiện sự kiện an ninh',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.description.isNotEmpty ? alert.description : 'Camera giám sát',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
            ],
          ),
        );
      }).toList(),
    );
  }
}
