import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Trạng thái của bộ phân tích âm thanh AI
enum SoundAiStatus { idle, loading, listening, modelMissing, noPermission, error }

/// SoundClassifierService — Phân loại âm thanh thời gian thực bằng YAMNet (TFLite).
///
/// Luồng xử lý:
///   Microphone ──(record: PCM16, 16kHz, mono)──► chuẩn hoá Float32 [-1, 1]
///   ──► bộ đệm 15600 mẫu (0.975s) ──► cổng im lặng (RMS) ──► YAMNet (Isolate)
///   ──► 521 điểm lớp ──► điểm nguy cơ có trọng số ──► SensorFusionService
///
/// Tối ưu chống nóng máy / quá tải:
///   • Inference chạy trên IsolateInterpreter → không chặn UI thread.
///   • Bỏ qua inference khi môi trường im lặng (RMS < [silenceRms]).
///   • Nếu inference trước chưa xong → bỏ cửa sổ hiện tại (không xếp hàng).
///   • Cửa sổ không chồng lấp: tối đa ~1 lần inference / giây.
///
/// Asset bắt buộc (tải từ TensorFlow Hub / tensorflow/models):
///   assets/models/yamnet.tflite
///   assets/models/yamnet_class_map.csv
class SoundClassifierService {
  static const String modelAsset = 'assets/models/yamnet.tflite';
  static const String labelsAsset = 'assets/models/yamnet_class_map.csv';

  static const int sampleRate = 16000;
  static const int windowSize = 15600; // Đầu vào chuẩn của YAMNet

  /// Ngưỡng RMS coi là im lặng (bỏ qua inference để tiết kiệm pin)
  double silenceRms = 0.008;

  /// Ngưỡng điểm nguy cơ tối thiểu để coi là âm thanh bất thường (0.0 – 1.0)
  double confidenceThreshold = 0.65;

  // ─── TFLite ────────────────────────────────────────────────────────────────
  Interpreter? _interpreter;
  IsolateInterpreter? _isolate;
  List<int> _inputShape = const [windowSize];
  List<int> _outputShape = const [1, 521];
  List<String> _labels = [];
  List<double> _riskWeights = [];

  // ─── Microphone ────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  final Float32List _window = Float32List(windowSize);
  int _windowFill = 0;
  int? _pendingByte; // byte lẻ còn dư từ chunk PCM trước
  bool _inferenceBusy = false;

  // ─── Output streams ────────────────────────────────────────────────────────
  final _resultController = StreamController<SoundClassificationResult>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();

  /// Kết quả mỗi cửa sổ 0.975s
  Stream<SoundClassificationResult> get resultStream => _resultController.stream;

  /// Mức âm lượng (0.0 – 1.0) theo từng chunk mic – dùng vẽ sóng âm thật
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  final ValueNotifier<SoundAiStatus> status = ValueNotifier(SoundAiStatus.idle);
  String? lastError;

  String currentLabel = 'Silence';
  double currentConfidence = 0.0;

  /// Callback khi phát hiện âm thanh nguy hiểm vượt ngưỡng
  void Function(String label, double riskScore)? onAbnormalSound;

  bool get isListening => _micSub != null;

  // ═══ Lifecycle ═════════════════════════════════════════════════════════════

  /// Tải nhãn + mô hình. An toàn khi gọi nhiều lần.
  Future<bool> initialize() async {
    if (_interpreter != null) return true;
    status.value = SoundAiStatus.loading;
    try {
      await _loadLabels();
      final options = InterpreterOptions()..threads = 2;
      final interpreter = await Interpreter.fromAsset(modelAsset, options: options);

      // Một số bản YAMNet có input động → cố định về [15600]
      _inputShape = interpreter.getInputTensor(0).shape;
      if (_inputShape.fold<int>(1, (a, b) => a * b) != windowSize) {
        interpreter.resizeInputTensor(0, [windowSize]);
        interpreter.allocateTensors();
        _inputShape = interpreter.getInputTensor(0).shape;
      }
      _outputShape = interpreter.getOutputTensor(0).shape;

      _interpreter = interpreter;
      _isolate = await IsolateInterpreter.create(address: interpreter.address);
      debugPrint('[SoundAI] YAMNet sẵn sàng: input=$_inputShape output=$_outputShape '
          'labels=${_labels.length}');
      status.value = SoundAiStatus.idle;
      return true;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[SoundAI] Không tải được mô hình: $e');
      // Không giả lập kết quả – báo rõ là thiếu mô hình
      status.value = SoundAiStatus.modelMissing;
      return false;
    }
  }

