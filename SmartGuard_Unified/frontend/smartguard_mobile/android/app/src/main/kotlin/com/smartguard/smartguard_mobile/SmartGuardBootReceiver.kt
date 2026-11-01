package com.smartguard.smartguard_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * SmartGuard Boot Receiver – Phase 2
 *
 * Lắng nghe sự kiện khởi động máy và tự động restart
 * SmartGuardForegroundService để duy trì bảo vệ liên tục.
 *
 * Cần quyền: RECEIVE_BOOT_COMPLETED trong AndroidManifest.xml
 */
class SmartGuardBootReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "SmartGuardBootRcvr"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i(TAG, "Boot event nhận được: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            Log.i(TAG, "Khởi động lại SmartGuard Guard Service sau khi thiết bị boot.")
            SmartGuardForegroundService.startService(context)
        }
    }
}

