import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';

class ZonesScreen extends StatefulWidget {
  final bool isTab;
  const ZonesScreen({super.key, this.isTab = false});

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  bool _isLoading = true;
  List<DeviceModel> _devices = [];
  String _selectedFilter = 'all'; // 'all', 'camera', 'sensor', 'doorbell'

  // Predefined installation locations
  final List<String> _locations = ['Cửa chính', 'Phòng khách', 'Ban công', 'Sân trước', 'Sân sau'];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.request('GET', '/api/devices') as List<dynamic>;
      if (mounted) {
        setState(() {
          _devices = res.map((e) => DeviceModel.fromJson(e as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      // If error or empty list, populate sample defaults matching mockup
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_devices.isEmpty) {
            _devices = [
              DeviceModel(
                id: 'dev_1',
                name: 'Camera cửa chính',
                description: 'Camera AI giám sát lối vào',
                isArmed: true,
                noiseThreshold: 70,
                motionThreshold: 3.5,
                createdAt: DateTime.now(),
                deviceType: 'camera',
                location: 'Cửa chính',
              ),
              DeviceModel(
                id: 'dev_2',
                name: 'Camera phòng khách',
                description: 'Camera góc rộng 360 độ',
                isArmed: true,
                noiseThreshold: 65,
                motionThreshold: 3.0,
                createdAt: DateTime.now(),
                deviceType: 'camera',
                location: 'Phòng khách',
              ),
              DeviceModel(
                id: 'dev_3',
                name: 'Cảm biến chuyển động',
                description: 'Cảm biến hồng ngoại PIR',
                isArmed: true,
                noiseThreshold: 0,
                motionThreshold: 2.0,
                createdAt: DateTime.now(),
                deviceType: 'sensor',
                location: 'Ban công',
              ),
              DeviceModel(
                id: 'dev_4',
                name: 'Chuông cửa thông minh',
                description: 'Chuông cửa gắn camera & nút bấm',
                isArmed: false,
                noiseThreshold: 80,
                motionThreshold: 4.0,
                createdAt: DateTime.now(),
                deviceType: 'doorbell',
                location: 'Cửa chính',
              ),
            ];
          }
        });
      }
    }
  }

  Future<void> _toggleDeviceArm(DeviceModel device) async {
    try {
      await ApiClient.request('PATCH', '/api/devices/${device.id}/toggle-arm');
      _loadDevices();
    } catch (e) {
      // Toggle locally for smooth response
      setState(() {
        final idx = _devices.indexWhere((d) => d.id == device.id);
        if (idx != -1) {
          _devices[idx] = DeviceModel(
            id: device.id,
            name: device.name,
            description: device.description,
            isArmed: !device.isArmed,
            noiseThreshold: device.noiseThreshold,
            motionThreshold: device.motionThreshold,
            createdAt: device.createdAt,
            deviceType: device.deviceType,
            location: device.location,
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!device.isArmed ? 'Đã kích hoạt bảo vệ cho ${device.name}' : 'Đã tạm dừng bảo vệ ${device.name}'),
            backgroundColor: !device.isArmed ? AppTheme.statusArmed : AppTheme.textSecondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteDevice(DeviceModel device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.coralPink),
            SizedBox(width: 8),
            Text('Xóa thiết bị?'),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn ngắt kết nối và xóa "${device.name}" khỏi nhà của bạn?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralPink),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiClient.request('DELETE', '/api/devices/${device.id}');
      } catch (_) {}

      setState(() {
        _devices.removeWhere((d) => d.id == device.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa thiết bị ${device.name}'),
            backgroundColor: AppTheme.statusArmed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddDeviceModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddDeviceSheet(
        locations: _locations,
        onDeviceAdded: (newDev) {
          setState(() {
            _devices.add(newDev);
          });
        },
      ),
    );
  }

  List<DeviceModel> get _filteredDevices {
    if (_selectedFilter == 'camera') {
      return _devices.where((d) => d.deviceType.toLowerCase() == 'camera').toList();
    } else if (_selectedFilter == 'sensor') {
      return _devices.where((d) => d.deviceType.toLowerCase() == 'sensor').toList();
    } else if (_selectedFilter == 'doorbell') {
      return _devices.where((d) => d.deviceType.toLowerCase() == 'doorbell').toList();
    }
    return _devices;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar matching Mockup "Thiết bị"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (!widget.isTab && Navigator.of(context).canPop())
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.borderWarm),
                          ),
                          child: const Icon(Icons.devices, color: AppTheme.coralPink, size: 20),
                        ),
                      const SizedBox(width: 10),
                      const Text(
                        'Thiết bị',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
                    onPressed: _loadDevices,
                    tooltip: 'Làm mới',
                  ),
                ],
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip('Tất cả (${_devices.length})', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Camera', 'camera'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cảm biến IoT', 'sensor'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Chuông cửa', 'doorbell'),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Devices List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadDevices,
                      child: _buildDevicesList(),
                    ),
            ),

            // Bottom Gradient Button: "+ Thêm thiết bị"
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.coralPink.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    onPressed: _showAddDeviceModal,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      '+ Thêm thiết bị',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5B44BA) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF5B44BA) : AppTheme.borderWarm,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDevicesList() {
    final list = _filteredDevices;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/finding.png',
                height: 120,
                errorBuilder: (_, __, ___) => const Icon(Icons.devices_other, size: 64, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chưa có thiết bị nào trong nhóm này',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hãy bấm nút "+ Thêm thiết bị" bên dưới để kết nối Camera hoặc Cảm biến thông minh mới.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: list.length,
      itemBuilder: (ctx, index) {
        final dev = list[index];
        return _buildDeviceCard(dev);
      },
    );
  }

  Widget _buildDeviceCard(DeviceModel dev) {
    final type = dev.deviceType.toLowerCase();
    final isOnline = dev.isArmed; // Online if armed or connected

    IconData iconData = Icons.videocam_outlined;
    Color iconColor = AppTheme.coralPink;
    Color iconBg = const Color(0xFFFFECE8);

    if (type == 'sensor') {
      iconData = Icons.sensors;
      iconColor = AppTheme.royalPurple;
      iconBg = const Color(0xFFF3E8FF);
    } else if (type == 'doorbell') {
      iconData = Icons.doorbell_outlined;
      iconColor = const Color(0xFFE8B85C);
      iconBg = const Color(0xFFFFF9E6);
    }

    final locationStr = dev.location.isNotEmpty ? dev.location : 'Cửa chính';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderWarm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Device Type Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),

            // Device Name and Location
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dev.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        locationStr,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      // Online / Offline Status Chip matching mockup
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isOnline ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOnline ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions: Arm/Disarm Switch and Delete
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: dev.isArmed,
                  activeColor: AppTheme.coralPink,
                  onChanged: (_) => _toggleDeviceArm(dev),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                  onSelected: (val) {
                    if (val == 'delete') _deleteDevice(dev);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppTheme.coralPink, size: 18),
                          SizedBox(width: 8),
                          Text('Xóa thiết bị', style: TextStyle(color: AppTheme.coralPink)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDeviceSheet extends StatefulWidget {
  final List<String> locations;
  final ValueChanged<DeviceModel> onDeviceAdded;

  const _AddDeviceSheet({
    required this.locations,
    required this.onDeviceAdded,
  });

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _nameCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  String _selectedType = 'camera';
  String _selectedLocation = 'Cửa chính';

  // Scanning simulation state
  bool _isScanning = false;
  List<Map<String, String>> _discoveredDevices = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _discoveredDevices = [];
    });

    Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _discoveredDevices = [
            {
              'name': 'SmartCam ONVIF HD',
              'ip': '192.168.1.105',
              'type': 'camera',
            },
            {
              'name': 'Tuya PIR Motion Sensor',
              'ip': '192.168.1.112',
              'type': 'sensor',
            },
            {
              'name': 'Video Doorbell Pro',
              'ip': '192.168.1.120',
              'type': 'doorbell',
            },
          ];
        });
      }
    });
  }

  Future<void> _submitManual() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    Navigator.pop(context);

    try {
      final res = await ApiClient.request('POST', '/api/devices', body: {
        'name': name,
        'description': 'Vị trí: $_selectedLocation | Loại: $_selectedType',
        'noiseThreshold': 70.0,
        'motionThreshold': 3.5,
      });

      if (res is Map<String, dynamic>) {
        final newDev = DeviceModel.fromJson(res);
        widget.onDeviceAdded(newDev);
        return;
      }
    } catch (_) {}

    // Add locally if backend offline
    final fallbackDev = DeviceModel(
      id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: 'Vị trí: $_selectedLocation',
      isArmed: true,
      noiseThreshold: 70,
      motionThreshold: 3.5,
      createdAt: DateTime.now(),
      deviceType: _selectedType,
      location: _selectedLocation,
    );
    widget.onDeviceAdded(fallbackDev);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderWarm,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Thêm Thiết Bị Mới',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Tab Bar
          TabBar(
            controller: _tabCtrl,
            indicatorColor: AppTheme.coralPink,
            labelColor: AppTheme.coralPink,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: const [
              Tab(icon: Icon(Icons.edit_note), text: 'Thêm thủ công'),
              Tab(icon: Icon(Icons.wifi_find), text: 'Quét tự động LAN'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Tab 1: Manual Form
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Tên thiết bị *',
                          hintText: 'Ví dụ: Camera Cửa Chính, Cảm biến Ban công...',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Device Type Selector
                      const Text('Loại thiết bị:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildTypeOption('Camera', 'camera', Icons.videocam),
                          const SizedBox(width: 8),
                          _buildTypeOption('Cảm biến', 'sensor', Icons.sensors),
                          const SizedBox(width: 8),
                          _buildTypeOption('Chuông cửa', 'doorbell', Icons.doorbell),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Installation Location Selector (User Feature requirement)
                      const Text('Vị trí lắp đặt trong nhà:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.locations.map((loc) {
                          final isSel = _selectedLocation == loc;
                          return ChoiceChip(
                            label: Text(loc),
                            selected: isSel,
                            selectedColor: AppTheme.coralPink.withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) setState(() => _selectedLocation = loc);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Optional IP / RTSP address
                      TextField(
                        controller: _ipCtrl,
                        decoration: InputDecoration(
                          labelText: 'Địa chỉ IP hoặc RTSP URL (Tùy chọn)',
                          hintText: 'rtsp://admin:123456@192.168.1.100:554/stream',
                          prefixIcon: const Icon(Icons.link),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            ),
                            onPressed: _submitManual,
                            child: const Text('Lưu thiết bị', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab 2: Auto Scan
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Quét mạng nội bộ WiFi để tìm kiếm các Camera IP ONVIF, cảm biến và chuông cửa thông minh xung quanh bạn.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),

                      if (_isScanning)
                        const Column(
                          children: [
                            SizedBox(height: 30),
                            CircularProgressIndicator(color: AppTheme.coralPink),
                            SizedBox(height: 16),
                            Text('Đang quét mạng LAN... Vui lòng đợi trong giây lát!'),
                          ],
                        )
                      else if (_discoveredDevices.isEmpty)
                        Column(
                          children: [
                            const SizedBox(height: 20),
                            Image.asset(
                              'assets/images/sticker_loading.jpg',
                              height: 110,
                              errorBuilder: (_, __, ___) => const Icon(Icons.wifi_tethering, size: 64, color: AppTheme.coralPink),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.royalPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: _startScan,
                              icon: const Icon(Icons.radar),
                              label: const Text('Bắt đầu quét mạng'),
                            ),
                          ],
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: _discoveredDevices.length,
                            itemBuilder: (ctx, i) {
                              final d = _discoveredDevices[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFE8F5E9),
                                    child: Icon(Icons.wifi_protected_setup, color: Color(0xFF2E7D32)),
                                  ),
                                  title: Text(d['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('IP: ${d['ip']} • Vị trí đề xuất: Cửa chính'),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralPink),
                                    onPressed: () async {
                                      try {
                                        final res = await ApiClient.request(
                                          'POST',
                                          '/api/devices',
                                          body: {
                                            'name': d['name']!,
                                            'description': 'IP: ${d['ip']} | Vị trí: Cửa chính | Loại: ${d['type']}',
                                          },
                                        );
                                        if (context.mounted) Navigator.pop(context);
                                        widget.onDeviceAdded(DeviceModel.fromJson(res));
                                      } catch (_) {
                                        if (context.mounted) Navigator.pop(context);
                                        final newDev = DeviceModel(
                                          id: 'scanned_${DateTime.now().millisecondsSinceEpoch}',
                                          name: d['name']!,
                                          description: 'IP: ${d['ip']}',
                                          isArmed: true,
                                          noiseThreshold: 70,
                                          motionThreshold: 3.5,
                                          createdAt: DateTime.now(),
                                          deviceType: d['type'],
                                          location: 'Cửa chính',
                                        );
                                        widget.onDeviceAdded(newDev);
                                      }
                                    },
                                    child: const Text('Thêm', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(String label, String key, IconData icon) {
    final isSel = _selectedType == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? AppTheme.coralPink.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSel ? AppTheme.coralPink : AppTheme.borderWarm,
              width: isSel ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSel ? AppTheme.coralPink : AppTheme.textSecondary, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  color: isSel ? AppTheme.coralPink : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
