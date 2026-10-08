package com.ambi.tiffe

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tiffe/delivery_notifications")
            .setMethodCallHandler { call, result ->
                if (call.method != "start") { result.notImplemented(); return@setMethodCallHandler }
                if (pendingResult != null) { result.error("busy", "Notification permission is already being requested", null); return@setMethodCallHandler }
                if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    pendingResult = result
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2301)
                } else { result.success(scheduleJourney()) }
            }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 2301) {
            val result = pendingResult
            pendingResult = null
            result?.success(if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) scheduleJourney() else false)
        }
    }
    private fun scheduleJourney(): Boolean {
        val manager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        if (!manager.areNotificationsEnabled()) return false
        DeliveryNotificationReceiver.createChannel(this)
        val alarm = getSystemService(ALARM_SERVICE) as AlarmManager
        val stages = listOf(Triple(2L, "Tiffin left", "Your dabba has left the kitchen."), Triple(6L, "Tiffin is coming", "A warm meal is getting closer."), Triple(24L, "Tiffin arrived", "Your Tiffe is here. Enjoy your meal!"))
        val base = SystemClock.elapsedRealtime()
        stages.forEachIndexed { index, stage ->
            val intent = Intent(this, DeliveryNotificationReceiver::class.java)
                .putExtra("title", stage.second).putExtra("body", stage.third).putExtra("id", 3100 + index)
            val pending = PendingIntent.getBroadcast(this, 3100 + index, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarm.cancel(pending)
            // No exact-alarm special access required. Android may delay while idle.
            alarm.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, base + stage.first * 1000L, pending)
        }
        return true
    }
}
