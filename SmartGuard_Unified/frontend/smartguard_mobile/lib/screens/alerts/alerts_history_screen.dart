import 'package:flutter/material.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/alert_service.dart';
import '../../widgets/capybara_widgets.dart';

class AlertsHistoryScreen extends StatefulWidget {
  const AlertsHistoryScreen({super.key});

  @override
  State<AlertsHistoryScreen> createState() => _AlertsHistoryScreenState();
}

class _AlertsHistoryScreenState extends State<AlertsHistoryScreen> {
  bool _isLoading = true;
  List<AlertModel> _alerts = [];
  String _selectedFilter = 'Tất cả';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);
    try {
      final alerts = await AlertService.getAlertHistory(limit: 100);
      setState(() => _alerts = alerts);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AlertModel> get _filteredAlerts {
    final now = DateTime.now();
    return _alerts.where((a) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = a.title.toLowerCase().contains(q) ||
            a.description.toLowerCase().contains(q) ||
            a.deviceName.toLowerCase().contains(q);
        if (!match) return false;
      }

      if (_selectedFilter == 'Hôm nay') {
        return a.triggeredAt.year == now.year &&
            a.triggeredAt.month == now.month &&
            a.triggeredAt.day == now.day;
      } else if (_selectedFilter == 'Hôm qua') {
        final yesterday = now.subtract(const Duration(days: 1));
        return a.triggeredAt.year == yesterday.year &&
            a.triggeredAt.month == yesterday.month &&
            a.triggeredAt.day == yesterday.day;
      } else if (_selectedFilter == '7 ngày') {
        return now.difference(a.triggeredAt).inDays <= 7;
      }
      return true;
    }).toList();
  }

  Color _getSeverityColor(String type) {
    final t = type.toUpperCase();
    if (t.contains('STRANGER') || t.contains('FACE') || t.contains('HIGH')) {
      return AppTheme.statusDanger;
    }
    if (t.contains('CHUYEN_DONG') || t.contains('MOTION')) {
      return AppTheme.warmAmber;
    }
    if (t.contains('TIENG_ON') || t.contains('NOISE')) {
      return AppTheme.primaryPurple;
    }
    return Colors.blueAccent;
  }

  IconData _getSeverityIcon(String type) {
    final t = type.toUpperCase();
    if (t.contains('STRANGER') || t.contains('FACE')) {
      return Icons.person_search;
    }
    if (t.contains('CHUYEN_DONG') || t.contains('MOTION')) {
      return Icons.directions_run;
    }
    if (t.contains('TIENG_ON') || t.contains('NOISE')) {
      return Icons.volume_up;
    }
    return Icons.settings_backup_restore;
  }

  void _showDetailDialog(AlertModel alert) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getSeverityColor(alert.triggerReason).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_getSeverityIcon(alert.triggerReason), color: _getSeverityColor(alert.triggerReason), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                alert.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (alert.imageUrl != null && alert.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    '${AppConfig.baseUrl}/evidence/${alert.imageUrl}',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Text('Không thể tải ảnh bằng chứng', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Thiết bị: ${alert.deviceName} ${alert.zoneName != null ? "(${alert.zoneName})" : ""}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                alert.description,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Thời điểm: ${alert.triggeredAt.hour.toString().padLeft(2, '0')}:${alert.triggeredAt.minute.toString().padLeft(2, '0')} - ${alert.triggeredAt.day}/${alert.triggeredAt.month}/${alert.triggeredAt.year}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: alert.isResolved ? AppTheme.statusGreenBg : AppTheme.statusDangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alert.isResolved ? '✓ Đã xử lý (${alert.status})' : '⚠️ Trạng thái: Chưa xử lý',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: alert.isResolved ? AppTheme.statusGreen : AppTheme.statusDanger,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
          if (!alert.isResolved)
            ElevatedButton(
              onPressed: () async {
                try {
                  // Gọi API POST /api/alerts/{id}/action
                  await AlertService.acknowledgeAlert(alert.id, action: 'known');
                  if (mounted) _fetchAlerts();
                } catch (_) {}
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.statusGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Xác nhận an toàn (Người quen)'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmCream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lịch sử',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppTheme.primaryPurple),
                        onPressed: _fetchAlerts,
                      ),
                      const CapybaraAvatar(size: 38),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm sự kiện, camera, khu vực...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primaryPurple),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFEADBCE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFEADBCE)),
                  ),
                ),
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: ['Tất cả', 'Hôm nay', 'Hôm qua', '7 ngày'].map((chip) {
                  final isSelected = _selectedFilter == chip;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(chip),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryPurple,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryPurple : const Color(0xFFEADBCE),
                        ),
                      ),
                      onSelected: (_) => setState(() => _selectedFilter = chip),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Alerts List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
                  : _filteredAlerts.isEmpty
                      ? const CapybaraEmptyState(
                          title: 'Không có cảnh báo nào',
                          message: 'Mọi phân vùng đều yên bình và được bảo vệ cẩn mật.',
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchAlerts,
                          color: AppTheme.primaryPurple,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemCount: _filteredAlerts.length,
                            itemBuilder: (context, index) {
                              final alert = _filteredAlerts[index];
                              final color = _getSeverityColor(alert.triggerReason);
                              final icon = _getSeverityIcon(alert.triggerReason);

                              return GestureDetector(
                                onTap: () => _showDetailDialog(alert),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: alert.isResolved ? const Color(0xFFF1E7DD) : AppTheme.statusDanger.withValues(alpha: 0.3),
                                      width: alert.isResolved ? 1.0 : 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(icon, color: color, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              alert.title,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${alert.deviceName} • ${alert.description}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${alert.triggeredAt.hour.toString().padLeft(2, '0')}:${alert.triggeredAt.minute.toString().padLeft(2, '0')} • ${alert.triggeredAt.day}/${alert.triggeredAt.month}',
                                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
