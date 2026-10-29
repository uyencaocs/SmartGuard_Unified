import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/capybara_widgets.dart';

class CameraGuardScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const CameraGuardScreen({super.key, this.onTabChange});

  @override
  State<CameraGuardScreen> createState() => _CameraGuardScreenState();
}

class _CameraGuardScreenState extends State<CameraGuardScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _isMuted = false;
  bool _isMicActive = false;
  bool _isCapturing = false;
  String _selectedCameraName = 'Camera cửa chính';

  List<AlertModel> _cameraEvents = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
    _fetchCameraEvents();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _cameraController = CameraController(
          _cameras.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraReady = true);
      }
    } catch (_) {
      // If camera hardware not available (e.g. simulator/no permission), use simulated feed
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  Future<void> _fetchCameraEvents() async {
    try {
      final res = await ApiClient.request('GET', '/api/alerts', queryParams: {
        'page': '1',
        'pageSize': '4',
      });
      if (res is Map<String, dynamic> && res['items'] is List) {
        setState(() {
          _cameraEvents = (res['items'] as List)
              .map((a) => AlertModel.fromJson(a as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _takeSnapshot() async {
    setState(() => _isCapturing = true);
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppTheme.statusGreen,
          content: const Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('🐾 Capybara đã chụp và lưu ảnh bằng chứng an ninh!')),
            ],
          ),
        ),
      );
    }
  }

  void _triggerPanicSiren() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.statusDanger),
            SizedBox(width: 8),
            Text('Kích hoạt Còi hú?'),
          ],
        ),
        content: const Text(
          'Hệ thống sẽ phát âm thanh cảnh báo lớn và gửi thông báo khẩn cấp tới tất cả thành viên trong nhà.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 ĐÃ PHÁT CÒI HÚ CẢNH BÁO AN NINH!'),
                  backgroundColor: AppTheme.statusDanger,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusDanger),
            child: const Text('Phát còi ngay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF1E7DD)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCameraName,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            items: [
                              'Camera cửa chính',
                              'Camera sân trước',
                              'Camera phòng khách',
                            ].map((name) {
                              return DropdownMenuItem(value: name, child: Text(name));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCameraName = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  // LIVE Indicator Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.statusGreenBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.statusGreen),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: AppTheme.statusGreen, size: 10),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: AppTheme.statusGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Camera Viewport Frame
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.black87,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Camera feed or fallback simulation
                      if (_isCameraReady && _cameraController != null)
                        CameraPreview(_cameraController!)
                      else
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2C3E50), Color(0xFF000000)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CapybaraAvatar(size: 64),
                                const SizedBox(height: 10),
                                Text(
                                  _selectedCameraName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Mô phỏng luồng trực tiếp HD 1080p',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Live overlay elements
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'REC ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Capybara Shield Watermark at bottom right
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CapybaraAvatar(size: 20),
                              SizedBox(width: 4),
                              Text(
                                'SmartGuard AI',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Control Action Bar (Mute, Mic, Capture, Fullscreen, Panic)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1E7DD)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: _isMuted ? AppTheme.statusDanger : AppTheme.primaryPurple,
                      ),
                      tooltip: 'Âm thanh',
                      onPressed: () => setState(() => _isMuted = !_isMuted),
                    ),
                    IconButton(
                      icon: Icon(
                        _isMicActive ? Icons.mic : Icons.mic_none,
                        color: _isMicActive ? AppTheme.primaryCoral : AppTheme.primaryPurple,
                      ),
                      tooltip: 'Đàm thoại 2 chiều',
                      onPressed: () {
                        setState(() => _isMicActive = !_isMicActive);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isMicActive ? 'Đang mở micro đàm thoại...' : 'Đã tắt micro'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: _isCapturing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt, color: AppTheme.primaryPurple),
                      tooltip: 'Chụp ảnh bằng chứng',
                      onPressed: _isCapturing ? null : _takeSnapshot,
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen, color: AppTheme.primaryPurple),
                      tooltip: 'Toàn màn hình',
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_active, color: AppTheme.statusDanger),
                      tooltip: 'Còi hú báo động',
                      onPressed: _triggerPanicSiren,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Timeline / Recent events under camera
              const Text(
                'Sự kiện gần đây tại phân vùng',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              if (_cameraEvents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF1E7DD)),
                  ),
                  child: const Row(
                    children: [
                      CapybaraAvatar(size: 36),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Không có phát hiện bất thường nào gần đây.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: _cameraEvents.map((e) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1E7DD)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.statusGreenBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.videocam, color: AppTheme.statusGreen, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')} - ${e.description}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 18),
              CapybaraGradientButton(
                text: 'Xem lịch sử đầy đủ',
                onPressed: () => widget.onTabChange?.call(1),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
