import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../alerts/alerts_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  bool _serverOnline = false;
  bool _isSystemArmed = true;
  List<DeviceModel> _devices = [];
  List<AlertModel> _recentAlerts = [];
  int _alertCountToday = 0;

  void reloadDashboard() {
    _loadDashboardData();
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final isOnline = await ApiClient.testConnection();

    if (!isOnline) {
      if (mounted) {
        setState(() {
          _serverOnline = false;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final devicesRes = await ApiClient.request('GET', '/api/devices') as List<dynamic>;
      final alertsRes = await ApiClient.request('GET', '/api/alerts/history?limit=10') as List<dynamic>;

      if (mounted) {
        final devs = devicesRes.map((e) => DeviceModel.fromJson(e as Map<String, dynamic>)).toList();
        final alts = alertsRes.map((e) => AlertModel.fromJson(e as Map<String, dynamic>)).toList();

        setState(() {
          _serverOnline = true;
          _devices = devs;
          _recentAlerts = alts;
          _alertCountToday = alts.length;
          _isSystemArmed = devs.any((d) => d.isArmed);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverOnline = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleSystemArm() async {
    final newState = !_isSystemArmed;
    setState(() => _isSystemArmed = newState);

    for (var d in _devices) {
      try {
        await ApiClient.request('PATCH', '/api/devices/${d.id}/toggle-arm');
      } catch (_) {}
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newState ? 'Đã bật chế độ bảo vệ an ninh! 🛡️' : 'Đã tắt chế độ bảo vệ.'),
        backgroundColor: newState ? AppTheme.statusArmed : AppTheme.statusWarning,
      ),
    );
  }

  void _showSnoozeModal() {
    int selectedMinutes = 30;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderWarm, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Image.asset('assets/images/sticker_system(5).png', width: 90, height: 90),
              const SizedBox(height: 12),
              const Text('Tạm tắt bảo vệ trong', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.headingDark)),
              const SizedBox(height: 6),
              Text(
                '00:${selectedMinutes.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.royalPurple),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [15, 30, 60].map((mins) {
                  final isSel = selectedMinutes == mins;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ChoiceChip(
                      label: Text('$mins phút'),
                      selected: isSel,
                      selectedColor: AppTheme.royalPurple,
                      backgroundColor: AppTheme.creamBg,
                      labelStyle: TextStyle(color: isSel ? Colors.white : AppTheme.headingDark, fontWeight: FontWeight.bold),
                      onSelected: (val) {
                        if (val) setModalState(() => selectedMinutes = mins);
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ApiClient.request('POST', '/api/adaptive/snooze', body: {'minutes': selectedMinutes});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã tạm dừng cảnh báo trong $selectedMinutes phút.'), backgroundColor: AppTheme.statusArmed),
                      );
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Bắt đầu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Smart', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.coralPink)),
            Text('Guard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryNavy)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.headingDark, size: 26),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AlertsHistoryScreen()),
                  );
                },
              ),
              if (_alertCountToday > 0)
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.statusAlarm,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.coralPink))
          : RefreshIndicator(
              color: AppTheme.coralPink,
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==========================================
                    // 1. HERO SHIELD CARD (Matching Design Image)
                    // ==========================================
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.borderWarm, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryNavy.withValues(alpha: 0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isSystemArmed ? AppTheme.statusArmedBg : AppTheme.statusWarningBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isSystemArmed ? Icons.shield_rounded : Icons.shield_outlined,
                                  color: _isSystemArmed ? AppTheme.statusArmed : AppTheme.statusWarning,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isSystemArmed ? 'Đang được bảo vệ' : 'Bảo vệ đang tắt',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: _isSystemArmed ? AppTheme.statusArmed : AppTheme.statusWarning,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isSystemArmed ? 'Hệ thống hoạt động bình thường' : 'Hệ thống đang ở chế độ chờ',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                                    ),
                                  ],
                                ),
                              ),
                              // Mascot image
                              Image.asset(
                                'assets/images/3bc65821-0388-43aa-aba6-16fc6a3912a4.png',
                                width: 72,
                                height: 72,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Action Pill Button: TẮT BẢO VỆ / BẬT BẢO VỆ
                          InkWell(
                            onTap: _toggleSystemArm,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isSystemArmed ? Colors.white : AppTheme.statusArmed,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: _isSystemArmed ? AppTheme.statusAlarm : AppTheme.statusArmed,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isSystemArmed ? Icons.lock_outline_rounded : Icons.shield_rounded,
                                    size: 18,
                                    color: _isSystemArmed ? AppTheme.statusAlarm : Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isSystemArmed ? 'TẮT BẢO VỆ' : 'BẬT BẢO VỆ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: _isSystemArmed ? AppTheme.statusAlarm : Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ==========================================
                    // 2. 4 QUICK STATUS METRIC CARDS (2x2 Grid)
                    // ==========================================
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            icon: Icons.videocam_outlined,
                            iconColor: AppTheme.statusArmed,
                            title: 'Camera',
                            subtitle: _devices.isEmpty ? 'Chưa kết nối' : 'Hoạt động',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            icon: Icons.wifi_rounded,
                            iconColor: _serverOnline ? AppTheme.statusArmed : AppTheme.statusAlarm,
                            title: 'Kết nối',
                            subtitle: _serverOnline ? 'Tốt' : 'Mất mạng',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            icon: Icons.battery_charging_full_rounded,
                            iconColor: AppTheme.statusArmed,
                            title: 'Pin',
                            subtitle: '87%',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            icon: Icons.sd_storage_outlined,
                            iconColor: AppTheme.primaryNavy,
                            title: 'Lưu trữ',
                            subtitle: '23.6 GB trống',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ==========================================
                    // 3. SỰ KIỆN GẦN ĐÂY
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sự kiện gần đây',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.headingDark),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AlertsHistoryScreen()),
                            );
                          },
                          child: const Text(
                            'Xem tất cả >',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.royalPurple),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_recentAlerts.isEmpty) ...[
                      _buildEventCard(
                        title: 'Phát hiện người lạ',
                        timeLocation: '10:24 • Camera cửa chính',
                        imageAsset: 'assets/images/sticker_system(6).png',
                        badgeColor: AppTheme.statusAlarm,
                      ),
                      const SizedBox(height: 10),
                      _buildEventCard(
                        title: 'Phát hiện chuyển động',
                        timeLocation: '09:58 • Sân trước',
                        imageAsset: 'assets/images/alter.png',
                        badgeColor: AppTheme.statusWarning,
                      ),
                    ] else ...[
                      ..._recentAlerts.take(3).map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildEventCard(
                          title: a.triggerReason,
                          timeLocation: '${a.deviceName} • ${a.severity}',
                          imageAsset: a.imageUrl ?? 'assets/images/alter.png',
                          badgeColor: a.severity == 'Critical' || a.severity == 'Danger' ? AppTheme.statusAlarm : AppTheme.statusWarning,
                        ),
                      )),
                    ],
                    const SizedBox(height: 20),

                    // ==========================================
                    // 4. CHỨC NĂNG NHANH & 6 TRẠNG THÁI
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Trạng thái bảo vệ & Tạm dừng',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.headingDark),
                        ),
                        TextButton.icon(
                          onPressed: _showSnoozeModal,
                          icon: const Icon(Icons.snooze_rounded, size: 18, color: AppTheme.royalPurple),
                          label: const Text('Tạm nghỉ', style: TextStyle(color: AppTheme.royalPurple, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Horizontal States Carousel (Matching "6 TRẠNG THÁI BẢO VỆ" in image)
                    SizedBox(
                      height: 110,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildStateChip(
                            title: 'Đang bảo vệ',
                            desc: 'Hoạt động tốt',
                            image: 'assets/images/sticker_system(1).png',
                            color: AppTheme.statusArmed,
                          ),
                          _buildStateChip(
                            title: 'Bảo vệ tắt',
                            desc: 'Chế độ chờ',
                            image: 'assets/images/sticker_system(5).png',
                            color: AppTheme.primaryNavy,
                          ),
                          _buildStateChip(
                            title: 'Khởi tạo...',
                            desc: 'Vui lòng chờ',
                            image: 'assets/images/sticker_system(3).png',
                            color: AppTheme.securityBlue,
                          ),
                          _buildStateChip(
                            title: 'Mất camera',
                            desc: 'Kiểm tra quyền',
                            image: 'assets/images/sticker_system(2).png',
                            color: AppTheme.statusWarning,
                          ),
                          _buildStateChip(
                            title: 'Mất kết nối',
                            desc: 'Kiểm tra Wi-Fi',
                            image: 'assets/images/sticker_system(6).png',
                            color: AppTheme.statusAlarm,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderWarm),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.headingDark)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.secondaryText, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard({
    required String title,
    required String timeLocation,
    required String imageAsset,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderWarm),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 52,
              height: 52,
              color: AppTheme.creamBg,
              child: imageAsset.startsWith('http') || imageAsset.startsWith('/evidence')
                  ? Image.network(
                      imageAsset.startsWith('http') ? imageAsset : '${AppConfig.baseUrl}$imageAsset',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset('assets/images/alter.png', fit: BoxFit.cover),
                    )
                  : Image.asset(imageAsset, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.headingDark)),
                const SizedBox(height: 4),
                Text(timeLocation, style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryText),
        ],
      ),
    );
  }

  Widget _buildStateChip({
    required String title,
    required String desc,
    required String image,
    required Color color,
  }) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderWarm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(image, width: 38, height: 38, fit: BoxFit.contain),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color), maxLines: 1),
          Text(desc, style: const TextStyle(fontSize: 9, color: AppTheme.secondaryText), maxLines: 1),
        ],
      ),
    );
  }
}
