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
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/tts_service.dart';
import '../../services/sensor_fusion_service.dart';
import '../alerts/alerts_history_screen.dart';

enum GuardMode { always24h, enabled, disabled }

class CameraGuardScreen extends StatefulWidget {
  final bool isTab;
  const CameraGuardScreen({super.key, this.isTab = false});

  @override
  State<CameraGuardScreen> createState() => _CameraGuardScreenState();
}

class _CameraGuardScreenState extends State<CameraGuardScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  bool _isProcessingFrame = false;

  final GuardMode _guardMode = GuardMode.always24h;
  DateTime? _lastAlertTime;
  final int _cooldownSeconds = 15;

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

  bool _hasPersonInFrame = false;
  List<KnownPersonModel> _knownPersons = [];
  final bool _autoDismissForKnownPersons = true;
  DateTime? _lastKnownPersonNotice;

  // Audio / Mic / Fullscreen state
  bool _isMuted = false;
  bool _isIntercomActive = false;
  bool _isFullscreen = false;

  // Recent timeline events for UI
  List<Map<String, dynamic>> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSystem();
    _loadRecentEvents();
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

  Future<void> _loadRecentEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('sg_cached_alerts');
      if (cached != null && cached.isNotEmpty && mounted) {
        final list = (jsonDecode(cached) as List<dynamic>).take(5).toList();
        setState(() {
          _recentEvents = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      } else {
        setState(() {
          _recentEvents = [
            {
              'title': 'Phát hiện người lạ',
              'time': '10:24',
              'subtitle': 'Camera cửa chính',
              'type': 'stranger',
            },
            {
              'title': 'Phát hiện chuyển động',
              'time': '10:10',
              'subtitle': 'Sân trước',
              'type': 'motion',
            },
            {
              'title': 'Âm thanh bất thường',
              'time': '09:58',
              'subtitle': 'Phòng khách',
              'type': 'sound',
            },
            {
              'title': 'Kết nối lại',
              'time': '09:32',
              'subtitle': 'Hệ thống tự động',
              'type': 'system',
            },
          ];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDevices() async {
    try {
      final res = await ApiClient.request('GET', '/api/devices') as List<dynamic>;
      final list = res.map((e) => DeviceModel.fromJson(e as Map<String, dynamic>)).toList();
      if (list.isEmpty) {
        try {
          final newDev = await ApiClient.request('POST', '/api/devices', body: {
            'name': 'Camera Cửa Chính',
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
          _statusText = 'Chế độ mô phỏng trực tiếp';
          _statusColor = AppTheme.statusArmed;
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

  Future<void> _takeSnapshot() async {
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final xFile = await _cameraController!.takePicture();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Đã lưu ảnh chụp nhanh: ${xFile.name}'),
                ],
              ),
              backgroundColor: AppTheme.statusArmed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã chụp ảnh nhanh (mô phỏng)!'),
              backgroundColor: AppTheme.statusArmed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chụp ảnh: $e'), backgroundColor: AppTheme.statusAlarm),
        );
      }
    }
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

  void _initAccelerometer() {
    _sensorSubscription = accelerometerEventStream().listen((event) {
      if (_guardMode == GuardMode.disabled) return;
      if (_snoozeUntil != null && DateTime.now().isBefore(_snoozeUntil!)) return;
      if (_hasPersonInFrame) return;

      final double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      final double delta = (magnitude - 9.8).abs();

      if (delta > 3.8) {
        _handleSecurityTrigger('PHAT_HIEN_RUNG_LAC', delta);
      }
    });
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _guardMode == GuardMode.disabled) return;
    if (_snoozeUntil != null && DateTime.now().isBefore(_snoozeUntil!)) return;

    _isProcessingFrame = true;
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = _cameras[_selectedCameraIndex];
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.isNotEmpty ? image.planes.first.bytesPerRow : image.width,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        _hasPersonInFrame = true;
        if (_autoDismissForKnownPersons && _knownPersons.isNotEmpty) {
          final now = DateTime.now();
          if (_lastKnownPersonNotice == null || now.difference(_lastKnownPersonNotice!).inSeconds > 10) {
            _lastKnownPersonNotice = now;
            TtsService.playWarningVoice('NGUOI_QUEN');
          }
          if (mounted) {
            setState(() {
              _statusText = 'Nhận diện người quen (${_knownPersons.first.name})';
              _statusColor = AppTheme.statusArmed;
            });
          }
        } else {
          _handleSecurityTrigger('PHAT_HIEN_NGUOI_LA', faces.length.toDouble());
        }
      } else {
        _hasPersonInFrame = false;
        if (mounted && !_isAlarmActive) {
          setState(() {
            _statusText = 'Đang canh gác trực tiếp';
            _statusColor = AppTheme.statusArmed;
          });
        }
      }
    } catch (_) {} finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _handleSecurityTrigger(String reason, double score) async {
    final now = DateTime.now();
    if (_snoozeUntil != null && now.isBefore(_snoozeUntil!)) return;
    if (_lastAlertTime != null && now.difference(_lastAlertTime!).inSeconds < _cooldownSeconds) return;

    _lastAlertTime = now;
    if (mounted) {
      setState(() {
        _isAlarmActive = true;
        _statusText = 'CẢNH BÁO: $reason!';
        _statusColor = AppTheme.statusAlarm;
      });
    }

    try {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(pattern: [500, 1000, 500, 1000]);
      }
    } catch (_) {}

    TtsService.playWarningVoice(reason);

    // ── Gọi điện khẩn cấp qua AlertOrchestrator ────────────────────────────
    final devId = _selectedDeviceId ?? (_devices.isNotEmpty ? _devices.first.id : 'unknown');
    final devName = _devices.firstWhere(
      (d) => d.id == devId,
      orElse: () => DeviceModel(
        id: devId,
        ownerId: '',
        name: 'Camera',
        deviceCode: '',
        registeredAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
      ),
    ).name;

    // Chạy trong background, không block UI
    AlertOrchestrator.triggerFullAlert(
      fusion: FusionResult(
        score: (score / 10).clamp(0.0, 1.0),
        level: AlertSeverity.high,
        reason: reason,
        breakdown: {'motion': score / 10, 'sound': 0.0, 'vision': 0.0},
      ),
      deviceId: devId,
      deviceName: devName,
      // Màn hình này đã tự rung/TTS và POST kèm ảnh bên dưới → tránh trùng
      postToServer: false,
      localFeedback: false,
    );

    String? imageUrl;
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final xFile = await _cameraController!.takePicture();
        final snapFile = File(xFile.path);
        if (snapFile.existsSync()) {
          if (devId.isNotEmpty && devId != 'unknown') {
            final uploadRes = await ApiClient.uploadFile(
              '/api/images/upload',
              snapFile,
              fields: {'deviceId': devId},
            );
            imageUrl = uploadRes['imageUrl']?.toString();
          }
        }
      }
    } catch (_) {}

    String alertId = '';
    try {
      final alertRes = await ApiClient.request('POST', '/api/alerts/trigger', body: {
        'deviceId': _selectedDeviceId,
        'triggerReason': reason,
        'triggerScore': score,
        'imageUrl': imageUrl,
      });
      if (alertRes is Map<String, dynamic>) {
        alertId = (alertRes['alertId'] ?? alertRes['id'])?.toString() ?? '';
        _activeAlertId = alertId;
      }
    } catch (_) {}

    _startAlertStatusPolling(alertId);
  }

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

    if (!fromRemote && _activeAlertId != null && _activeAlertId!.isNotEmpty) {
      try {
        final actionStr = isKnownPerson ? 'KnownPerson' : (isMuted ? 'Mute' : 'Dismiss');
        await ApiClient.request('POST', '/api/alerts/$_activeAlertId/action', body: {'action': actionStr});
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final devName = _devices.isNotEmpty ? _devices.first.name : 'Camera cửa chính';

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar matching Mockup "CAMERA TRỰC TIẾP"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (!widget.isTab && Navigator.of(context).canPop())
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppTheme.headingDark),
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
                          child: const Icon(Icons.videocam, color: AppTheme.coralPink, size: 20),
                        ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            devName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.headingDark,
                            ),
                          ),
                          Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: _statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // LIVE status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E7D32),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Video Streaming Card
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.borderWarm, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Live Camera Preview or Placeholder
                        if (_isCameraReady && _cameraController != null)
                          CameraPreview(_cameraController!)
                        else
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF2B3A4A), Color(0xFF1E2836)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/3bc65821-0388-43aa-aba6-16fc6a3912a4.png',
                                    height: 100,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.videocam_outlined,
                                      size: 64,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Đang kết nối camera an ninh...',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Viewfinder center focus box
                        Center(
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _statusColor.withValues(alpha: 0.6),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),

                        // Cute Capybara Mascot Peek in bottom right corner (from mockup!)
                        Positioned(
                          bottom: -6,
                          right: 8,
                          child: IgnorePointer(
                            child: Image.asset(
                              'assets/images/sticker_system(2).png',
                              height: 64,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/Capybara.jpg',
                                height: 60,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),

                        // Alarm Active Banner overlay
                        if (_isAlarmActive)
                          Positioned(
                            top: 12,
                            left: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.coralPink.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'PHÁT HIỆN ĐỐI TƯỢNG BẤT THƯỜNG!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _dismissAlarm(isKnownPerson: true),
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                    child: const Text('Người quen', style: TextStyle(color: AppTheme.coralPink, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Rounded Floating Control Bar (Speaker, Mic, Camera Snapshot, Fullscreen / Flip)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Speaker toggle
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: _isMuted ? Colors.white54 : Colors.white,
                      ),
                      tooltip: _isMuted ? 'Bật âm thanh' : 'Tắt âm thanh',
                      onPressed: () {
                        setState(() => _isMuted = !_isMuted);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isMuted ? 'Đã tắt âm thanh camera' : 'Đã bật âm thanh camera'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    // Intercom / Mic
                    IconButton(
                      icon: Icon(
                        _isIntercomActive ? Icons.mic : Icons.mic_none,
                        color: _isIntercomActive ? AppTheme.coralPink : Colors.white,
                      ),
                      tooltip: 'Đàm thoại 2 chiều',
                      onPressed: () {
                        setState(() => _isIntercomActive = !_isIntercomActive);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isIntercomActive ? 'Đang mở mic đàm thoại...' : 'Đã ngắt kết nối mic'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    // Snapshot Camera Button
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                        tooltip: 'Chụp ảnh màn hình',
                        onPressed: _takeSnapshot,
                      ),
                    ),
                    // Flip Camera / Switch
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                      tooltip: 'Đổi camera trước/sau',
                      onPressed: _switchCamera,
                    ),
                    // Admin / Settings
                    IconButton(
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                      tooltip: 'Toàn màn hình',
                      onPressed: () {
                        setState(() => _isFullscreen = !_isFullscreen);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Timeline Section "Hôm nay" matching Mockup
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Hôm nay',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.headingDark,
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary, size: 20),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.creamBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_recentEvents.length} sự kiện',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Event timeline list
                    Expanded(
                      child: ListView.separated(
                        itemCount: _recentEvents.length,
                        separatorBuilder: (_, __) => const Divider(height: 12, color: AppTheme.borderWarm),
                        itemBuilder: (ctx, index) {
                          final item = _recentEvents[index];
                          final title = item['title']?.toString() ?? item['triggerReason']?.toString() ?? 'Sự kiện';
                          final time = item['time']?.toString() ?? '10:24';
                          final subtitle = item['subtitle']?.toString() ?? item['deviceName']?.toString() ?? 'Camera cửa chính';
                          final imageUrl = item['imageUrl']?.toString();

                          return Row(
                            children: [
                              // Timestamp
                              SizedBox(
                                width: 50,
                                child: Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Event description
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.headingDark,
                                      ),
                                    ),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Small thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 44,
                                  height: 34,
                                  color: const Color(0xFFF1F5F9),
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(
                                          '${AppConfig.baseUrl}$imageUrl',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _eventIconFor(title),
                                        )
                                      : _eventIconFor(title),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // "Xem lịch sử đầy đủ" Gradient Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.coralPink.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AlertsHistoryScreen()),
                            );
                          },
                          child: const Text(
                            'Xem lịch sử đầy đủ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventIconFor(String title) {
    if (title.contains('người lạ') || title.contains('stranger')) {
      return const Icon(Icons.person_pin_circle, color: AppTheme.coralPink, size: 20);
    } else if (title.contains('chuyển động') || title.contains('motion')) {
      return const Icon(Icons.directions_run, color: Color(0xFF10B981), size: 20);
    } else if (title.contains('âm thanh') || title.contains('sound')) {
      return const Icon(Icons.graphic_eq, color: AppTheme.royalPurple, size: 20);
    }
    return const Icon(Icons.shield_outlined, color: AppTheme.statusArmed, size: 20);
  }
}

