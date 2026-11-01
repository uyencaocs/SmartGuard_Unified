import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '../services/foreground_service_controller.dart';

/// Lời nhắc miễn tối ưu pin (Battery Optimization Exemption).
///
/// Dù đã có Foreground Service + WakeLock, Doze Mode của Android vẫn có thể
/// hoãn mạng / CPU của ứng dụng. Ứng dụng camera an ninh bắt buộc phải nằm
/// trong danh sách ngoại lệ để không bỏ lỡ cảnh báo.
class BatteryExemptionPrompt {
  static const String _prefShownKey = 'sg_battery_prompt_shown';

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// Gọi khi mở app: chỉ hiện bottom sheet ở lần đầu tiên (hoặc khi chưa từng
  /// hiện) và chỉ khi ứng dụng CHƯA được miễn tối ưu pin.
  static Future<void> showOnFirstLaunch(BuildContext context) async {
    if (!_isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefShownKey) == true) return;
    if (await ForegroundServiceController.isIgnoringBatteryOptimizations()) {
      await prefs.setBool(_prefShownKey, true);
      return;
    }
    if (!context.mounted) return;
    await prefs.setBool(_prefShownKey, true);
    await show(context);
  }

  /// Hiển thị bottom sheet (có thể gọi lại thủ công từ Cài đặt / Cảm biến)
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BatterySheet(),
    );
  }
}

class _BatterySheet extends StatelessWidget {
  const _BatterySheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/images/sticker_bao_an.png',
              height: 110,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.battery_charging_full_rounded,
                size: 80, color: AppTheme.statusArmed),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cho Capybara gác đêm nhé!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppTheme.headingDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Android có thể tự tắt SmartGuard khi màn hình tắt để tiết kiệm pin '
              '(Doze Mode). Hãy cho phép SmartGuard chạy nền không giới hạn để '
              'không bỏ lỡ bất kỳ cảnh báo xâm nhập nào.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: AppTheme.secondaryText),
            ),
            const SizedBox(height: 16),
            const _Bullet(icon: Icons.shield_moon_rounded,
                text: 'Giám sát liên tục 24/7, kể cả khi khóa màn hình'),
            const _Bullet(icon: Icons.phone_in_talk_rounded,
                text: 'Gọi điện khẩn cấp ngay cả khi máy đang ngủ'),
            const _Bullet(icon: Icons.notifications_active_rounded,
                text: 'Gửi cảnh báo Discord không bị trễ'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  icon: const Icon(Icons.battery_saver_rounded),
                  label: const Text('Cho phép chạy nền'),
                  onPressed: () async {
                    await ForegroundServiceController.requestBatteryExemption();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Để sau',
                  style: TextStyle(color: AppTheme.secondaryText)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Bullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.royalPurple),
          const SizedBox(width: 10),
          Expanded(child: Text(text,
              style: const TextStyle(fontSize: 13, color: AppTheme.textDark))),
        ],
      ),
    );
  }
}

/// Thẻ cảnh báo nhỏ, tự kiểm tra lại trạng thái khi người dùng quay lại app.
/// Tự ẩn khi đã được miễn tối ưu pin.
class BatteryStatusCard extends StatefulWidget {
  const BatteryStatusCard({super.key});

  @override
  State<BatteryStatusCard> createState() => _BatteryStatusCardState();
}

class _BatteryStatusCardState extends State<BatteryStatusCard>
    with WidgetsBindingObserver {
  bool? _exempt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Người dùng quay lại từ hộp thoại hệ thống → kiểm tra kết quả thật
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (kIsWeb || !Platform.isAndroid) {
      if (mounted) setState(() => _exempt = true);
      return;
    }
    final v = await ForegroundServiceController.isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _exempt = v);
  }

  @override
  Widget build(BuildContext context) {
    if (_exempt != false) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.statusWarningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.statusWarning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.battery_alert_rounded, color: AppTheme.statusWarning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Tối ưu pin đang bật – Android có thể dừng giám sát khi màn hình tắt.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textDark),
            ),
          ),
          TextButton(
            onPressed: () => ForegroundServiceController.requestBatteryExemption(),
            child: const Text('Sửa ngay',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.coralPink)),
          ),
        ],
      ),
    );
  }
}

