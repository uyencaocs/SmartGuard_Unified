import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'camera/camera_guard_screen.dart';
import 'alerts/alerts_history_screen.dart';
import 'motion/motion_detection_screen.dart';
import 'settings/settings_screen.dart';
import '../widgets/battery_exemption_prompt.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Lần đầu mở app: xin miễn tối ưu pin để Doze không tắt dịch vụ giám sát
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BatteryExemptionPrompt.showOnFirstLaunch(context);
    });
  }

  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();
  final GlobalKey<AlertsHistoryScreenState> _alertsKey = GlobalKey<AlertsHistoryScreenState>();

  late final List<Widget> _screens = [
    DashboardScreen(key: _dashboardKey),
    AlertsHistoryScreen(key: _alertsKey, isTab: true),
    const CameraGuardScreen(isTab: true),
    const MotionDetectionScreen(isTab: true),
    const SettingsScreen(isTab: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          border: const Border(top: BorderSide(color: AppTheme.borderWarm, width: 1.2)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryNavy.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.shield_rounded, Icons.shield_outlined, 'Bảo vệ'),
                _buildNavItem(1, Icons.history_rounded, Icons.history_outlined, 'Lịch sử'),
                _buildNavItem(2, Icons.videocam_rounded, Icons.videocam_outlined, 'Camera'),
                _buildNavItem(3, Icons.sensors_rounded, Icons.sensors_outlined, 'Cảm biến'),
                _buildNavItem(4, Icons.settings_rounded, Icons.settings_outlined, 'Cài đặt'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 0) {
          _dashboardKey.currentState?.reloadDashboard();
        } else if (index == 1) {
          _alertsKey.currentState?.reloadAlerts();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFECE5) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? AppTheme.coralPink : AppTheme.secondaryText,
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppTheme.coralPink : AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
