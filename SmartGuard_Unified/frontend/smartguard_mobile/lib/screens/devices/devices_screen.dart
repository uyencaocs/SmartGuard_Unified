import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/device_service.dart';
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
      final devices = await DeviceService.getDevices();
      setState(() => _devices = devices);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDeviceArm(DeviceModel device) async {
    try {
      final res = await DeviceService.toggleArm(device.id);
      final newArm = res['isArmed'] == true;

      setState(() {
        final index = _devices.indexWhere((d) => d.id == device.id);
        if (index != -1) {
          _devices[index] = DeviceModel(
            id: device.id,
            ownerId: device.ownerId,
            zoneId: device.zoneId,
            zoneName: device.zoneName,
            name: device.name,
            deviceCode: device.deviceCode,
            description: device.description,
            isArmed: newArm,
            noiseThreshold: device.noiseThreshold,
            motionThreshold: device.motionThreshold,
            registeredAt: device.registeredAt,
            lastSeenAt: DateTime.now(),
          );
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: newArm ? AppTheme.statusGreen : AppTheme.primaryPurple,
          content: Text(newArm ? '🐾 Đã bật bảo vệ cho [${device.name}]' : 'Đã tắt bảo vệ cho [${device.name}]'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.statusDanger),
      );
    }
  }

  void _showPairDeviceDialog() {
    final codeCtrl = TextEditingController();
    bool isPairing = false;
    String? pairError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                CapybaraAvatar(size: 34),
                SizedBox(width: 10),
                Text('Ghép Nối Thiết Bị', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nhập mã phần cứng in trên nhãn thiết bị camera (Ví dụ: CAM-01 hoặc SNS-01):',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã thiết bị (Device Code)',
                    prefixIcon: Icon(Icons.qr_code, color: AppTheme.primaryPurple),
                    hintText: 'CAM-01',
                  ),
                ),
                if (pairError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    pairError!,
                    style: const TextStyle(color: AppTheme.statusDanger, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isPairing ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isPairing
                    ? null
                    : () async {
                        final code = codeCtrl.text.trim();
                        if (code.isEmpty) return;

                        setDialogState(() {
                          isPairing = true;
                          pairError = null;
                        });

                        try {
                          final res = await DeviceService.pairDevice(code);
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: AppTheme.statusGreen,
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      res['message']?.toString() ?? 'Ghép nối thiết bị thành công!',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          _fetchDevices();
                        } catch (e) {
                          setDialogState(() {
                            isPairing = false;
                            pairError = e.toString().replaceAll('Exception:', '').trim();
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isPairing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Ghép Nối'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddManualDeviceDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Thêm Thiết Bị Mới'),
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
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Vị trí / Mô tả',
                prefixIcon: Icon(Icons.location_on_outlined),
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
                  await DeviceService.createDevice(
                    name: name,
                    description: descCtrl.text.trim(),
                  );
                  if (mounted) _fetchDevices();
                } catch (_) {}
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            child: const Text('Tạo ngay', style: TextStyle(color: Colors.white)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryPurple),
            onPressed: _fetchDevices,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
                    : _devices.isEmpty
                        ? CapybaraEmptyState(
                            title: 'Chưa có thiết bị nào',
                            message: 'Hãy ghép nối camera an ninh hoặc cảm biến để Capybara bắt đầu canh gác.',
                            buttonText: 'Ghép nối camera ngay',
                            onButtonPressed: _showPairDeviceDialog,
                          )
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
                                  border: Border.all(
                                    color: dev.isArmed ? const Color(0xFFC8F3D7) : const Color(0xFFF1E7DD),
                                    width: dev.isArmed ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: dev.isArmed
                                            ? AppTheme.statusGreenBg
                                            : AppTheme.primaryPurple.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.videocam_outlined,
                                        color: dev.isArmed ? AppTheme.statusGreen : AppTheme.primaryPurple,
                                      ),
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
                                          const SizedBox(height: 2),
                                          Text(
                                            'Mã: ${dev.deviceCode} ${dev.zoneName != null ? "• ${dev.zoneName}" : ""}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: dev.isArmed ? AppTheme.statusGreenBg : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  dev.isArmed ? 'Đang bật bảo vệ' : 'Tắt bảo vệ',
                                                  style: TextStyle(
                                                    color: dev.isArmed ? AppTheme.statusGreen : AppTheme.textMuted,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: dev.isArmed,
                                      activeThumbColor: AppTheme.statusGreen,
                                      onChanged: (_) => _toggleDeviceArm(dev),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showPairDeviceDialog,
                      icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryPurple),
                      label: const Text('Ghép Nối Mã'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppTheme.primaryPurple),
                        foregroundColor: AppTheme.primaryPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showAddManualDeviceDialog,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Tạo Thiết Bị'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
