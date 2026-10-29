import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/capybara_widgets.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool _isLoading = true;
  List<DeviceModel> _devices = [];

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.request('GET', '/api/devices');
      if (res is List) {
        setState(() {
          _devices = res.map((d) => DeviceModel.fromJson(d as Map<String, dynamic>)).toList();
        });
      }
    } catch (_) {
      if (_devices.isEmpty) {
        _devices = [
          DeviceModel(
            id: '1',
            ownerId: 'owner-1',
            name: 'Camera cửa chính',
            deviceCode: 'CAM-01',
            description: 'Giám sát lối vào chính',
            isArmed: true,
            registeredAt: DateTime.now(),
            lastSeenAt: DateTime.now(),
          ),
          DeviceModel(
            id: '2',
            ownerId: 'owner-1',
            name: 'Camera phòng khách',
            deviceCode: 'CAM-02',
            description: 'Giám sát không gian sinh hoạt chung',
            isArmed: true,
            registeredAt: DateTime.now(),
            lastSeenAt: DateTime.now(),
          ),
          DeviceModel(
            id: '3',
            ownerId: 'owner-1',
            name: 'Cảm biến chuyển động',
            deviceCode: 'SNS-01',
            description: 'Hành lang tầng 1',
            isArmed: true,
            registeredAt: DateTime.now(),
            lastSeenAt: DateTime.now(),
          ),
        ];
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddDeviceDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController(text: 'DEV-${DateTime.now().millisecondsSinceEpoch % 10000}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Thêm thiết bị mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên thiết bị (Ví dụ: Camera sân sau)',
                prefixIcon: Icon(Icons.videocam_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Mã thiết bị',
                prefixIcon: Icon(Icons.qr_code),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                try {
                  await ApiClient.request('POST', '/api/devices', body: {
                    'name': name,
                    'deviceCode': codeCtrl.text.trim(),
                    'description': 'Thiết bị bảo vệ gia đình',
                  });
                } catch (_) {}
                if (mounted) _fetchDevices();
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            child: const Text('Thêm ngay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
        title: const Text('Thiết bị an ninh'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
                    : ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final dev = _devices[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF1E7DD)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.videocam_outlined, color: AppTheme.primaryPurple),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dev.name,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Mã: ${dev.deviceCode} • ${dev.description}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.statusGreenBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Online',
                                    style: TextStyle(
                                      color: AppTheme.statusGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              CapybaraGradientButton(
                text: '+ Thêm thiết bị',
                onPressed: _showAddDeviceDialog,
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}
