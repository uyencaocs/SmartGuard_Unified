import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/session_manager.dart';
import '../../services/auth_service.dart';
import '../../widgets/capybara_widgets.dart';
import '../home_shell.dart';
import '../settings/server_config_dialog.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _canBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final canBio = await AuthService.canUseBiometric();
    if (mounted) setState(() => _canBiometric = canBio);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập tài khoản/email và mật khẩu.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.login(
        identifier: identifier,
        password: password,
      );

      if (!mounted) return;

      // Backend returns ChallengeId for OTP verification
      final challengeId = res['challengeId']?.toString();
      final maskedEmail = res['email']?.toString() ?? identifier;

      if (challengeId != null && challengeId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              challengeId: challengeId,
              maskedEmail: maskedEmail,
            ),
          ),
        );
      } else if (res['token'] != null) {
        // Direct login fallback
        await SessionManager.saveSession(
          token: res['token'].toString(),
          userId: res['userId']?.toString() ?? '',
          email: res['email']?.toString() ?? '',
          username: res['username']?.toString() ?? '',
          role: res['role']?.toString() ?? 'Owner',
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBiometricLogin() async {
    final success = await AuthService.authenticateBiometric();
    if (success && mounted && SessionManager.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmCream,
      appBar: AppBar(
        title: const Text('SmartGuard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.primaryPurple),
            tooltip: 'Cài đặt máy chủ',
            onPressed: () => ServerConfigDialog.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mascot Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 106,
                          height: 106,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.capyPeach.withValues(alpha: 0.5),
                          ),
                        ),
                        const CapybaraAvatar(size: 88),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Chào mừng trở lại! ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text('👋', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Đăng nhập để tiếp tục bảo vệ ngôi nhà của bạn',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Email / Username field
              const Text(
                'Email hoặc Tên đăng nhập',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _identifierController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'example@gmail.com',
                  prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryPurple),
                ),
              ),
              const SizedBox(height: 16),

              // Password field
              const Text(
                'Mật khẩu',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: '••••••••••••',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryPurple),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Remember me & Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: AppTheme.primaryPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) => setState(() => _rememberMe = val ?? true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ghi nhớ đăng nhập',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    ),
                    child: const Text(
                      'Quên mật khẩu?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.statusDangerBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.statusDanger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.statusDanger,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              CapybaraGradientButton(
                text: 'Đăng nhập',
                onPressed: _handleLogin,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 20),
              // Divider: hoặc
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFEADBCE))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'hoặc',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFEADBCE))),
                ],
              ),
              const SizedBox(height: 18),

              // Google Login Button
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tính năng đăng nhập Google đang được tích hợp.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  side: const BorderSide(color: Color(0xFFEADBCE)),
                  backgroundColor: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      width: 18,
                      height: 18,
                      errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Đăng nhập với Google',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              if (_canBiometric && SessionManager.isLoggedIn) ...[
                const SizedBox(height: 12),
                Center(
                  child: IconButton(
                    iconSize: 42,
                    icon: const Icon(Icons.fingerprint, color: AppTheme.primaryPurple),
                    tooltip: 'Đăng nhập bằng vân tay',
                    onPressed: _handleBiometricLogin,
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: RichText(
                    text: const TextSpan(
                      text: 'Chưa có tài khoản? ',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Đăng ký ngay',
                          style: TextStyle(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
