import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'camera/camera_guard_screen.dart';
import 'alerts/alerts_history_screen.dart';
import 'zones/zones_screen.dart';
import 'settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();
  final GlobalKey<AlertsHistoryScreenState> _alertsKey = GlobalKey<AlertsHistoryScreenState>();

  late final List<Widget> _screens = [
    DashboardScreen(key: _dashboardKey),
    const CameraGuardScreen(),
    AlertsHistoryScreen(key: _alertsKey),
    const ZonesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 2) {
            _alertsKey.currentState?.reloadAlerts();
          } else if (index == 0) {
            _dashboardKey.currentState?.reloadDashboard();
          }
        },
        indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryBlue),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam, color: AppTheme.primaryBlue),
            label: 'Camera AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_outlined),
            selectedIcon: Icon(Icons.notifications, color: AppTheme.primaryBlue),
            label: 'Cảnh báo',
          ),
          NavigationDestination(
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room, color: AppTheme.primaryBlue),
            label: 'Khu vực',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppTheme.primaryBlue),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
