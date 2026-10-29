import 'package:flutter/material.dart';
import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'core/session_manager.dart';

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
      home: const Scaffold(
        body: Center(
          child: Text(
            'Sẵn sàng thiết kế giao diện mới...',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
