# SMARTGUARD UNIFIED — HỆ THỐNG GIÁM SÁT AN NINH CAMERA THÔNG MINH

Dự án hợp nhất chuẩn kiến trúc từ 3 dự án thành phần, kế thừa các ưu điểm vượt trội, khắc phục triệt để các lỗ hổng bảo mật và chuẩn hóa toàn diện mã nguồn.

---

## 1. KIẾN TRÚC TỔNG THỂ VÀ TECH STACK

- **Backend (`backend/SmartGuard.API`)**:
  - ASP.NET Core 8.0 Web API theo mô hình phân tầng **Layered Clean Architecture**.
  - Entity Framework Core 8.0 + SQL Server (`MSSQLSERVER` / `LocalDB`).
  - Phân quyền theo vai trò (Role-based: Admin, Owner, Member).
  - Tích hợp bảo mật 2 lớp: Mã hóa BCrypt + Challenge OTP (Email SMTP & Dev console fallback).
  - Bảo vệ Rate Limiting chống Brute-Force (15 requests/phút theo IP).
  - Tích hợp cảnh báo Discord 2 chiều (Discord Bot WebSocket + Discord Webhook Fallback + Nút bấm tương tác trên Discord).
  - Tiếp nhận và lưu trữ ảnh chụp bằng chứng từ Camera Client qua REST Multipart (`/evidence/...`).

- **Frontend (`frontend/smartguard_mobile`)**:
  - Flutter Mobile App (Tương thích Dart `3.12.1`+).
  - Thiết kế Material 3 hiện đại, hỗ trợ cả Dark Mode và Light Mode.
  - Tích hợp quét khuôn mặt thời gian thực bằng Google ML Kit (`google_mlkit_face_detection`).
  - Cảm biến gia tốc phát hiện rung lắc hoặc di chuyển thiết bị vật lý (`sensors_plus`).
  - Phát âm thanh cảnh báo bằng giọng nói tiếng Việt qua Text-To-Speech (`flutter_tts`).
  - Xác thực sinh trắc học vân tay / Face ID (`local_auth`) cho đăng nhập nhanh.
  - Lưu trữ JWT an toàn bằng Android Keystore qua `flutter_secure_storage`.
  - Hỗ trợ đổi máy chủ linh hoạt trên giao diện: LAN IP, Localhost, Android Emulator hoặc Custom URL.

- **Smart Adaptive Security (Chức năng mới Giai đoạn 3)**:
  - Bộ máy quy tắc thích ứng có thể giải thích (`AdaptiveRuleEngine`): Tự động điều chỉnh hành vi theo kịch bản sinh hoạt thực tế.
  - Ba chế độ tiêu chuẩn:
    * 🏠 **Ở nhà (Home)**: Tự động miễn trừ/giảm cảnh báo tại các khu vực sinh hoạt (Phòng khách, Bếp), chỉ tập trung bảo vệ lối vào, cổng trước.
    * 🚶 **Rời nhà (Away)**: Kích hoạt toàn diện cảm biến ở mọi phân vùng, gửi thông báo khẩn cấp ngay tức thì.
    * 🌙 **Ban đêm (Night)**: Tăng cường độ nhạy phát hiện (x1.5), kích hoạt còi báo động tại chỗ ngay khi phát hiện người lạ hoặc rung lắc.
  - Cơ chế **Tạm dừng / Nghỉ tạm thời (Snooze Override)**: Cho phép chủ nhà tạm ngưng cảnh báo trong 15, 30, 60 phút khi có khách hoặc dọn dẹp nhà cửa.
  - Diễn giải nguồn gốc cảnh báo (Explainable Rule Trigger): Mỗi cảnh báo đều ghi lại rõ lý do kích hoạt (ví dụ: *"Kích hoạt bởi Chế độ [Ban đêm] tại khu vực [Cổng chính] (Độ nhạy x1.5)"*).
  - Tùy chỉnh hành vi khi mất kết nối (`BehaviorOnDisconnect`): `AlertOffline`, `FailSecure`, `MaintainState`.

