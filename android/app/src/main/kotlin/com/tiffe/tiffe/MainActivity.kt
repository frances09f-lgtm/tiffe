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
    private var dailyMode = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tiffe/delivery_notifications")
            .setMethodCallHandler { call, result ->
                if (call.method == "consumeDailyTap") { val open = intent.getBooleanExtra("open_daily_tracker", false); intent.removeExtra("open_daily_tracker"); result.success(open); return@setMethodCallHandler }
                if (call.method == "cancelDaily") { cancelDaily(); result.success(true); return@setMethodCallHandler }
                if (call.method != "start" && call.method != "scheduleDaily") { result.notImplemented(); return@setMethodCallHandler }
                if (pendingResult != null) { result.error("busy", "Notification permission is already being requested", null); return@setMethodCallHandler }
                dailyMode = call.method == "scheduleDaily"
                if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    pendingResult = result
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2301)
                } else { result.success(if (dailyMode) scheduleDaily() else scheduleJourney()) }
            }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 2301) {
            val result = pendingResult
            pendingResult = null
            result?.success(if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) (if (dailyMode) scheduleDaily() else scheduleJourney()) else false)
        }
    }
    override fun onNewIntent(newIntent: Intent) { super.onNewIntent(newIntent); setIntent(newIntent) }
    private fun cancelDaily() {
        val alarm = getSystemService(ALARM_SERVICE) as AlarmManager
        for (id in 3200..3202) {
            val intent = Intent(this, DeliveryNotificationReceiver::class.java)
            val pending = PendingIntent.getBroadcast(this, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarm.cancel(pending)
        }
    }
    private fun scheduleDaily(): Boolean {
        val manager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        if (!manager.areNotificationsEnabled()) return false
        DeliveryNotificationReceiver.createChannel(this)
        val alarm = getSystemService(ALARM_SERVICE) as AlarmManager
        val titles = listOf("Tiffe left", "On the way", "Tiffe arrived")
        val bodies = listOf("Your dabba has left the kitchen.", "A warm meal is on its way to you.", "Your Tiffe is here. Enjoy your meal!")
        val offsets = listOf(0, 6, 24)
        titles.forEachIndexed { index, title ->
            val time = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("Asia/Kolkata")).apply {
                set(java.util.Calendar.HOUR_OF_DAY, 20); set(java.util.Calendar.MINUTE, offsets[index]); set(java.util.Calendar.SECOND, 0); set(java.util.Calendar.MILLISECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) add(java.util.Calendar.DAY_OF_YEAR, 1)
            }
            val intent = Intent(this, DeliveryNotificationReceiver::class.java).putExtra("title", title).putExtra("body", bodies[index]).putExtra("id", 3200 + index).putExtra("daily", true)
            val pending = PendingIntent.getBroadcast(this, 3200 + index, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarm.cancel(pending)
            alarm.setInexactRepeating(AlarmManager.RTC_WAKEUP, time.timeInMillis, AlarmManager.INTERVAL_DAY, pending)
        }
        return true
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
