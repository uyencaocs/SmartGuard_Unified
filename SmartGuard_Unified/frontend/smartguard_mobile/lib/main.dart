import 'package:flutter/material.dart';
import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'core/session_manager.dart';
import 'screens/auth/welcome_screen.dart';
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
      title: 'SmartGuard Unified',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: SessionManager.isLoggedIn ? const HomeShell() : const WelcomeScreen(),
    );
  }
}
