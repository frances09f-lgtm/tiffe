package com.ambi.tiffe

import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object OrderNotificationSettings {
    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "tiffe/order_notification_settings").setMethodCallHandler { call, result ->
            try {
                val manager = activity.getSystemService(Activity.NOTIFICATION_SERVICE) as NotificationManager
                when (call.method) {
                    "status" -> {
                        val channelEnabled = if (Build.VERSION.SDK_INT >= 26) {
                            val channel = manager.getNotificationChannel("tiffe_order_status")
                            channel != null && channel.importance != NotificationManager.IMPORTANCE_NONE
                        } else true
                        val power = activity.getSystemService(Activity.POWER_SERVICE) as PowerManager
                        result.success(mapOf(
                            "sdk" to Build.VERSION.SDK_INT,
                            "manufacturer" to Build.MANUFACTURER,
                            "enabled" to NotificationManagerCompat.from(activity).areNotificationsEnabled(),
                            "channelEnabled" to channelEnabled,
                            "batteryExempt" to (Build.VERSION.SDK_INT < 23 || power.isIgnoringBatteryOptimizations(activity.packageName))
                        ))
                    }
                    "notifications", "channel" -> {
                        val intent = if (Build.VERSION.SDK_INT >= 26) {
                            Intent(if (call.method == "channel") Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS else Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                                .putExtra(Settings.EXTRA_CHANNEL_ID, "tiffe_order_status")
                        } else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))
                        activity.startActivity(intent); result.success(null)
                    }
                    "battery" -> {
                        val intent = if (Build.VERSION.SDK_INT >= 23) Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))
                        activity.startActivity(intent); result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("settings_unavailable", e.javaClass.simpleName + ": " + (e.message ?: ""), null) }
        }
    }
}
