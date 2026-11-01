# Script tải mô hình YAMNet TFLite & bảng nhãn chuẩn từ TensorFlow
$ErrorActionPreference = "Stop"
$targetDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Đang tải yamnet_class_map.csv..." -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing `
  -Uri "https://raw.githubusercontent.com/tensorflow/models/master/research/audioset/yamnet/yamnet_class_map.csv" `
  -OutFile (Join-Path $targetDir "yamnet_class_map.csv")

Write-Host "Đang tải yamnet.tflite (khoảng 3.7 MB)..." -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing `
  -Uri "https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/audio_classification/android/lite-model_yamnet_classification_tflite_1.tflite" `
  -OutFile (Join-Path $targetDir "yamnet.tflite")

Write-Host "Hoàn tất! Đã lưu yamnet.tflite và yamnet_class_map.csv vào $targetDir" -ForegroundColor Green

