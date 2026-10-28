import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key});

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  bool _isLoading = true;
  List<ZoneModel> _zones = [];
  List<DeviceModel> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final zonesRes = await ApiClient.request('GET', '/api/zones') as List<dynamic>;
      final devicesRes = await ApiClient.request('GET', '/api/devices') as List<dynamic>;

      if (mounted) {
        setState(() {
          _zones = zonesRes.map((e) => ZoneModel.fromJson(e as Map<String, dynamic>)).toList();
          _devices = devicesRes.map((e) => DeviceModel.fromJson(e as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDeviceArm(DeviceModel device) async {
    try {
      await ApiClient.request('PATCH', '/api/devices/${device.id}/toggle-arm');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.statusAlarm),
      );
    }
  }

  void _showAddZoneDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Khu vực mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tên khu vực (ví dụ: Phòng khách)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Mô tả (tùy chọn)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiClient.request('POST', '/api/zones', body: {
                  'name': name,
                  'description': descController.text.trim(),
                });
                _loadData();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi thêm khu vực: $e')),
                );
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khu vực & Thiết bị'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddZoneDialog,
            tooltip: 'Thêm khu vực',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Zones Section
                    const Text('Khu vực phân vùng (Zones)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (_zones.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Chưa có khu vực nào. Hãy nhấn dấu + ở trên để tạo (ví dụ: Phòng khách, Sân trước).'),
                        ),
                      )
                    else
                      ..._zones.map((zone) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE2E8F0),
                                child: Icon(Icons.meeting_room, color: AppTheme.primaryBlue),
                              ),
                              title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(zone.description.isNotEmpty ? zone.description : 'Không có mô tả'),
                              trailing: Chip(
                                label: Text('${zone.deviceCount} camera'),
                                backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.1),
                              ),
                            ),
                          )),

                    const SizedBox(height: 24),

                    // Devices Section
                    const Text('Danh sách thiết bị (Devices)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (_devices.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Chưa có thiết bị nào được liên kết.'),
                        ),
                      )
                    else
                      ..._devices.map((device) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                Icons.videocam_rounded,
                                color: device.isArmed ? AppTheme.statusArmed : AppTheme.statusOffline,
                                size: 30,
                              ),
                              title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Khu vực: ${device.zoneName ?? "Chưa phân"} • Mã: ${device.deviceCode}'),
                              trailing: Switch(
                                value: device.isArmed,
                                activeThumbColor: AppTheme.statusArmed,
                                onChanged: (_) => _toggleDeviceArm(device),
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ),
    );
  }
}
