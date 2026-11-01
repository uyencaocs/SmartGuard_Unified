import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/session_manager.dart';
import '../../services/auth_service.dart';
import '../home_shell.dart';

class OtpScreen extends StatefulWidget {
  final String challengeId;
  final String maskedEmail;
  final String? devOtp;

  const OtpScreen({
    super.key,
    required this.challengeId,
    required this.maskedEmail,
    this.devOtp,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _pinControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Nếu ở chế độ LAN/Dev và server trả sẵn devOtp, tự động điền vào 6 ô
    final code = widget.devOtp;
    if (code != null && code.length == 6) {
      for (int i = 0; i < 6; i++) {
        _pinControllers[i].text = code[i];
      }
    }
  }

  @override
  void dispose() {
    for (var c in _pinControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _pinControllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final code = _otpCode.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ 6 chữ số mã OTP.')),
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

      final canBio = await AuthService.canUseBiometric();
      if (canBio && mounted) {
        final enableBio = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.cardWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Kích hoạt Sinh trắc học', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Bạn có muốn bật xác thực bằng vân tay hoặc Face ID cho các lần đăng nhập sau không?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bỏ qua', style: TextStyle(color: AppTheme.secondaryText))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalPurple),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kích hoạt'),
              ),
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
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('Xác thực OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // Cute Mascot with Mail Envelope
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2E6),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderWarm, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/lock.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.mark_email_read_rounded,
                        color: AppTheme.coralPink,
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Xác thực OTP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.headingDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText, height: 1.5),
                  children: [
                    const TextSpan(text: 'Chúng tôi đã gửi mã OTP đến email:\n'),
                    TextSpan(
                      text: widget.maskedEmail,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.headingDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 6 Separate Rounded OTP Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 46,
                    height: 56,
                    child: TextField(
                      controller: _pinControllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.headingDark),
                      decoration: InputDecoration(
                        counterText: '',
                        fillColor: AppTheme.cardWhite,
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.borderWarm, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.royalPurple, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (val.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (_otpCode.length == 6) {
                          _verifyOtp();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Expiry timer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AppTheme.secondaryText),
                  const SizedBox(width: 6),
                  const Text(
                    'Mã sẽ hết hạn sau ',
                    style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                  ),
                  Text(
                    '02:54',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.coralPink),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Gradient Button: Xác nhận
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.coralPink.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Xác nhận',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Resend code link
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã gửi lại mã OTP mới tới email của bạn.')),
                    );
                  },
                  child: const Text(
                    'Gửi lại mã (00:30)',
                    style: TextStyle(color: AppTheme.secondaryText, fontWeight: FontWeight.bold, fontSize: 13),
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
