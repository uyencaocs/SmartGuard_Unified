import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/session_manager.dart';
import '../../services/auth_service.dart';
import '../home_shell.dart';

class OtpScreen extends StatefulWidget {
  final String challengeId;
  final String maskedEmail;

  const OtpScreen({
    super.key,
    required this.challengeId,
    required this.maskedEmail,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đúng mã OTP gồm 6 chữ số.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.verifyOtp(
        challengeId: widget.challengeId,
        code: code,
      );

      if (!mounted) return;

      // Kiểm tra hỗ trợ sinh trắc học để gợi ý kích hoạt
      final canBio = await AuthService.canUseBiometric();
      if (canBio && mounted) {
        final enableBio = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Kích hoạt Sinh trắc học'),
            content: const Text('Bạn có muốn bật xác thực bằng vân tay hoặc Face ID cho các lần đăng nhập sau không?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bỏ qua')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kích hoạt')),
            ],
          ),
        );

        if (enableBio == true) {
          await SessionManager.setBiometricEnabled(true);
        }
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
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
      appBar: AppBar(title: const Text('Xác thực 2 bước (2FA)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.mark_email_read_outlined, size: 64, color: AppTheme.primaryBlue),
              const SizedBox(height: 16),
              const Text(
                'Nhập mã xác thực OTP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã bảo mật gồm 6 chữ số đã được gửi tới email:\n${widget.maskedEmail}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Xác nhận & Đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