- **Automated Tests (`tests/SmartGuard.Tests`)**:
  - Bộ kiểm thử tự động xUnit 9/9 bài kiểm tra cho toàn bộ luồng Auth, 2FA, JWT Claims, Phân quyền, Bật/Tắt Canh gác (Arm/Disarm), Kích hoạt Cảnh báo an ninh, Bộ máy thích ứng (Home/Away/Night/Snooze/Transition) và Kiểm tra khả năng chịu lỗi (Resilience / Fault Tolerance).

---

## 2. CẤU TRÚC THƯ MỤC DỰ ÁN HỢP NHẤT

```
SmartGuard_Unified/
├── backend/
│   └── SmartGuard.API/
│       ├── Controllers/            # Auth, Devices, Zones, Members, Alerts, Images, Admin, AdaptiveSecurity
│       ├── Data/SmartGuardDbContext.cs
│       ├── DTOs/AllDtos.cs
│       ├── Models/Entities.cs      # User, Device, Zone, Alert, AdaptiveProfile, AdaptiveZoneRule...
│       ├── Services/               # DiscordBotService, EmailService, TokenService, AdaptiveRuleEngine
│       ├── Program.cs              # DI Pipeline, Rate Limiter, Seeding Data
│       ├── appsettings.json
│       └── SmartGuard.API.csproj
├── frontend/
│   └── smartguard_mobile/
│       ├── lib/
│       │   ├── core/               # ApiClient, AppConfig, SessionManager, AppTheme
│       │   ├── models/models.dart  # Data Models
│       │   ├── services/           # AuthService, TtsService
│       │   ├── screens/
│       │   │   ├── auth/           # Welcome, Login, Register, Otp
│       │   │   ├── dashboard/      # DashboardScreen (kèm nút mở Chế độ Thích ứng)
│       │   │   ├── camera/         # CameraGuardScreen (Live stream, AI Face, Rung lắc)
│       │   │   ├── adaptive/       # AdaptiveSecurityScreen (Home, Away, Night, Snooze, Zone Rules)
│       │   │   ├── alerts/         # AlertsHistoryScreen (Kèm ảnh bằng chứng & Adaptive Reason)
│       │   │   ├── zones/          # ZonesScreen
│       │   │   ├── members/        # MembersScreen
│       │   │   ├── admin/          # AdminScreen
│       │   │   └── settings/       # SettingsScreen (IP Switcher, Ping Test, Biometric)
│       │   └── main.dart
│       └── pubspec.yaml
└── tests/
    └── SmartGuard.Tests/           # xUnit Integration Tests (9/9 Passed)
```

---

## 3. HƯỚNG DẪN CHẠY VÀ KIỂM THỬ

### A. Khởi chạy Backend (.NET 8 API)
1. Mở terminal tại thư mục Backend:
   ```powershell
   cd d:\MyProject\Laptrinhthietbididong\SmartGuard_Unified\backend\SmartGuard.API
   ```
2. Chạy ứng dụng:
   ```powershell
   dotnet run
   ```
   - API sẽ lắng nghe tại: `http://0.0.0.0:5235` (cho phép cả Localhost lẫn điện thoại qua mạng LAN).
   - Truy cập tài liệu trực quan Swagger: `http://localhost:5235/swagger`
   - Tài khoản Admin mặc định tự động tạo: `admin@smartguard.local` / `Admin123@`

### B. Chạy kiểm thử tự động (Unit / Integration Tests)
```powershell
dotnet test d:\MyProject\Laptrinhthietbididong\SmartGuard_Unified\tests\SmartGuard.Tests\SmartGuard.Tests.csproj
```
Kết quả: `Passed! - Failed: 0, Passed: 9, Total: 9`.

### C. Khởi chạy Ứng dụng Di động (Flutter)
1. Mở terminal tại thư mục Frontend:
   ```powershell
   cd d:\MyProject\Laptrinhthietbididong\SmartGuard_Unified\frontend\smartguard_mobile
   ```
2. Cài đặt các gói phụ thuộc:
   ```powershell
   flutter pub get
   ```
3. Khởi chạy ứng dụng:
   ```powershell
   flutter run
   ```
4. Trên ứng dụng, nhấn biểu tượng **Bánh răng (Cài đặt)** ở góc trên để cấu hình địa chỉ máy chủ (LAN IP của máy tính, ví dụ: `http://192.168.2.6:5235`), sau đó nhấn nút **"Kiểm tra kết nối"** để xác nhận kết nối thành công trước khi đăng nhập.
