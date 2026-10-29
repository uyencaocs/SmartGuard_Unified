import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../core/session_manager.dart';
import '../../services/auth_service.dart';
import '../auth/welcome_screen.dart';
import '../admin/admin_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool isModal;
  const SettingsScreen({super.key, this.isModal = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverController = TextEditingController();
  bool _testingConnection = false;
  String? _testResult;
  bool _testSuccess = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _serverController.text = AppConfig.baseUrl;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bio = await SessionManager.isBiometricEnabled();
    if (mounted) setState(() => _biometricEnabled = bio);
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _testResult = null;
    });

    final targetUrl = _serverController.text.trim();
    final ok = await ApiClient.testConnection(targetUrl);

    if (mounted) {
      setState(() {
        _testingConnection = false;
        _testSuccess = ok;
        _testResult = ok
            ? 'Kết nối máy chủ thành công (HTTP 200 OK)!'
            : 'Không thể kết nối đến máy chủ. Hãy kiểm tra xem Backend đã chạy và cùng Wi-Fi chưa.';
      });
    }
  }

  Future<void> _saveServerUrl() async {
    final targetUrl = _serverController.text.trim();
    if (targetUrl.isEmpty) return;

    await AppConfig.setBaseUrl(targetUrl);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu cấu hình máy chủ mới.'),
          backgroundColor: AppTheme.statusArmed,
        ),
      );
      if (widget.isModal) Navigator.pop(context);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi SmartGuard?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusAlarm),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
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
      appBar: AppBar(title: const Text('Cài đặt hệ thống')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Server Network Configuration Section
            const Text(
              'Cấu hình Máy chủ (Backend IP)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Thiết lập địa chỉ API của máy trạm để ứng dụng di động kết nối qua mạng LAN hoặc từ xa.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serverController,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ Base URL',
                prefixIcon: Icon(Icons.dns_outlined),
                hintText: 'http://192.168.2.6:5235',
              ),
            ),
            const SizedBox(height: 10),

            // Quick Preset Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Mạng LAN (192.168.2.6)'),
                  onPressed: () => setState(() => _serverController.text = AppConfig.defaultLanUrl),
                ),
                ActionChip(
                  label: const Text('Máy ảo Emulator (10.0.2.2)'),
                  onPressed: () => setState(() => _serverController.text = AppConfig.emulatorUrl),
                ),
                ActionChip(
                  label: const Text('Localhost (5235)'),
                  onPressed: () => setState(() => _serverController.text = AppConfig.localhostUrl),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Ping & Save Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testingConnection ? null : _testConnection,
                    icon: _testingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check),
                    label: const Text('Kiểm tra kết nối'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveServerUrl,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Lưu máy chủ'),
                  ),
                ),
              ],
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSuccess
                      ? AppTheme.statusArmed.withValues(alpha: 0.12)
                      : AppTheme.statusAlarm.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _testSuccess ? AppTheme.statusArmed : AppTheme.statusAlarm,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Security & Biometric Section
            if (SessionManager.isLoggedIn) ...[
              const Text(
                'Bảo mật & Sinh trắc học',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.fingerprint, color: AppTheme.primaryBlue, size: 28),
                  title: const Text('Đăng nhập bằng Sinh trắc học', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Mở khóa nhanh bằng vân tay hoặc Face ID'),
                  value: _biometricEnabled,
                  activeThumbColor: AppTheme.statusArmed,
                  onChanged: (val) async {
                    await SessionManager.setBiometricEnabled(val);
                    setState(() => _biometricEnabled = val);
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Admin Management Quick Navigation
              Card(
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF7C3AED), size: 28),
                  title: const Text('Quản trị hệ thống & Tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Quản lý người dùng, phân quyền, hình ảnh & máy chủ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.statusAlarm,
                  side: const BorderSide(color: AppTheme.statusAlarm),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất khỏi hệ thống', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
