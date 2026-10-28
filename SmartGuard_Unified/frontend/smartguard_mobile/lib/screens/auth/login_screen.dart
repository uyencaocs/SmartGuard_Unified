import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/session_manager.dart';
import '../../services/auth_service.dart';
import 'otp_screen.dart';
import 'register_screen.dart';
import '../home_shell.dart';
import '../admin/admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Hiển thị nút vân tay khi thiết bị HỖ TRỢ sinh trắc học
  // (không cần bật toggle trong Settings trước)
  bool _deviceSupportsBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final canBio = await AuthService.canUseBiometric();
    if (mounted) {
      setState(() => _deviceSupportsBiometric = canBio);
    }

    // Nếu thiết bị hỗ trợ VÀ người dùng từng đăng nhập (có session) → tự động kích hoạt
    if (canBio && SessionManager.isLoggedIn) {
      final isEnabled = await SessionManager.isBiometricEnabled();
      if (isEnabled && mounted) {
        _triggerBiometricLogin();
      }
    }
  }

  Future<void> _triggerBiometricLogin() async {
    final success = await AuthService.authenticateBiometric();
    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    }
  }

  Future<void> _submitLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tài khoản và mật khẩu.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.login(identifier: identifier, password: password);
      final challengeId = res['challengeId']?.toString() ?? '';
      final maskedEmail = res['email']?.toString() ?? identifier;

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            challengeId: challengeId,
            maskedEmail: maskedEmail,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.statusAlarm,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng nhập'),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Trang Quản trị Hệ thống',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Chào mừng trở lại',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nhập thông tin tài khoản để truy cập hệ thống camera',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _identifierController,
                decoration: const InputDecoration(
                  labelText: 'Email hoặc Tên đăng nhập',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitLogin,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Tiếp tục (Nhận mã OTP)'),
              ),

              // Nút vân tay: hiện khi thiết bị HỖ TRỢ sinh trắc học
              if (_deviceSupportsBiometric) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _triggerBiometricLogin,
                  icon: const Icon(Icons.fingerprint, color: AppTheme.primaryBlue, size: 28),
                  label: const Text(
                    'Đăng nhập bằng Vân tay / Face ID',
                    style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],

              // Fallback: luôn hiện nút icon vân tay nhỏ kể cả khi chưa check xong
              if (!_deviceSupportsBiometric) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: _triggerBiometricLogin,
                    icon: const Icon(Icons.fingerprint, size: 32, color: Color(0xFF94A3B8)),
                    label: const Text(
                      'Thử đăng nhập sinh trắc học',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chưa có tài khoản? '),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text(
                      'Đăng ký ngay',
                      style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
