import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/adaptive_security_service.dart';
import '../../services/alert_service.dart';
import '../../services/device_service.dart';
import '../../widgets/capybara_widgets.dart';
import '../adaptive/adaptive_security_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const DashboardScreen({super.key, this.onTabChange});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isTogglingArm = false;
  bool _isArmed = true;
  String? _deviceId;
  String _currentMode = 'Home';
  List<AdaptiveProfileModel> _profiles = [];
  List<AlertModel> _recentAlerts = [];
  int _deviceCount = 0;
  String _pingLatency = 'Tốt';

  Timer? _refreshTimer;

  // Hold-to-disarm animation variables
  late AnimationController _holdController;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _executeToggleArm();
        _holdController.reset();
      }
    });

    _loadDashboardData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) => _loadDashboardData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _holdController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      // 1. Lấy danh sách thiết bị từ Backend (GET /api/devices)
      final devices = await DeviceService.getDevices();
      _deviceCount = devices.length;
      if (devices.isNotEmpty) {
        final mainDev = devices.first;
        _deviceId = mainDev.id;
        _isArmed = mainDev.isArmed;
      }

      // 2. Lấy hồ sơ chế độ thích ứng từ Backend (GET /api/adaptivesecurity/profiles)
      try {
        _profiles = await AdaptiveSecurityService.getProfiles();
        final active = _profiles.firstWhere((p) => p.isActive, orElse: () => _profiles.first);
        _currentMode = active.modeName;
      } catch (_) {}

      // 3. Lấy các sự kiện cảnh báo mới nhất (GET /api/alerts/history?limit=5)
      try {
        _recentAlerts = await AlertService.getAlertHistory(limit: 5);
      } catch (_) {}

      // 4. Đo độ trễ kết nối (Latency ping)
      final stopwatch = Stopwatch()..start();
      final pingOk = await AppConfig.pingServer(AppConfig.baseUrl);
      stopwatch.stop();
      _pingLatency = pingOk ? '${stopwatch.elapsedMilliseconds}ms' : 'Offline';
    } catch (_) {
      _pingLatency = 'Offline';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeToggleArm() async {
    if (_deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có thiết bị nào được ghép nối để bật/tắt an ninh.'),
          backgroundColor: AppTheme.warmAmber,
        ),
      );
      return;
    }

    setState(() => _isTogglingArm = true);

    try {
      // Gọi endpoint PATCH /api/devices/{id}/toggle-arm
      final res = await DeviceService.toggleArm(_deviceId!);
      final newArmed = res['isArmed'] == true;

      setState(() => _isArmed = newArmed);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: newArmed ? AppTheme.statusGreen : AppTheme.primaryPurple,
          content: Row(
            children: [
              Icon(newArmed ? Icons.shield : Icons.nightlight_round, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  newArmed
                      ? '🐾 Capybara đã kích hoạt toàn diện chế độ bảo vệ!'
                      : 'Đã tắt bảo vệ. Hệ thống chuyển sang chế độ chờ.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceAll("Exception:", "")}'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTogglingArm = false);
    }
  }

  Future<void> _changeMode(String modeKey) async {
    try {
      final targetProfile = _profiles.firstWhere(
        (p) => p.modeName.toLowerCase() == modeKey.toLowerCase(),
        orElse: () => _profiles.first,
      );

      // Kích hoạt qua API POST /api/adaptivesecurity/profiles/{id}/activate
      await AdaptiveSecurityService.activateProfile(targetProfile.id);
      setState(() => _currentMode = modeKey);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.primaryPurple,
          content: Text('🐾 Đã chuyển sang chế độ [${targetProfile.displayName}]'),
        ),
      );
    } catch (_) {
      setState(() => _currentMode = modeKey);
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
                'Capybara đang đồng bộ API hệ thống...',
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
                // Top Header
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
                          if (_recentAlerts.any((a) => a.status.toLowerCase() == 'triggered'))
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: AppTheme.statusDanger,
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

                // Hero Card: Bật/Tắt bảo vệ (PATCH /api/devices/{id}/toggle-arm)
                _buildHeroCard(),
                const SizedBox(height: 18),

                // 4 Metric Cards (Lưới 2x2)
                Row(
                  children: [
                    Expanded(
                      child: CapybaraMetricCard(
                        icon: Icons.videocam_outlined,
                        title: 'Camera',
                        value: _deviceCount > 0 ? '$_deviceCount hoạt động' : 'Chưa có Cam',
                        iconColor: AppTheme.statusGreen,
                        statusColor: _deviceCount > 0 ? AppTheme.statusGreen : AppTheme.warmAmber,
                        onTap: () => widget.onTabChange?.call(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CapybaraMetricCard(
                        icon: Icons.wifi,
                        title: 'Kết nối API',
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

                // Chế độ thích ứng (Adaptive profiles)
                _buildAdaptiveModesSelector(),
                const SizedBox(height: 22),

                // Sự kiện gần đây (Recent alerts)
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
                          ? 'Hệ thống camera & AI hoạt động bình thường'
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
              const CapybaraAvatar(size: 64),
            ],
          ),
          const SizedBox(height: 20),

          // Action Button: Nhấn để Bật / Nhấn giữ 1.5s để Tắt (Anti-accidental disarming)
          if (_isArmed) ...[
            GestureDetector(
              onTapDown: (_) => _holdController.forward(),
              onTapUp: (_) => _holdController.reverse(),
              onTapCancel: () => _holdController.reverse(),
              child: AnimatedBuilder(
                animation: _holdController,
                builder: (context, child) {
                  return Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.statusDanger.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Thanh tiến trình khi giữ nút
                        FractionallySizedBox(
                          widthFactor: _holdController.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.statusDanger.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        Center(
                          child: _isTogglingArm
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.lock_open, color: AppTheme.statusDanger, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _holdController.value > 0
                                          ? 'ĐANG GIỮ ĐỂ TẮT BẢO VỆ...'
                                          : 'NHẤN GIỮ 1.5s ĐỂ TẮT BẢO VỆ',
                                      style: const TextStyle(
                                        color: AppTheme.statusDanger,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            InkWell(
              onTap: _isTogglingArm ? null : _executeToggleArm,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.statusGreenBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.statusGreen),
                ),
                child: Center(
                  child: _isTogglingArm
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield, color: AppTheme.statusGreen, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'KÍCH HOẠT BẢO VỆ NGAY',
                              style: TextStyle(
                                color: AppTheme.statusGreen,
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
                'Chưa có sự kiện an ninh nào. Ngôi nhà đang được bảo vệ an toàn!',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentAlerts.map((alert) {
        final isStranger = alert.triggerReason.toUpperCase().contains('FACE') ||
            alert.triggerReason.toUpperCase().contains('STRANGER');
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
                      '${alert.deviceName} • ${alert.description}',
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
