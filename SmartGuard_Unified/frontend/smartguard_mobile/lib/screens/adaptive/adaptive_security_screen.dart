import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../widgets/capybara_widgets.dart';

class AdaptiveSecurityScreen extends StatefulWidget {
  const AdaptiveSecurityScreen({super.key});

  @override
  State<AdaptiveSecurityScreen> createState() => _AdaptiveSecurityScreenState();
}

class _AdaptiveSecurityScreenState extends State<AdaptiveSecurityScreen> {
  int _selectedMinutes = 30;
  bool _isSnoozing = false;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  String _activeMode = 'Home';

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final res = await ApiClient.request('GET', '/api/adaptivesecurity/current-mode');
      if (res is Map<String, dynamic> && res['currentMode'] != null) {
        setState(() => _activeMode = res['currentMode'].toString());
      }
    } catch (_) {}
  }

  void _startSnooze() async {
    try {
      await ApiClient.request('POST', '/api/adaptivesecurity/snooze', body: {
        'durationMinutes': _selectedMinutes,
        'reason': 'Người dùng tạm ngưng trên app',
      });
    } catch (_) {}

    setState(() {
      _isSnoozing = true;
      _remainingSeconds = _selectedMinutes * 60;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _isSnoozing = false;
          timer.cancel();
        }
      });
    });
  }

  void _cancelSnooze() {
    _countdownTimer?.cancel();
    setState(() {
      _isSnoozing = false;
      _remainingSeconds = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🐾 Capybara đã tái kích hoạt bảo vệ toàn diện!'),
        backgroundColor: AppTheme.statusGreen,
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final h = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmCream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Bảo vệ thích ứng'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Snooze Card (Matching Mockup with Relaxed Capybara)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFF1E7DD)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warmAmber.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Mascot relaxing
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.capyPeach.withValues(alpha: 0.5),
                          ),
                        ),
                        const CapybaraAvatar(size: 76),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSnoozing ? 'Đang tạm tắt bảo vệ trong' : 'Tạm tắt bảo vệ trong',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Big Clock Display
                    Text(
                      _isSnoozing
                          ? _formatTimer(_remainingSeconds)
                          : _formatTimer(_selectedMinutes * 60),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Duration Chips (15 phút, 30 phút, 60 phút)
                    if (!_isSnoozing)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [15, 30, 60].map((mins) {
                          final isSelected = _selectedMinutes == mins;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: ChoiceChip(
                              label: Text('$mins phút'),
                              selected: isSelected,
                              selectedColor: AppTheme.primaryPurple,
                              backgroundColor: const Color(0xFFF8F5F2),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSelected ? AppTheme.primaryPurple : const Color(0xFFEADBCE),
                                ),
                              ),
                              onSelected: (_) => setState(() => _selectedMinutes = mins),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 20),
                    CapybaraGradientButton(
                      text: _isSnoozing ? 'Hủy bỏ và kích hoạt lại' : 'Bắt đầu',
                      onPressed: _isSnoozing ? _cancelSnooze : _startSnooze,
                      gradient: _isSnoozing
                          ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3 Chế độ tiêu chuẩn (Home / Away / Night)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '3 Chế độ thông minh',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(height: 10),

              _buildModeCard(
                title: 'Ở nhà (Home)',
                description: 'Miễn trừ cảnh báo tại phòng khách & bếp, chỉ canh gác cửa chính.',
                icon: Icons.home,
                color: Colors.blueAccent,
                isActive: _activeMode == 'Home',
              ),
              const SizedBox(height: 10),
              _buildModeCard(
                title: 'Rời nhà (Away)',
                description: 'Kích hoạt toàn diện tất cả cảm biến và camera ở mọi phân vùng.',
                icon: Icons.directions_walk,
                color: AppTheme.warmAmber,
                isActive: _activeMode == 'Away',
              ),
              const SizedBox(height: 10),
              _buildModeCard(
                title: 'Ban đêm (Night)',
                description: 'Tăng độ nhạy phát hiện x1.5, còi báo động ngay khi phát hiện người lạ.',
                icon: Icons.nightlight_round,
                color: AppTheme.primaryPurple,
                isActive: _activeMode == 'Night',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppTheme.primaryPurple : const Color(0xFFF1E7DD),
          width: isActive ? 1.8 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.statusGreenBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Đang chọn',
                          style: TextStyle(color: AppTheme.statusGreen, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
