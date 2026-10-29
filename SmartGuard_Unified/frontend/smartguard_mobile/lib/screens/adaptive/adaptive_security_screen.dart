import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';

class AdaptiveSecurityScreen extends StatefulWidget {
  const AdaptiveSecurityScreen({super.key});

  @override
  State<AdaptiveSecurityScreen> createState() => _AdaptiveSecurityScreenState();
}

class _AdaptiveSecurityScreenState extends State<AdaptiveSecurityScreen> {
  bool _isLoading = true;
  List<AdaptiveProfileModel> _profiles = [];
  AdaptiveProfileModel? _selectedProfile;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.request('GET', '/api/adaptive/profiles') as List<dynamic>;
      if (mounted) {
        final list = res.map((e) => AdaptiveProfileModel.fromJson(e as Map<String, dynamic>)).toList();
        setState(() {
          _profiles = list;
          _selectedProfile = list.firstWhere(
            (p) => p.isActive,
            orElse: () => list.isNotEmpty ? list.first : AdaptiveProfileModel(id: '', modeName: 'Home', displayName: 'Ở nhà', description: ''),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải cấu hình: $e'), backgroundColor: AppTheme.statusAlarm),
        );
      }
    }
  }

  Future<void> _activateProfile(AdaptiveProfileModel profile) async {
    try {
      await ApiClient.request('POST', '/api/adaptive/profiles/${profile.id}/activate');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã kích hoạt chế độ: ${profile.displayName}'),
          backgroundColor: AppTheme.statusArmed,
        ),
      );
      _loadProfiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi kích hoạt: $e'), backgroundColor: AppTheme.statusAlarm),
      );
    }
  }

  Future<void> _snoozeAlerts(int minutes) async {
    try {
      final res = await ApiClient.request('POST', '/api/adaptive/snooze', body: {'minutes': minutes}) as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Đã tạm dừng cảnh báo.'),
          backgroundColor: AppTheme.statusWarning,
        ),
      );
      _loadProfiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạm dừng: $e'), backgroundColor: AppTheme.statusAlarm),
      );
    }
  }

  Future<void> _cancelSnooze() async {
    try {
      await ApiClient.request('POST', '/api/adaptive/cancel-snooze');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy tạm dừng. Hệ thống tiếp tục canh gác bình thường.'),
          backgroundColor: AppTheme.statusArmed,
        ),
      );
      _loadProfiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi hủy tạm dừng: $e'), backgroundColor: AppTheme.statusAlarm),
      );
    }
  }

  Future<void> _saveProfileChanges() async {
    if (_selectedProfile == null) return;
    try {
      await ApiClient.request('PUT', '/api/adaptive/profiles/${_selectedProfile!.id}', body: {
        'displayName': _selectedProfile!.displayName,
        'description': _selectedProfile!.description,
        'activeFrom': _selectedProfile!.activeFrom,
        'activeTo': _selectedProfile!.activeTo,
        'behaviorOnDisconnect': _selectedProfile!.behaviorOnDisconnect,
        'zoneRules': _selectedProfile!.zoneRules.map((r) => r.toJson()).toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu cấu hình chế độ an ninh thích ứng thành công!'),
          backgroundColor: AppTheme.statusArmed,
        ),
      );
      _loadProfiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu cấu hình: $e'), backgroundColor: AppTheme.statusAlarm),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giám sát An ninh Thích ứng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfiles,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header description
                  const Text(
                    'Kịch bản An ninh Thích ứng (Smart Adaptive)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Hệ thống tự động điều chỉnh độ nhạy, khu vực giám sát và kênh cảnh báo theo trạng thái sinh hoạt thực tế của gia đình.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  // Three Mode Selector Cards
                  Row(
                    children: _profiles.map((p) {
                      final isSelected = _selectedProfile?.id == p.id;
                      final isActive = p.isActive;

                      final (icon, color) = switch (p.modeName) {
                        'Home' => (Icons.home_outlined, AppTheme.statusArmed),
                        'Away' => (Icons.directions_walk_outlined, AppTheme.statusWarning),
                        'Night' => (Icons.nightlight_outlined, const Color(0xFF8B5CF6)),
                        _ => (Icons.shield_outlined, AppTheme.primaryBlue),
                      };

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedProfile = p),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? color : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Icon(icon, color: color, size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  p.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isSelected ? color : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'ĐANG BẬT',
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Active / Activate Control
                  if (_selectedProfile != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Chế độ: ${_selectedProfile!.displayName}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedProfile!.description,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_selectedProfile!.isActive)
                                  ElevatedButton(
                                    onPressed: () => _activateProfile(_selectedProfile!),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                    child: const Text('Kích hoạt', style: TextStyle(fontSize: 13)),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.statusArmed.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, color: AppTheme.statusArmed, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Đang kích hoạt',
                                          style: TextStyle(color: AppTheme.statusArmed, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            // Temporary Snooze / Pause Section
                            if (_selectedProfile!.isActive) ...[
                              const Divider(height: 24),
                              Row(
                                children: [
                                  const Icon(Icons.snooze, color: AppTheme.statusWarning, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedProfile!.isSnoozed
                                          ? 'Đang tạm dừng đến: ${_selectedProfile!.snoozeUntil!.toLocal().toString().substring(11, 16)}'
                                          : 'Tạm dừng cảnh báo an ninh tạm thời:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedProfile!.isSnoozed ? AppTheme.statusWarning : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (_selectedProfile!.isSnoozed)
                                    TextButton(
                                      onPressed: _cancelSnooze,
                                      child: const Text('Hủy tạm dừng', style: TextStyle(color: AppTheme.statusAlarm)),
                                    ),
                                ],
                              ),
                              if (!_selectedProfile!.isSnoozed) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ActionChip(
                                      label: const Text('15 phút'),
                                      onPressed: () => _snoozeAlerts(15),
                                    ),
                                    ActionChip(
                                      label: const Text('30 phút'),
                                      onPressed: () => _snoozeAlerts(30),
                                    ),
                                    ActionChip(
                                      label: const Text('60 phút'),
                                      onPressed: () => _snoozeAlerts(60),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Disconnect Behavior setting
                    const Text('Hành vi khi mất kết nối máy chủ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedProfile!.behaviorOnDisconnect,
                            items: const [
                              DropdownMenuItem(value: 'AlertOffline', child: Text('Thông báo thiết bị Offline lên ứng dụng')),
                              DropdownMenuItem(value: 'FailSecure', child: Text('Bật báo động còi tại chỗ nếu camera bị ngắt')),
                              DropdownMenuItem(value: 'MaintainState', child: Text('Giữ nguyên trạng thái canh gác cục bộ')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  // Update local state
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Zone Rules Customization
                    const Text('Quy tắc chi tiết từng Khu vực (Zones)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),

                    if (_selectedProfile!.zoneRules.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Chưa có phân vùng nào. Hãy vào mục Khu vực để tạo các phòng trước.'),
                        ),
                      )
                    else
                      ..._selectedProfile!.zoneRules.map((rule) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.meeting_room, color: AppTheme.primaryBlue, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        rule.zoneName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                    Switch(
                                      value: rule.enableMonitoring,
                                      activeThumbColor: AppTheme.statusArmed,
                                      onChanged: (val) {
                                        setState(() => rule.enableMonitoring = val);
                                      },
                                    ),
                                  ],
                                ),
                                if (rule.enableMonitoring) ...[
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Độ nhạy phát hiện: x${rule.customSensitivity.toStringAsFixed(1)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        rule.customSensitivity >= 1.4 ? 'Rất nhạy' : (rule.customSensitivity <= 0.8 ? 'Giảm nhạy' : 'Tiêu chuẩn'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: rule.customSensitivity >= 1.4 ? AppTheme.statusAlarm : const Color(0xFF64748B),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Slider(
                                    value: rule.customSensitivity,
                                    min: 0.5,
                                    max: 2.0,
                                    divisions: 15,
                                    activeColor: AppTheme.primaryBlue,
                                    onChanged: (val) {
                                      setState(() => rule.customSensitivity = val);
                                    },
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Còi báo động', style: TextStyle(fontSize: 12)),
                                          value: rule.enableAlarmSound,
                                          onChanged: (val) => setState(() => rule.enableAlarmSound = val ?? true),
                                        ),
                                      ),
                                      Expanded(
                                        child: CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Báo Discord', style: TextStyle(fontSize: 12)),
                                          value: rule.enableDiscordNotification,
                                          onChanged: (val) => setState(() => rule.enableDiscordNotification = val ?? true),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(
                                      '🚫 Khu vực này được miễn trừ cảnh báo trong chế độ hiện tại.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saveProfileChanges,
                      icon: const Icon(Icons.save),
                      label: const Text('Lưu cấu hình chế độ thích ứng'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }
}
