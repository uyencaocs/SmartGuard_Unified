package com.smartguard.smartguard_mobile

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity – Phase 2 Enhanced
 *
 * Tích hợp:
 * 1. MethodChannel "com.smartguard/foreground" → điều khiển ForegroundService từ Dart
 * 2. MethodChannel "com.smartguard/phone"       → gọi điện trực tiếp SIM từ Dart
 * 3. Xin quyền POST_NOTIFICATIONS (Android 13+)
 * 4. Xin quyền CALL_PHONE khi cần gọi khẩn cấp
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val TAG = "SmartGuardMain"
        const val CHANNEL_FOREGROUND = "com.smartguard/foreground"
        const val CHANNEL_PHONE = "com.smartguard/phone"
        const val CHANNEL_PERMISSIONS = "com.smartguard/permissions"

        const val REQ_NOTIFICATIONS = 1001
        const val REQ_CALL_PHONE = 1002
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ─── 1. Foreground Service Channel ───────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_FOREGROUND
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Lưu ý: tất cả trả về Boolean để khớp với invokeMethod<bool> phía Dart
                "startService" -> {
                    Log.i(TAG, "Flutter → startForegroundService")
                    try {
                        SmartGuardForegroundService.startService(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        // Android 12+: ForegroundServiceStartNotAllowedException khi app ở nền
                        Log.e(TAG, "Không thể khởi động service: ${e.message}")
                        result.success(false)
                    }
                }
                "stopService" -> {
                    Log.i(TAG, "Flutter → stopForegroundService")
                    SmartGuardForegroundService.stopService(applicationContext)
                    result.success(true)
                }
                "notifyAlarm" -> {
                    val intent = Intent(applicationContext, SmartGuardForegroundService::class.java).apply {
                        action = SmartGuardForegroundService.ACTION_ALARM
                    }
                    try {
                        applicationContext.startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "notifyAlarm thất bại: ${e.message}")
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ─── 2. Phone Call Channel ────────────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_PHONE
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "callEmergency" -> {
                    val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                    if (phoneNumber.isBlank()) {
                        result.error("INVALID_NUMBER", "Số điện thoại không hợp lệ", null)
                        return@setMethodCallHandler
                    }
                    // true = đã khởi tạo cuộc gọi, false = thiếu quyền / lỗi
                    result.success(makePhoneCall(phoneNumber))
                }
                "requestCallPermission" -> {
                    requestCallPermissionIfNeeded()
                    result.success(true)
                }
                "checkCallPermission" -> {
                    val hasPermission = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.CALL_PHONE
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(hasPermission)
                }
                else -> result.notImplemented()
            }
        }

        // ─── 3. Permissions Channel ───────────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_PERMISSIONS
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAllGuardPermissions" -> {
                    requestAllRequiredPermissions()
                    result.success(true)
                }
                // ── Battery Optimization (Doze Mode) ──────────────────────────
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestBatteryExemption" -> {
                    result.success(requestBatteryExemption())
                }
                "openBatterySettings" -> {
                    result.success(openBatteryOptimizationSettings())
                }
                "checkNotificationPermission" -> {
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        ContextCompat.checkSelfPermission(
                            this, Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                    } else true
                    result.success(granted)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Tự động xin các quyền cần thiết khi app mở lần đầu
        requestAllRequiredPermissions()
    }

    // ═══ Private Helpers ═══════════════════════════════════════════════

    /** Ứng dụng đã nằm trong danh sách ngoại lệ tối ưu pin (Doze) chưa */
    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * Mở hộp thoại hệ thống xin bỏ qua tối ưu pin cho riêng SmartGuard.
     * Cần quyền REQUEST_IGNORE_BATTERY_OPTIMIZATIONS (đã khai báo trong Manifest).
     * Nếu ROM không hỗ trợ hộp thoại trực tiếp → mở trang cài đặt danh sách ứng dụng.
     */
    private fun requestBatteryExemption(): Boolean {
        if (isIgnoringBatteryOptimizations()) return true
        return try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "ROM không hỗ trợ hộp thoại trực tiếp, mở trang cài đặt: ${e.message}")
            openBatteryOptimizationSettings()
        }
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        return try {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            true
        } catch (e: Exception) {
            Log.e(TAG, "Không mở được cài đặt pin: ${e.message}")
            false
        }
    }

    /**
     * Thực hiện gọi điện trực tiếp qua SIM (CALL_PHONE permission required)
     * Trả về true nếu cuộc gọi được khởi tạo thành công, false nếu thiếu quyền
     */
    private fun makePhoneCall(phoneNumber: String): Boolean {
        val hasPermission = ContextCompat.checkSelfPermission(
            this, Manifest.permission.CALL_PHONE
        ) == PackageManager.PERMISSION_GRANTED

        return if (hasPermission) {
            try {
                // Chuẩn hóa số điện thoại – loại bỏ khoảng trắng
                val cleanNumber = phoneNumber.replace("\\s".toRegex(), "")
                val callUri = Uri.parse("tel:$cleanNumber")
                val callIntent = Intent(Intent.ACTION_CALL, callUri).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(callIntent)
                Log.i(TAG, "📞 Đã khởi tạo cuộc gọi khẩn cấp đến: $cleanNumber")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Lỗi khi gọi điện: ${e.message}")
                false
            }
        } else {
            Log.w(TAG, "CALL_PHONE permission chưa được cấp – yêu cầu quyền...")
            requestCallPermissionIfNeeded()
            false
        }
    }

    private fun requestCallPermissionIfNeeded() {
        if (ContextCompat.checkSelfPermission(
                this, Manifest.permission.CALL_PHONE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CALL_PHONE),
                REQ_CALL_PHONE
            )
        }
    }

    private fun requestAllRequiredPermissions() {
        val permissionsNeeded = mutableListOf<String>()

        // Camera & Mic
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED) permissionsNeeded.add(Manifest.permission.CAMERA)

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) permissionsNeeded.add(Manifest.permission.RECORD_AUDIO)

        // Call Phone
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE)
            != PackageManager.PERMISSION_GRANTED) permissionsNeeded.add(Manifest.permission.CALL_PHONE)

        // Read Phone State
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
            != PackageManager.PERMISSION_GRANTED) permissionsNeeded.add(Manifest.permission.READ_PHONE_STATE)

        // Send SMS
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS)
            != PackageManager.PERMISSION_GRANTED) permissionsNeeded.add(Manifest.permission.SEND_SMS)

        // POST_NOTIFICATIONS (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        if (permissionsNeeded.isNotEmpty()) {
            Log.i(TAG, "Yêu cầu các quyền: ${permissionsNeeded.joinToString()}")
            ActivityCompat.requestPermissions(
                this,
                permissionsNeeded.toTypedArray(),
                REQ_NOTIFICATIONS
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        val granted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        Log.i(TAG, "Permission result (code=$requestCode): ${if (granted) "Tất cả đã cấp ✅" else "Một số bị từ chối ⚠️"}")

        // Nếu đã có CALL_PHONE thì tự động khởi động ForegroundService
        if (requestCode == REQ_NOTIFICATIONS && grantResults.isNotEmpty()) {
            val callGranted = permissions.contains(Manifest.permission.CALL_PHONE) &&
                grantResults[permissions.indexOf(Manifest.permission.CALL_PHONE)] == PackageManager.PERMISSION_GRANTED

            if (callGranted) {
                Log.i(TAG, "CALL_PHONE được cấp – SmartGuard sẵn sàng gọi điện khẩn cấp 📞")
            }
        }
    }
}
