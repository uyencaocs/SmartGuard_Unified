import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../core/session_manager.dart';
import '../../services/auth_service.dart';
import '../admin/admin_screen.dart';
import '../auth/welcome_screen.dart';
import '../camera/camera_guard_screen.dart';
import '../members/members_screen.dart';
import '../motion/motion_detection_screen.dart';
import '../zones/zones_screen.dart';
import '../../widgets/battery_exemption_prompt.dart';

class SettingsScreen extends StatefulWidget {
  final bool isTab;
  final bool isModal;
  const SettingsScreen({super.key, this.isTab = false, this.isModal = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverController = TextEditingController();
  bool _testingConnection = false;
  String? _testResult;
  bool _testSuccess = false;

  String _username = 'Người bảo vệ';
  String _email = 'user@smartguard.local';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _serverController.text = AppConfig.baseUrl;
    _loadUserInfo();
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final user = await SessionManager.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _username = user.username;
        _email = user.email;
        _isAdmin = user.role.toLowerCase() == 'admin';
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _testResult = null;
    });

    final targetUrl = _serverController.text.trim();
    final check = await ApiClient.testConnectionDetailed(targetUrl);

    if (mounted) {
      setState(() {
        _testingConnection = false;
        _testSuccess = check.ok;
        _serverController.text = check.url;
        _testResult = check.message;
      });
    }
  }

  Future<void> _saveServerUrl() async {
    final targetUrl = _serverController.text.trim();
    if (targetUrl.isEmpty) return;

    await AppConfig.setBaseUrl(targetUrl);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã lưu địa chỉ máy chủ mới'),
          backgroundColor: AppTheme.statusArmed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showServerConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.dns, color: AppTheme.coralPink),
              SizedBox(width: 8),
              Text('Cấu hình Máy chủ', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Thiết lập địa chỉ API của máy trạm để ứng dụng di động kết nối qua mạng LAN hoặc từ xa.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serverController,
                  decoration: InputDecoration(
                    labelText: 'Địa chỉ Base URL',
                    prefixIcon: const Icon(Icons.link),
                    hintText: 'http://192.168.1.100:5235',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Localhost (5235)'),
                      onPressed: () => setDlgState(() => _serverController.text = AppConfig.localhostUrl),
                    ),
                    ActionChip(
                      label: const Text('Máy ảo (10.0.2.2)'),
                      onPressed: () => setDlgState(() => _serverController.text = AppConfig.emulatorUrl),
                    ),
                    ActionChip(
                      label: const Text('LAN mẫu'),
                      onPressed: () => setDlgState(() => _serverController.text = AppConfig.defaultLanUrl),
                    ),
                    ActionChip(
                      label: const Text('DevTunnel'),
                      onPressed: () => setDlgState(() => _serverController.text = AppConfig.defaultTunnelUrl),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_testResult != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _testSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _testSuccess ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            OutlinedButton(
              onPressed: () async {
                await _testConnection();
                setDlgState(() {});
              },
              child: _testingConnection
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Kiểm tra'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await _saveServerUrl();
                Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppTheme.coralPink),
            SizedBox(width: 8),
            Text('Đăng xuất'),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi SmartGuard?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralPink),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header matching mockup with Capybara peeking out
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (!widget.isTab && Navigator.of(context).canPop())
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                            onPressed: () => Navigator.pop(context),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.borderWarm),
                            ),
                            child: const Icon(Icons.settings, color: AppTheme.coralPink, size: 20),
                          ),
                        const SizedBox(width: 10),
                        const Text(
                          'Cài đặt',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    // Capybara Security Officer sticker peeking at top right (from mockup!)
                    Image.asset(
                      'assets/images/sticker_system.png',
                      height: 52,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/3bc65821-0388-43aa-aba6-16fc6a3912a4.png',
                        height: 48,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Group 1: Account Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderWarm),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: _isAdmin ? const Color(0xFFEDE9FE) : const Color(0xFFFFECE8),
                        child: Text(
                          _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _isAdmin ? AppTheme.royalPurple : AppTheme.coralPink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _username,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _isAdmin ? const Color(0xFFEDE9FE) : const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _isAdmin ? 'Quản trị viên' : 'Chủ nhà',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _isAdmin ? AppTheme.royalPurple : const Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _email,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Group 2: Core Settings Menu Cards (matching mockup list)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.borderWarm),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons.person_outline,
                        iconColor: const Color(0xFF3B82F6),
                        title: 'Hồ sơ & tài khoản',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.shield_outlined,
                        iconColor: const Color(0xFF10B981),
                        title: 'Cài đặt bảo vệ (AI Âm thanh & Cảm biến)',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MotionDetectionScreen()));
                        },
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.battery_saver_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Chạy nền & Miễn tối ưu pin (Doze Mode)',
                        onTap: () => BatteryExemptionPrompt.show(context),
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.videocam_outlined,
                        iconColor: AppTheme.coralPink,
                        title: 'Camera & Cảm biến',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraGuardScreen()));
                        },
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.notifications_none,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Thông báo',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.cloud_outlined,
                        iconColor: const Color(0xFF06B6D4),
                        title: 'Lưu trữ & Cloud',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.devices_outlined,
                        iconColor: AppTheme.royalPurple,
                        title: 'Thiết bị trong nhà',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ZonesScreen()));
                        },
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.people_outline,
                        iconColor: AppTheme.coralPink,
                        title: 'Chia sẻ & Thành viên khẩn cấp',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MembersScreen()));
                        },
                      ),

                      // RBAC Admin Screen Item: Highlighted for Admin
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.admin_panel_settings,
                        iconColor: const Color(0xFF7C3AED),
                        title: 'Quản trị hệ thống (Admin)',
                        badge: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'RBAC',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
                        },
                      ),

                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.dns_outlined,
                        iconColor: const Color(0xFF64748B),
                        title: 'Cấu hình Máy chủ & IP',
                        onTap: _showServerConfigDialog,
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.help_outline,
                        iconColor: const Color(0xFF64748B),
                        title: 'Trung tâm trợ giúp',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.info_outline,
                        iconColor: const Color(0xFF64748B),
                        title: 'Giới thiệu ứng dụng (v2.0)',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildMenuItem(
                        icon: Icons.logout,
                        iconColor: AppTheme.coralPink,
                        title: 'Đăng xuất',
                        titleColor: AppTheme.coralPink,
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Decorative bottom illustration
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/save.png',
                      height: 50,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'SmartGuard Unified • Capybara Security Mascot',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? titleColor,
    Widget? badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor ?? AppTheme.textPrimary,
                  ),
                ),
              ),
              if (badge != null) ...[
                badge,
                const SizedBox(width: 8),
              ],
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: AppTheme.borderWarm, indent: 52);
  }
}
