import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../settings/settings_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderWarm),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppTheme.primaryNavy, size: 22),
                    tooltip: 'Cài đặt máy chủ',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen(isModal: true)),
                      );
                    },
                  ),
                ),
              ),
              const Spacer(),

              // Cute Capybara Mascot Illustration
              Center(
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderWarm, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.coralPink.withValues(alpha: 0.12),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/3bc65821-0388-43aa-aba6-16fc6a3912a4.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield,
                          size: 72,
                          color: AppTheme.coralPink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Brand Title: SmartGuard
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Smart',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.coralPink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Guard',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryNavy,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Tagline
              const Text(
                'Capybara giữ nhà,\nNhà luôn an tâm! 🐾',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryText,
                  height: 1.4,
                ),
              ),
              const Spacer(),

              // Gradient Button: Đăng nhập
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.coralPink.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text(
                    'Đăng nhập',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Outlined Button: Đăng ký tài khoản
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.cardWhite,
                  side: const BorderSide(color: AppTheme.borderWarm, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text(
                  'Tạo tài khoản mới',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
