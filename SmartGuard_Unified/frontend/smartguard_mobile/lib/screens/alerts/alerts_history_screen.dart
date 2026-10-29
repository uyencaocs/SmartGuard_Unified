import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/capybara_widgets.dart';

class AlertsHistoryScreen extends StatefulWidget {
  const AlertsHistoryScreen({super.key});

  @override
  State<AlertsHistoryScreen> createState() => _AlertsHistoryScreenState();
}

class _AlertsHistoryScreenState extends State<AlertsHistoryScreen> {
  bool _isLoading = true;
  List<AlertModel> _alerts = [];
  String _selectedFilter = 'Tất cả'; // 'Tất cả', 'Hôm nay', 'Hôm qua', '7 ngày'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.request('GET', '/api/alerts', queryParams: {
        'page': '1',
        'pageSize': '50',
      });

      if (res is Map<String, dynamic> && res['items'] is List) {
        final items = (res['items'] as List)
            .map((item) => AlertModel.fromJson(item as Map<String, dynamic>))
            .toList();
        setState(() => _alerts = items);
      }
    } catch (_) {
      // Mock sample data if backend is offline or empty
      if (_alerts.isEmpty) {
        _alerts = [
          AlertModel(
            id: '1',
            deviceId: 'dev-1',
            alertType: 'Face_Stranger',
            severity: 'High',
            title: 'Phát hiện người lạ',
            description: 'Khuôn mặt chưa định danh tại Camera cửa chính',
            isResolved: false,
            createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
          ),
          AlertModel(
            id: '2',
            deviceId: 'dev-1',
            alertType: 'Motion',
            severity: 'Medium',
            title: 'Phát hiện chuyển động',
            description: 'Chuyển động vượt ngưỡng tại Sân trước',
            isResolved: true,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          AlertModel(
            id: '3',
            deviceId: 'dev-2',
            alertType: 'Noise',
            severity: 'Medium',
            title: 'Âm thanh bất thường',
            description: 'Tiếng ồn lớn 82dB tại Phòng khách',
            isResolved: true,
            createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          ),
          AlertModel(
            id: '4',
            deviceId: 'dev-1',
            alertType: 'System',
            severity: 'Low',
            title: 'Hệ thống khởi động',
            description: 'Capybara Guard đã tự động kích hoạt canh gác',
            isResolved: true,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
      }
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
            a.alertType.toLowerCase().contains(q);
        if (!match) return false;
      }

      if (_selectedFilter == 'Hôm nay') {
        return a.createdAt.year == now.year &&
            a.createdAt.month == now.month &&
            a.createdAt.day == now.day;
      } else if (_selectedFilter == 'Hôm qua') {
        final yesterday = now.subtract(const Duration(days: 1));
        return a.createdAt.year == yesterday.year &&
            a.createdAt.month == yesterday.month &&
            a.createdAt.day == yesterday.day;
      } else if (_selectedFilter == '7 ngày') {
        return now.difference(a.createdAt).inDays <= 7;
      }
      return true;
    }).toList();
  }

  Color _getSeverityColor(String type) {
    if (type.contains('Face') || type.contains('Stranger') || type.contains('High')) {
      return AppTheme.statusDanger;
    }
    if (type.contains('Motion') || type.contains('Warning')) {
      return AppTheme.warmAmber;
    }
    if (type.contains('Noise') || type.contains('Sound')) {
      return AppTheme.primaryPurple;
    }
    return Colors.blueAccent;
  }

  IconData _getSeverityIcon(String type) {
    if (type.contains('Face') || type.contains('Stranger')) {
      return Icons.person_search;
    }
    if (type.contains('Motion')) {
      return Icons.directions_run;
    }
    if (type.contains('Noise') || type.contains('Sound')) {
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
                color: _getSeverityColor(alert.alertType).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_getSeverityIcon(alert.alertType), color: _getSeverityColor(alert.alertType), size: 22),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alert.evidenceImagePath != null && alert.evidenceImagePath!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  '${AppConfig.baseUrl}/evidence/${alert.evidenceImagePath}',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
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
              alert.description,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${alert.createdAt.hour.toString().padLeft(2, '0')}:${alert.createdAt.minute.toString().padLeft(2, '0')} - ${alert.createdAt.day}/${alert.createdAt.month}/${alert.createdAt.year}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: alert.isResolved ? AppTheme.statusGreenBg : AppTheme.statusDangerBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                alert.isResolved ? '✓ Đã xử lý an toàn' : '⚠️ Cảnh báo chưa xử lý',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: alert.isResolved ? AppTheme.statusGreen : AppTheme.statusDanger,
                ),
              ),
            ),
          ],
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
                  await ApiClient.request('PUT', '/api/alerts/${alert.id}/resolve');
                  if (mounted) _fetchAlerts();
                } catch (_) {}
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.statusGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Đánh dấu đã xử lý'),
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
                  hintText: 'Tìm kiếm sự kiện, loại cảnh báo...',
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

            // Filter Chips (Tất cả, Hôm nay, Hôm qua, 7 ngày)
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
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                    )
                  : _filteredAlerts.isEmpty
                      ? const CapybaraEmptyState(
                          title: 'Không có cảnh báo nào',
                          message: 'Mọi phân vùng đều yên bình và được bảo vệ cẩn mật.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          itemCount: _filteredAlerts.length,
                          itemBuilder: (context, index) {
                            final alert = _filteredAlerts[index];
                            final color = _getSeverityColor(alert.alertType);
                            final icon = _getSeverityIcon(alert.alertType);

                            return GestureDetector(
                              onTap: () => _showDetailDialog(alert),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFF1E7DD)),
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
                                          const SizedBox(height: 3),
                                          Text(
                                            alert.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${alert.createdAt.hour.toString().padLeft(2, '0')}:${alert.createdAt.minute.toString().padLeft(2, '0')} • ${alert.createdAt.day}/${alert.createdAt.month}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted,
                                            ),
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
          ],
        ),
      ),
    );
  }
}
