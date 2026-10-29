import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/tts_service.dart';
import '../admin/admin_screen.dart';

enum GuardMode { always24h, enabled, disabled }

class CameraGuardScreen extends StatefulWidget {
  const CameraGuardScreen({super.key});

  @override
  State<CameraGuardScreen> createState() => _CameraGuardScreenState();
}

class _CameraGuardScreenState extends State<CameraGuardScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  bool _isProcessingFrame = false;

  GuardMode _guardMode = GuardMode.always24h;
  DateTime? _lastAlertTime;
  final int _cooldownSeconds = 15;

  // Trạng thái tạm dừng do người quen / tắt chuông
  DateTime? _snoozeUntil;
  String? _activeAlertId;
  bool _isAlarmActive = false;
  Timer? _alertPollTimer;

  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  List<DeviceModel> _devices = [];
  String? _selectedDeviceId;
  String _statusText = 'Đang khởi tạo camera...';
  Color _statusColor = AppTheme.statusArmed;

  // Điều kiện: Khi có người thì quét mặt, khi không có người thì quét rung lắc
  bool _hasPersonInFrame = false;
  List<KnownPersonModel> _knownPersons = [];
  bool _autoDismissForKnownPersons = true;
  DateTime? _lastKnownPersonNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSystem();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alertPollTimer?.cancel();
    _sensorSubscription?.cancel();
    _cameraController?.dispose();
    _faceDetector.close();
    TtsService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initSystem() async {
    await _loadDevices();
    await _loadKnownPersons();
    await _initCamera();
    _initAccelerometer();
  }

  Future<void> _loadDevices() async {
    try {
      final res = await ApiClient.request('GET', '/api/devices') as List<dynamic>;
      final list = res.map((e) => DeviceModel.fromJson(e as Map<String, dynamic>)).toList();
      if (list.isEmpty) {
        try {
          final newDev = await ApiClient.request('POST', '/api/devices', body: {
            'name': 'Camera Canh Gác Di Động',
            'description': 'Camera AI giám sát nhận diện khuôn mặt',
            'noiseThreshold': 70.0,
            'motionThreshold': 3.5,
          });
          if (newDev is Map<String, dynamic>) {
            list.add(DeviceModel.fromJson(newDev));
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _devices = list;
          if (list.isNotEmpty) {
            _selectedDeviceId = list.first.id;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _initCamera() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        setState(() => _statusText = 'Không tìm thấy camera trên thiết bị.');
        return;
      }

      final camera = _cameras[_selectedCameraIndex];
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
        _statusText = 'Đang canh gác trực tiếp';
        _statusColor = AppTheme.statusArmed;
      });

      await _cameraController!.startImageStream(_processCameraFrame);
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = 'Lỗi camera: $e';
          _statusColor = AppTheme.statusAlarm;
        });
      }
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    setState(() => _isCameraReady = false);
    await _initCamera();
  }

  Future<void> _loadKnownPersons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('sg_known_persons');
      if (str != null && str.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(str);
        if (mounted) {
          setState(() {
            _knownPersons = jsonList.map((e) => KnownPersonModel.fromJson(e as Map<String, dynamic>)).toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveKnownPersons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _knownPersons.map((e) => e.toJson()).toList();
      await prefs.setString('sg_known_persons', jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<void> _quickRegisterCurrentFaceAsKnown() async {
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.face_retouching_natural, color: AppTheme.statusArmed),
            SizedBox(width: 8),
            Text('Đăng ký Người quen'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Lưu người thân vào danh sách. Khi bật "Tự động tắt cảnh báo", hệ thống sẽ KHÔNG báo động khi phát hiện bất kỳ người nào (đã hoặc chưa đăng ký).',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên người quen *',
                prefixIcon: Icon(Icons.person),
                hintText: 'Ví dụ: Anh Nam, Bố, Mẹ...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);

              String? photoUrl;
              try {
                if (_cameraController != null && _cameraController!.value.isInitialized) {
                  final xFile = await _cameraController!.takePicture();
                  final snapFile = File(xFile.path);
                  if (snapFile.existsSync()) {
                    final devId = _selectedDeviceId ?? (_devices.isNotEmpty ? _devices.first.id : null);
                    if (devId != null) {
                      final uploadRes = await ApiClient.uploadFile(
                        '/api/images/upload',
                        snapFile,
                        fields: {'deviceId': devId},
                      );
                      photoUrl = uploadRes['imageUrl']?.toString();
                    }
                  }
                }
              } catch (_) {}

              final newPerson = KnownPersonModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                photoUrl: photoUrl,
                registeredAt: DateTime.now(),
              );

              setState(() {
                _knownPersons.insert(0, newPerson);
              });
              await _saveKnownPersons();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã đăng ký người quen "$name". Camera sẽ tự động tắt cảnh báo khi nhận diện!'),
                    backgroundColor: AppTheme.statusArmed,
                  ),
                );
              }
            },
            child: const Text('Lưu người quen'),
          ),
        ],
      ),
    );
  }

  void _showKnownPersonsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.face_retouching_natural, color: AppTheme.statusArmed, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Danh sách Người quen đã đăng ký',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Tự động tắt cảnh báo khi phát hiện người quen',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                value: _autoDismissForKnownPersons,
                activeThumbColor: AppTheme.statusArmed,
                onChanged: (val) {
                  setState(() => _autoDismissForKnownPersons = val);
                  setSheetState(() {});
                },
              ),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 6),
              if (_knownPersons.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Chưa có người quen nào. Bấm nút bên dưới để chụp ảnh và đăng ký khuôn mặt người thân.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _knownPersons.length,
                    itemBuilder: (_, i) {
                      final p = _knownPersons[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.statusArmed,
                          child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : 'N',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('Đã đăng ký', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: AppTheme.statusAlarm, size: 20),
                          onPressed: () async {
                            setState(() {
                              _knownPersons.removeAt(i);
                            });
                            await _saveKnownPersons();
                            setSheetState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.statusArmed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _quickRegisterCurrentFaceAsKnown();
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Chụp mặt hiện tại làm Người Quen', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initAccelerometer() {
    try {
      _sensorSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          if (_guardMode == GuardMode.disabled) return;
          if (_snoozeUntil != null && DateTime.now().isBefore(_snoozeUntil!)) return;

          // ĐIỀU KIỆN: Khi có người thì quét mặt, còn không có người thì quét rung lắc
          if (_hasPersonInFrame) {
            // Đang có người trước ống kính camera -> ưu tiên quét mặt, bỏ qua rung lắc
            return;
          }

          // Khi KHÔNG CÓ NGƯỜI -> giám sát cảm biến rung lắc chống cạy phá / dịch chuyển
          final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          if (magnitude > 14.5) {
            Vibration.hasVibrator().then((hasVib) {
              if (hasVib == true) Vibration.vibrate(duration: 400);
            });
            _handleSecurityTrigger('RUNG_LAC', magnitude);
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _guardMode == GuardMode.disabled) return;

    // Nếu đang trong thời gian tạm dừng cảnh báo (người quen / tắt chuông)
    if (_snoozeUntil != null && DateTime.now().isBefore(_snoozeUntil!)) {
      // Cập nhật trạng thái hiển thị đang snooze
      if (!_hasPersonInFrame) _hasPersonInFrame = false;
      return;
    }

    _isProcessingFrame = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        // CÓ NGƯỜI TRƯỚC CAMERA → CHẾ ĐỘ QUÉT MẶT
        if (!_hasPersonInFrame) {
          if (mounted) {
            setState(() {
              _hasPersonInFrame = true;
              // Chỉ cập nhật status nếu không đang báo động
              if (!_isAlarmActive) {
                _statusText = '👤 Phát hiện người - Đang phân tích khuôn mặt...';
                _statusColor = AppTheme.statusWarning;
              }
            });
          }
        }

        // CẢNH BÁO: Luôn kích hoạt báo động khi phát hiện khuôn mặt đối tượng trước camera.
        // Người dùng hoặc chủ nhà nhấn nút "Người quen" để tắt cảnh báo và tạm dừng 3 phút.
        _handleSecurityTrigger('NGUOI_LA', 1.0);
      } else {
        // KHÔNG CÓ NGƯỜI TRƯỚC CAMERA → CHUYỂN SANG QUÉT RUNG LẮC
        if (_hasPersonInFrame) {
          if (mounted) {
            setState(() {
              _hasPersonInFrame = false;
            });
          }
        }
        if (!_isAlarmActive && (_snoozeUntil == null || DateTime.now().isAfter(_snoozeUntil!))) {
          if (mounted && _statusText != '🛡️ Không có người - Đang quét rung lắc thiết bị') {
            setState(() {
              _statusText = '🛡️ Không có người - Đang quét rung lắc thiết bị';
              _statusColor = AppTheme.statusArmed;
            });
          }
        }
      }
    } catch (_) {
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_cameras.isEmpty) return null;
    final camera = _cameras[_selectedCameraIndex];
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    final bytes = WriteBuffer();
    for (final plane in image.planes) {
      bytes.putUint8List(plane.bytes);
    }

    return InputImage.fromBytes(
      bytes: bytes.done().buffer.asUint8List(),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _handleSecurityTrigger(String reason, double score) async {
    final now = DateTime.now();

    // Kiểm tra nếu đang snooze
    if (_snoozeUntil != null && now.isBefore(_snoozeUntil!)) {
      final remain = _snoozeUntil!.difference(now).inSeconds;
      setState(() {
        _statusText = 'Đang tạm dừng cảnh báo ($remain s)';
        _statusColor = AppTheme.statusArmed;
      });
      return;
    }

    if (_lastAlertTime != null && now.difference(_lastAlertTime!).inSeconds < _cooldownSeconds) {
      return; // Đang trong thời gian giãn cách chống spam
    }
    _lastAlertTime = now;

    setState(() {
      _isAlarmActive = true;
      _statusText = '🚨 PHÁT HIỆN: $reason!';
      _statusColor = AppTheme.statusAlarm;
    });

    // Phát âm thanh tiếng Việt cảnh báo
    TtsService.playWarningVoice(reason);

    // Chụp ảnh bằng chứng và gửi Backend
    File? snapshotFile;
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final xFile = await _cameraController!.takePicture();
        snapshotFile = File(xFile.path);
      }
    } catch (_) {}

    String? uploadedImageUrl;
    final deviceId = _selectedDeviceId ?? (_devices.isNotEmpty ? _devices.first.id : null);

    if (deviceId != null && snapshotFile != null && snapshotFile.existsSync()) {
      try {
        final uploadRes = await ApiClient.uploadFile(
          '/api/images/upload',
          snapshotFile,
          fields: {'deviceId': deviceId},
        );
        uploadedImageUrl = uploadRes['imageUrl']?.toString();
      } catch (_) {}
    }

    if (deviceId != null) {
      try {
        final res = await ApiClient.request('POST', '/api/alerts/trigger', body: {
          'deviceId': deviceId,
          'triggerReason': reason,
          'triggerScore': score,
          'severity': 'Critical',
          'imageUrl': uploadedImageUrl,
        });

        if (res is Map<String, dynamic>) {
          final alertId = res['alertId']?.toString();
          _activeAlertId = alertId;

          // Lưu sự kiện ngay vào local cache để Lịch sử cảnh báo có ngay lập tức
          await _saveAlertToLocalCache(
            alertId: alertId ?? '',
            reason: reason,
            imageUrl: uploadedImageUrl,
          );

          // Bắt đầu lắng nghe trạng thái từ Discord / Webhook để tắt báo động tự động
          _startAlertStatusPolling(alertId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã gửi bằng chứng sự kiện [$reason] lên Discord & Hệ thống!'),
              backgroundColor: AppTheme.statusAlarm,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (_) {}
    }
  }

  /// Lưu sự kiện vào local cache SharedPreferences
  Future<void> _saveAlertToLocalCache({required String alertId, required String reason, String? imageUrl}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('sg_cached_alerts');
      List<dynamic> list = [];
      if (cachedStr != null && cachedStr.isNotEmpty) {
        try {
          list = jsonDecode(cachedStr) as List<dynamic>;
        } catch (_) {}
      }

      final newAlertMap = {
        'id': alertId.isNotEmpty ? alertId : DateTime.now().millisecondsSinceEpoch.toString(),
        'deviceId': _selectedDeviceId ?? '',
        'deviceName': _devices.isNotEmpty ? _devices.first.name : 'Camera Di Động',
        'zoneName': 'Khu vực chính',
        'triggerReason': reason,
        'triggerScore': 1.0,
        'severity': 'Critical',
        'status': 'Triggered',
        'imageUrl': imageUrl,
        'triggeredAt': DateTime.now().toUtc().toIso8601String(),
        'acknowledgedAt': null,
      };

      list.insert(0, newAlertMap);
      if (list.length > 50) list = list.sublist(0, 50);
      await prefs.setString('sg_cached_alerts', jsonEncode(list));
    } catch (_) {}
  }

  /// Thăm dò trạng thái cảnh báo (khi người dùng bấm Người quen hoặc Tắt chuông trên Discord)
  void _startAlertStatusPolling(String? alertId) {
    _alertPollTimer?.cancel();
    int checkCount = 0;
    final devId = _selectedDeviceId ?? (_devices.isNotEmpty ? _devices.first.id : null);
    if (devId == null) return;

    _alertPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      checkCount++;
      if (checkCount > 45 || !_isAlarmActive) {
        timer.cancel();
        return;
      }
      try {
        final statusRes = await ApiClient.request('GET', '/api/alerts/device/$devId/status');
        if (statusRes is Map<String, dynamic>) {
          final isSnoozed = statusRes['isSnoozed'] == true;
          final latest = statusRes['latestAlert'];
          if (latest is Map<String, dynamic>) {
            final st = latest['status']?.toString();
            if (st == 'KnownPerson') {
              _dismissAlarm(isKnownPerson: true, fromRemote: true);
              timer.cancel();
            } else if (st == 'Muted') {
              _dismissAlarm(isMuted: true, fromRemote: true);
              timer.cancel();
            } else if (st == 'Dismissed') {
              _dismissAlarm(fromRemote: true);
              timer.cancel();
            }
          } else if (isSnoozed) {
            _dismissAlarm(isKnownPerson: true, fromRemote: true);
            timer.cancel();
          }
        }
      } catch (_) {}
    });
  }

  /// Tắt báo động, dừng tiếng hú, tạm dừng cảnh báo 3 phút
  Future<void> _dismissAlarm({bool isKnownPerson = false, bool isMuted = false, bool fromRemote = false}) async {
    _alertPollTimer?.cancel();
    _alertPollTimer = null;
    await TtsService.stop();

    final now = DateTime.now();
    if (isKnownPerson) {
      _snoozeUntil = now.add(const Duration(minutes: 3));
      TtsService.playWarningVoice('NGUOI_QUEN');
      if (mounted) {
        setState(() {
          _isAlarmActive = false;
          _statusText = fromRemote
              ? '✅ Người quen (Discord) - Tạm dừng báo động 3 phút'
              : '✅ Đã xác nhận Người quen - Tạm dừng 3 phút';
          _statusColor = AppTheme.statusArmed;
        });
      }
    } else if (isMuted) {
      _snoozeUntil = now.add(const Duration(minutes: 3));
      if (mounted) {
        setState(() {
          _isAlarmActive = false;
          _statusText = fromRemote
              ? '🔕 Đã tắt chuông (Discord) - Tạm dừng 3 phút'
              : '🔕 Đã tắt chuông báo - Tạm dừng 3 phút';
          _statusColor = AppTheme.statusArmed;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isAlarmActive = false;
          _statusText = 'Đang canh gác trực tiếp';
          _statusColor = AppTheme.statusArmed;
        });
      }
    }

    // Nếu người dùng thao tác trực tiếp trên màn hình camera -> Gửi lệnh cập nhật lên Backend
    if (!fromRemote && _activeAlertId != null) {
      try {
        final actionStr = isKnownPerson ? 'KnownPerson' : (isMuted ? 'Mute' : 'Dismiss');
        await ApiClient.request('POST', '/api/alerts/$_activeAlertId/action', body: {'action': actionStr});
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Camera Canh Gác Trực Tiếp'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.face_retouching_natural),
            tooltip: 'Người quen & Nhận diện',
            onPressed: _showKnownPersonsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined),
            onPressed: _switchCamera,
            tooltip: 'Đổi camera',
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Quản trị hệ thống',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
            Container(
              color: _statusColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Text(
                    _guardMode == GuardMode.always24h ? '24/7' : (_guardMode == GuardMode.enabled ? 'BẬT' : 'TẮT'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Live Camera View
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraReady && _cameraController != null)
                    Center(child: CameraPreview(_cameraController!))
                  else
                    const Center(child: CircularProgressIndicator(color: Colors.white)),

                  // Visual target viewfinder overlay
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _statusColor.withValues(alpha: 0.7),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  // Thanh điều khiển khẩn cấp khi đang phát hiện đối tượng / báo động
                  if (_isAlarmActive)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.statusAlarm, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: AppTheme.statusAlarm, size: 24),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ĐANG BÁO ĐỘNG PHÁT HIỆN ĐỐI TƯỢNG!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.statusArmed,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onPressed: () => _dismissAlarm(isKnownPerson: true),
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: const Text('Người quen', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onPressed: () => _dismissAlarm(isMuted: true),
                                    icon: const Icon(Icons.volume_off, size: 18),
                                    label: const Text('Tắt chuông'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Controls Sheet
            Container(
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Guard Mode Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildModeButton('24 Giờ', GuardMode.always24h, Colors.blue),
                      _buildModeButton('Bật Canh', GuardMode.enabled, Colors.green),
                      _buildModeButton('Tắt Canh', GuardMode.disabled, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Emergency Manual Alarm Trigger
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.statusAlarm,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _handleSecurityTrigger('CANH_BAO_THU_CONG', 10.0),
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('Báo Động Khẩn Cấp'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, GuardMode mode, Color activeColor) {
    final isSelected = _guardMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: activeColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: const Color(0xFF334155),
      onSelected: (val) {
        if (val) setState(() => _guardMode = mode);
      },
    );
  }
}
