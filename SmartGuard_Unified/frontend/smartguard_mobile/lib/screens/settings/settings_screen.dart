import 'package:flutter/material.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../core/session_manager.dart';
import '../../services/auth_service.dart';
import '../../widgets/capybara_widgets.dart';
import '../adaptive/adaptive_security_screen.dart';
import '../auth/login_screen.dart';
import '../devices/devices_screen.dart';
import '../members/members_screen.dart';
import 'server_config_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final canBio = await AuthService.canUseBiometric();
    if (mounted) setState(() => _biometricEnabled = canBio);
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            CapybaraAvatar(size: 34),
            SizedBox(width: 10),
            Text('Đăng xuất?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi SmartGuard? Capybara sẽ vẫn tiếp tục canh gác hệ thống ở chế độ nền.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ở lại', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cấu hình Thông báo & Cảnh báo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              value: true,
              activeThumbColor: AppTheme.primaryPurple,
              title: const Text('Cảnh báo Discord Bot 2 chiều', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Gửi ảnh & nút bấm phản hồi tới Discord', style: TextStyle(fontSize: 12)),
              onChanged: (_) {},
            ),
            SwitchListTile(
              value: true,
              activeThumbColor: AppTheme.primaryPurple,
              title: const Text('Cảnh báo qua Email', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Gửi email kèm ảnh khi phát hiện người lạ', style: TextStyle(fontSize: 12)),
              onChanged: (_) {},
            ),
            SwitchListTile(
              value: true,
              activeThumbColor: AppTheme.primaryPurple,
              title: const Text('Âm thanh giọng nói tiếng Việt', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Capybara phát giọng cảnh báo qua Text-to-Speech', style: TextStyle(fontSize: 12)),
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Title & Avatar
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cài đặt',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  CapybaraAvatar(size: 42),
                ],
              ),
              const SizedBox(height: 16),

              // Profile Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFF1E7DD)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CapybaraAvatar(size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            SessionManager.username.isNotEmpty ? SessionManager.username : 'Chủ nhà Capybara',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            SessionManager.email.isNotEmpty ? SessionManager.email : 'admin@smartguard.local',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.capyPeach,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              SessionManager.role.isNotEmpty ? SessionManager.role : 'Owner / Quản trị',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.capyBrownDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Menu Options Group (Matching Design Mockup)
              _buildMenuGroup([
                _buildMenuItem(
                  icon: Icons.shield_outlined,
                  title: 'Cài đặt bảo vệ (Chế độ thích ứng)',
                  color: AppTheme.primaryPurple,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdaptiveSecurityScreen()),
                  ),
                ),
                _buildMenuItem(
                  icon: Icons.devices_outlined,
                  title: 'Thiết bị an ninh',
                  color: AppTheme.warmAmber,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DevicesScreen()),
                  ),
                ),
                _buildMenuItem(
                  icon: Icons.people_outline,
                  title: 'Chia sẻ & Thành viên',
                  color: AppTheme.statusGreen,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MembersScreen()),
                  ),
                ),
                _buildMenuItem(
                  icon: Icons.notifications_active_outlined,
                  title: 'Thông báo & Discord Webhook',
                  color: Colors.indigoAccent,
                  onTap: _showNotificationSettings,
                ),
                _buildMenuItem(
                  icon: Icons.dns_outlined,
                  title: 'Địa chỉ Máy chủ (${AppConfig.baseUrl})',
                  color: Colors.blueGrey,
                  onTap: () => ServerConfigDialog.show(context),
                ),
              ]),

              const SizedBox(height: 16),
              _buildMenuGroup([
                _buildMenuItem(
                  icon: Icons.fingerprint,
                  title: 'Bảo mật Sinh trắc học',
                  color: AppTheme.capyBrown,
                  trailing: Switch(
                    value: _biometricEnabled,
                    activeThumbColor: AppTheme.primaryPurple,
                    onChanged: (val) => setState(() => _biometricEnabled = val),
                  ),
                ),
                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: 'Trung tâm trợ giúp',
                  color: Colors.teal,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tài liệu hướng dẫn trực tuyến SmartGuard')),
                    );
                  },
                ),
                _buildMenuItem(
                  icon: Icons.info_outline,
                  title: 'Giới thiệu SmartGuard',
                  color: AppTheme.primaryPurple,
                  subtitle: 'Phiên bản 1.0.0 (Capybara Edition)',
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'SmartGuard Unified',
                      applicationVersion: '1.0.0 (Capybara Edition)',
                      applicationLegalese: 'Capybara giữ nhà, Nhà luôn an tâm! 🐾',
                    );
                  },
                ),
              ]),

              const SizedBox(height: 16),
              // Logout Button
              _buildMenuGroup([
                _buildMenuItem(
                  icon: Icons.logout,
                  title: 'Đăng xuất tài khoản',
                  color: AppTheme.statusDanger,
                  textColor: AppTheme.statusDanger,
                  onTap: _handleLogout,
                ),
              ]),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGroup(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1E7DD)),
      ),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    Color? textColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppTheme.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))
          : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
    );
  }
}