  /// Bắt đầu nghe micro và phân tích liên tục
  Future<void> start() async {
    if (isListening) return;
    if (!await initialize()) return;

    if (!await _recorder.hasPermission()) {
      status.value = SoundAiStatus.noPermission;
      return;
    }

    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ));
      _windowFill = 0;
      _pendingByte = null;
      _micSub = stream.listen(_onPcmChunk, onError: (Object e) {
        lastError = e.toString();
        status.value = SoundAiStatus.error;
      });
      status.value = SoundAiStatus.listening;
    } catch (e) {
      lastError = e.toString();
      status.value = SoundAiStatus.error;
    }
  }

  /// Dừng nghe (giữ mô hình trong bộ nhớ để bật lại nhanh)
  Future<void> stop() async {
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    _windowFill = 0;
    _pendingByte = null;
    if (status.value == SoundAiStatus.listening) status.value = SoundAiStatus.idle;
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
    await _isolate?.close();
    _interpreter?.close();
    _isolate = null;
    _interpreter = null;
    await _resultController.close();
    await _amplitudeController.close();
    status.dispose();
  }

  void updateThreshold(double threshold) {
    confidenceThreshold = threshold.clamp(0.3, 0.95);
  }

  // ═══ PCM processing ════════════════════════════════════════════════════════

  void _onPcmChunk(Uint8List bytes) {
    // Ghép byte lẻ của chunk trước để không lệch biên Int16
    Uint8List data = bytes;
    if (_pendingByte != null) {
      data = Uint8List(bytes.length + 1)
        ..[0] = _pendingByte!
        ..setRange(1, bytes.length + 1, bytes);
      _pendingByte = null;
    }
    final sampleCount = data.length ~/ 2;
    if (data.length.isOdd) _pendingByte = data[data.length - 1];

    // Đọc little-endian an toàn (không phụ thuộc offset căn chỉnh của buffer)
    final bd = ByteData.sublistView(data);
    double sumSq = 0;
    for (int i = 0; i < sampleCount; i++) {
      final s = bd.getInt16(i * 2, Endian.little) / 32768.0;
      sumSq += s * s;
      _window[_windowFill++] = s;
      if (_windowFill == windowSize) {
        _onWindowReady();
        _windowFill = 0;
      }
    }

    if (sampleCount > 0 && !_amplitudeController.isClosed) {
      // Chuyển RMS sang thang 0..1 dễ nhìn (≈ -50dB → 0, 0dB → 1)
      final rms = sqrt(sumSq / sampleCount);
      final db = 20 * log(max(rms, 1e-5)) / ln10;
      _amplitudeController.add(((db + 50) / 50).clamp(0.0, 1.0));
    }
  }

  void _onWindowReady() {
    // Cổng im lặng: không tốn CPU khi phòng yên tĩnh
    double sumSq = 0;
    for (final s in _window) {
      sumSq += s * s;
    }
    final rms = sqrt(sumSq / windowSize);
    if (rms < silenceRms) {
      _emit('Silence', 1.0, 0.0, 'Silence');
      return;
    }
    // Inference trước chưa xong → bỏ cửa sổ này thay vì xếp hàng
    if (_inferenceBusy || _isolate == null) return;

    final snapshot = Float32List.fromList(_window);
    _runInference(snapshot);
  }

  Future<void> _runInference(Float32List samples) async {
    _inferenceBusy = true;
    try {
      final Object input = _inputShape.length == 1 ? samples : [samples];
      final output = _allocOutput(_outputShape);
      await _isolate!.run(input, output);

      final scores = _flattenScores(output);
      if (scores.isEmpty) return;

      // Lớp có điểm cao nhất (để hiển thị)
      int topIdx = 0;
      for (int i = 1; i < scores.length; i++) {
        if (scores[i] > scores[topIdx]) topIdx = i;
      }
      // Lớp nguy hiểm nhất theo trọng số (để quyết định báo động).
      // Không dùng argmax đơn thuần vì "Speech" thường lấn át "Glass".
      double risk = 0;
      int riskIdx = topIdx;
      for (int i = 0; i < scores.length && i < _riskWeights.length; i++) {
        final r = scores[i] * _riskWeights[i];
        if (r > risk) {
          risk = r;
          riskIdx = i;
        }
      }

      final topLabel = _labelAt(topIdx);
      final riskLabel = risk > 0 ? _labelAt(riskIdx) : topLabel;
      _emit(topLabel, scores[topIdx], risk.clamp(0.0, 1.0), riskLabel);
    } catch (e) {
      lastError = e.toString();
      debugPrint('[SoundAI] Inference lỗi: $e');
    } finally {
      _inferenceBusy = false;
    }
  }

  void _emit(String label, double confidence, double risk, String riskLabel) {
    currentLabel = risk >= confidenceThreshold ? riskLabel : label;
    currentConfidence = confidence;
    final abnormal = risk >= confidenceThreshold;
    if (_resultController.isClosed) return;
    _resultController.add(SoundClassificationResult(
      label: currentLabel,
      confidence: confidence,
      riskScore: risk,
      timestamp: DateTime.now(),
      isAbnormal: abnormal,
    ));
    if (abnormal) {
      debugPrint('🔊 AI phát hiện: $riskLabel – nguy cơ ${(risk * 100).toStringAsFixed(1)}%');
      onAbnormalSound?.call(riskLabel, risk);
    }
  }

  // ═══ Labels & risk weights ═════════════════════════════════════════════════

  Future<void> _loadLabels() async {
    if (_labels.isNotEmpty) return;
    final csv = await rootBundle.loadString(labelsAsset);
    final lines = csv.split(RegExp(r'\r?\n')).skip(1).where((l) => l.trim().isNotEmpty);
    // Định dạng: index,mid,display_name – display_name có thể chứa dấu phẩy
    // trong ngoặc kép, ví dụ: 3,/m/02zsn,"Gunshot, gunfire"
    _labels = lines.map((line) {
      final first = line.indexOf(',');
      final second = first < 0 ? -1 : line.indexOf(',', first + 1);
      if (second < 0) return 'Unknown';
      var name = line.substring(second + 1).trim();
      if (name.startsWith('"') && name.endsWith('"') && name.length >= 2) {
        name = name.substring(1, name.length - 1);
      }
      return name;
    }).toList();
    _riskWeights = _labels.map(_weightForLabel).toList();
  }

  /// Trọng số nguy cơ theo nhóm âm thanh (tính 1 lần khi tải nhãn)
  static double _weightForLabel(String label) {
    final l = label.toLowerCase();
    bool any(List<String> keys) => keys.any(l.contains);

    // Nhóm nguy hiểm cao: kính vỡ, đập phá, la hét, súng nổ, còi báo động
    if (any(['glass', 'shatter', 'breaking', 'smash', 'scream', 'gunshot',
        'gunfire', 'machine gun', 'explosion', 'alarm', 'siren'])) {
      return 1.0;
    }
    // Nhóm đáng ngờ: la lớn, cạy/gõ/đóng sầm cửa, khóc
    if (any(['shout', 'yell', 'crying', 'sobbing', 'knock', 'slam', 'door',
        'crowbar', 'thump'])) {
      return 0.7;
    }
    if (any(['dog', 'bark', 'growl'])) return 0.45;

    // Nhiễu môi trường thông thường → bỏ qua
    if (any(['speech', 'conversation', 'music', 'silence', 'wind', 'fan',
        'traffic', 'vehicle', 'television', 'radio', 'rain', 'air conditioning',
        'white noise', 'hum', 'inside, small room'])) {
      return 0.0;
    }
    return 0.15; // Tiếng động không xác định – rủi ro thấp
  }

  String _labelAt(int i) => i < _labels.length ? _labels[i] : 'Class $i';

  // ═══ Tensor helpers ════════════════════════════════════════════════════════

  static Object _allocOutput(List<int> shape) {
    if (shape.length == 1) return List<double>.filled(shape[0], 0.0);
    return List.generate(shape[0], (_) => _allocOutput(shape.sublist(1)));
  }

  /// Gộp output về vector 521 điểm (lấy max theo frame nếu có nhiều frame)
  static List<double> _flattenScores(Object? output) {
    if (output is List<double>) return output;
    if (output is List && output.isNotEmpty) {
      final frames = output
          .map<List<double>>((dynamic e) => _flattenScores(e))
          .where((f) => f.isNotEmpty)
          .toList();
      if (frames.isEmpty) return const [];
      if (frames.length == 1) return frames.first;
      final out = List<double>.filled(frames.first.length, 0.0);
      for (final f in frames) {
        for (int i = 0; i < out.length && i < f.length; i++) {
          if (f[i] > out[i]) out[i] = f[i];
        }
      }
      return out;
    }
    return const [];
  }

  // ═══ UI helpers ════════════════════════════════════════════════════════════

  /// Tên nhãn tiếng Việt để hiển thị UI (dựa trên từ khoá nhãn YAMNet)
  static String labelToVietnamese(String label) {
    final l = label.toLowerCase();
    if (l.contains('glass') || l.contains('shatter')) return 'Vỡ kính';
    if (l.contains('scream')) return 'Tiếng la hét';
    if (l.contains('shout') || l.contains('yell')) return 'Tiếng quát lớn';
    if (l.contains('gunshot') || l.contains('gunfire') || l.contains('explosion')) {
      return 'Tiếng nổ';
    }
    if (l.contains('smash') || l.contains('breaking')) return 'Đập phá';
    if (l.contains('alarm') || l.contains('siren')) return 'Còi báo động';
    if (l.contains('knock')) return 'Gõ cửa';
    if (l.contains('door') || l.contains('slam')) return 'Tiếng cửa';
    if (l.contains('dog') || l.contains('bark')) return 'Chó sủa';
    if (l.contains('crying') || l.contains('sobbing')) return 'Tiếng khóc';
    if (l.contains('speech') || l.contains('conversation')) return 'Tiếng nói';
    if (l.contains('music')) return 'Âm nhạc';
    if (l.contains('silence')) return 'Yên tĩnh';
    return 'Bình thường';
  }
}

/// Kết quả một cửa sổ phân tích âm thanh (0.975s)
class SoundClassificationResult {
  final String label;       // Nhãn YAMNet (tiếng Anh)
  final double confidence;  // Điểm của lớp cao nhất
  final double riskScore;   // Điểm nguy cơ có trọng số (0.0 – 1.0)
  final DateTime timestamp;
  final bool isAbnormal;

  const SoundClassificationResult({
    required this.label,
    required this.confidence,
    required this.riskScore,
    required this.timestamp,
    required this.isAbnormal,
  });
}
