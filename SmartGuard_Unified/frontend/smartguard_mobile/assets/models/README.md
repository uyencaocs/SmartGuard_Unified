# Mô hình AI âm thanh (YAMNet)

Thư mục này cần 2 tệp:

| Tệp | Nguồn |
|-----|-------|
| `yamnet.tflite` | https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/audio_classification/android/lite-model_yamnet_classification_tflite_1.tflite (đổi tên thành `yamnet.tflite`) |
| `yamnet_class_map.csv` | https://raw.githubusercontent.com/tensorflow/models/master/research/audioset/yamnet/yamnet_class_map.csv |

Đầu vào: Float32 `[15600]` (0.975s, 16 kHz, mono, giá trị [-1, 1]).
Đầu ra: `[1, 521]` điểm cho 521 lớp AudioSet.

Nếu thiếu tệp, `SoundClassifierService` báo trạng thái `modelMissing` và AI âm thanh
tắt (không giả lập kết quả).

