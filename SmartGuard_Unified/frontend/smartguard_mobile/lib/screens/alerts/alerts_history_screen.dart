import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';

class AlertsHistoryScreen extends StatefulWidget {
  const AlertsHistoryScreen({super.key});

  @override
  State<AlertsHistoryScreen> createState() => AlertsHistoryScreenState();
}

class AlertsHistoryScreenState extends State<AlertsHistoryScreen> {
  bool _isLoading = true;
  List<AlertModel> _alerts = [];
  String? _errorMessage;
  Timer? _autoRefreshTimer;

  static const _cacheKey = 'sg_cached_alerts';

  @override
  void initState() {
    super.initState();
    _loadCachedAlerts();
    _loadAlerts();

    // Tự động làm mới dữ liệu định kỳ mỗi 8 giây khi đang xem màn hình
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        _loadAlerts(isSilent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Gọi từ bên ngoài (ví dụ HomeShell khi chuyển tab sang Cảnh báo)
  void reloadAlerts() {
    _loadCachedAlerts();
    _loadAlerts();
  }

  /// Tải dữ liệu lưu cache nội bộ để hiển thị ngay lập tức không bị trắng màn hình
  Future<void> _loadCachedAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty && mounted) {
        final list = (jsonDecode(cached) as List<dynamic>)
            .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() => _alerts = list);
      }
    } catch (_) {}
  }

  /// Gọi API lấy danh sách cảnh báo mới nhất từ máy chủ
  Future<void> _loadAlerts({bool isSilent = false}) async {
    if (!isSilent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final res = await ApiClient.request('GET', '/api/alerts/history?limit=50') as List<dynamic>;
      final list = res.map((e) => AlertModel.fromJson(e as Map<String, dynamic>)).toList();

      // Lưu vào cache local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(res));

      if (mounted) {
        setState(() {
          _alerts = list;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_alerts.isEmpty) {
            _errorMessage = e.toString();
          }
        });
      }
    }
  }

  Future<void> _acknowledgeAlert(String id, String action) async {
    try {
      await ApiClient.request('POST', '/api/alerts/$id/action', body: {'action': action});
      if (!mounted) return;

      String actionMsg = 'Đã cập nhật trạng thái';
      if (action == 'KnownPerson') {
        actionMsg = '✅ Đã xác nhận Người quen - Hệ thống đã tắt báo động và tạm dừng cảnh báo 3 phút';
      } else if (action == 'ConfirmedStranger') {
        actionMsg = '🚨 Đã xác nhận Người lạ xâm nhập!';
      } else if (action == 'Dismiss') {
        actionMsg = 'Đã bỏ qua sự kiện cảnh báo.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionMsg),
          backgroundColor: action == 'ConfirmedStranger' ? AppTheme.statusAlarm : AppTheme.statusArmed,
          duration: const Duration(seconds: 3),
        ),
      );
      _loadAlerts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.statusAlarm),
      );
    }
  }

  void _showEvidenceDialog(AlertModel alert) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Chi tiết sự kiện: ${alert.triggerReason}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thiết bị: ${alert.deviceName}'),
              const SizedBox(height: 4),
              Text('Thời gian: ${alert.triggeredAt.toLocal().toString().substring(0, 19)}'),
              const SizedBox(height: 4),
              Text('Trạng thái hiện tại: ${_statusLabel(alert.status)}'),
              if (alert.adaptiveReason != null && alert.adaptiveReason!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Lý do thích ứng: ${alert.adaptiveReason}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              const SizedBox(height: 12),
              if (alert.imageUrl != null && alert.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    '${AppConfig.baseUrl}${alert.imageUrl}',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Center(child: Text('Không thể tải ảnh bằng chứng')),
                    ),
                  ),
                )
              else
                Container(
                  height: 80,
                  color: Colors.grey.shade100,
                  child: const Center(child: Text('Không có ảnh đính kèm')),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _acknowledgeAlert(alert.id, 'Dismiss');
            },
            child: const Text('Bỏ qua'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusArmed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _acknowledgeAlert(alert.id, 'KnownPerson');
            },
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Người quen'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusAlarm,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _acknowledgeAlert(alert.id, 'ConfirmedStranger');
            },
            icon: const Icon(Icons.warning, size: 16),
            label: const Text('Người lạ'),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'KnownPerson': return 'Người quen';
      case 'ConfirmedStranger': return 'Người lạ';
      case 'Muted': return 'Đã tắt chuông';
      case 'Confirmed': return 'Đã duyệt';
      case 'Dismissed': return 'Đã bỏ qua';
      default: return 'Mới';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'KnownPerson':
      case 'Confirmed': return AppTheme.statusArmed;
      case 'Dismissed':
      case 'Muted': return const Color(0xFF64748B);
      default: return AppTheme.statusAlarm;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử cảnh báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAlerts(),
            tooltip: 'Làm mới lịch sử',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAlerts(),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _alerts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _alerts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              const Text(
                'Không thể tải lịch sử cảnh báo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadAlerts(),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_alerts.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có sự kiện cảnh báo nào được ghi nhận.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return Column(
      children: [
        if (_errorMessage != null)
          Container(
            color: AppTheme.statusAlarm.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.statusAlarm, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đang hiển thị dữ liệu cache. $_errorMessage',
                    style: const TextStyle(fontSize: 12, color: AppTheme.statusAlarm),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final alert = _alerts[index];
              final isCritical = alert.severity.toLowerCase() == 'critical';
              final statusLabel = _statusLabel(alert.status);
              final statusClr = _statusColor(alert.status);

              return Card(
                child: ListTile(
                  onTap: () => _showEvidenceDialog(alert),
                  leading: CircleAvatar(
                    backgroundColor: isCritical
                        ? AppTheme.statusAlarm.withValues(alpha: 0.15)
                        : AppTheme.statusWarning.withValues(alpha: 0.15),
                    child: Icon(
                      isCritical ? Icons.warning_rounded : Icons.info_outline,
                      color: isCritical ? AppTheme.statusAlarm : AppTheme.statusWarning,
                    ),
                  ),
                  title: Text(
                    alert.triggerReason == 'NGUOI_LA'
                        ? 'Phát hiện Người lạ'
                        : (alert.triggerReason == 'RUNG_LAC' ? 'Cảnh báo Rung lắc thiết bị' : alert.triggerReason),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${alert.deviceName} • ${alert.triggeredAt.toLocal().toString().substring(0, 19)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusClr.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusClr,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
