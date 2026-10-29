import 'package:flutter/material.dart';
import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'core/session_manager.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();
  await SessionManager.init();

  runApp(const SmartGuardApp());
}

class SmartGuardApp extends StatelessWidget {
  const SmartGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartGuard - Capybara giữ nhà',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: SessionManager.isLoggedIn ? const HomeShell() : const LoginScreen(),
    );
  }
}
