import 'package:flutter/material.dart';
import '../core/app_config.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../services/alert_service.dart';
import 'capybara_widgets.dart';

class RealtimeAlertDialog extends StatefulWidget {
  final AlertModel alert;

  const RealtimeAlertDialog({super.key, required this.alert});

  static Future<void> show(BuildContext context, AlertModel alert) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RealtimeAlertDialog(alert: alert),
    );
  }

  @override
  State<RealtimeAlertDialog> createState() => _RealtimeAlertDialogState();
}

class _RealtimeAlertDialogState extends State<RealtimeAlertDialog> {
  bool _isActing = false;

  Future<void> _handleAction(String action, String message) async {
    setState(() => _isActing = true);
    try {
      await AlertService.acknowledgeAlert(widget.alert.id, action: action);
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: action == 'known'
              ? AppTheme.statusGreen
              : (action == 'stranger' ? AppTheme.statusDanger : AppTheme.primaryPurple),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi xử lý: $e'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final isStranger = alert.triggerReason.toUpperCase().contains('STRANGER') ||
        alert.triggerReason.toUpperCase().contains('FACE');

    return PopScope(
      canPop: !_isActing,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(20),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isStranger ? AppTheme.statusDangerBg : AppTheme.statusWarningBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isStranger ? Icons.warning_rounded : Icons.notifications_active,
                color: isStranger ? AppTheme.statusDanger : AppTheme.warmAmber,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CẢNH BÁO AN NINH!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.statusDanger,
                    ),
                  ),
                  Text(
                    'Thiết bị: ${alert.deviceName}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Evidence Image if present
              if (alert.imageUrl != null && alert.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Image.network(
                        '${AppConfig.baseUrl}/evidence/${alert.imageUrl}',
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: const Color(0xFFF1E7DD),
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey, size: 36),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ẢNH BẰNG CHỨNG',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Adaptive reason & event details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF1E7DD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CapybaraAvatar(size: 24),
                        const SizedBox(width: 8),
                        Text(
                          alert.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.description,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Chọn thao tác xử lý khẩn cấp:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 10),

              // Action 1: Người quen
              OutlinedButton.icon(
                onPressed: _isActing
                    ? null
                    : () => _handleAction('known', 'Đã xác nhận Người quen. Còi tắt và tạm dừng cảnh báo 3 phút.'),
                icon: const Icon(Icons.verified_user, color: AppTheme.statusGreen, size: 18),
                label: const Text('Xác nhận: Người quen (Tắt còi & Nghỉ 3p)'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  side: const BorderSide(color: AppTheme.statusGreen),
                  foregroundColor: AppTheme.statusGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),

              // Action 2: Người lạ xâm nhập
              ElevatedButton.icon(
                onPressed: _isActing
                    ? null
                    : () => _handleAction('stranger', 'Đã xác nhận Người lạ! Báo động & lưu giữ bằng chứng được kích hoạt.'),
                icon: const Icon(Icons.warning, color: Colors.white, size: 18),
                label: const Text('Xác nhận: NGƯỜI LẠ XÂM NHẬP (Báo động!)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  backgroundColor: AppTheme.statusDanger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),

              // Action 3: Tắt chuông báo động
              OutlinedButton.icon(
                onPressed: _isActing
                    ? null
                    : () => _handleAction('mute', 'Đã tắt còi hú và tạm dừng cảnh báo 3 phút.'),
                icon: const Icon(Icons.volume_off, color: AppTheme.primaryPurple, size: 18),
                label: const Text('Tắt chuông báo động'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  side: const BorderSide(color: AppTheme.primaryPurple),
                  foregroundColor: AppTheme.primaryPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isActing ? null : () => Navigator.of(context).pop(),
            child: const Text('Đóng', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }
}
