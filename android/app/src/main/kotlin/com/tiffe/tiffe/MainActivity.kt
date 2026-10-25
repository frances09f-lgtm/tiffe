package com.ambi.tiffe

import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

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
    private var orderCode: String? = null
    private var orderMode = false
    private var orderLabel = ""
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerUpdateChannel(flutterEngine)
        cancelDaily()
        val alarms = getSystemService(ALARM_SERVICE) as AlarmManager
        for (id in 3100..3102) {
            val pending = PendingIntent.getBroadcast(this, id, Intent(this, DeliveryNotificationReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarms.cancel(pending)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tiffe/delivery_notifications")
            .setMethodCallHandler { call, result ->
                if (call.method == "consumeDailyTap") { val open = intent.getBooleanExtra("open_daily_tracker", false); intent.removeExtra("open_daily_tracker"); result.success(open); return@setMethodCallHandler }
                if (call.method == "cancelDaily") { cancelDaily(); result.success(true); return@setMethodCallHandler }
                if (call.method == "cancelOrder") { cancelOrder(call.argument<String>("code") ?: ""); result.success(true); return@setMethodCallHandler }
                if (call.method != "start" && call.method != "scheduleDaily" && call.method != "scheduleOrder") { result.notImplemented(); return@setMethodCallHandler }
                if (pendingResult != null) { result.error("busy", "Notification permission is already being requested", null); return@setMethodCallHandler }
                dailyMode = call.method == "scheduleDaily"
                orderMode = call.method == "scheduleOrder"
                if (orderMode) { orderCode = call.argument<String>("code"); orderLabel = call.argument<String>("label") ?: "" }
                if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    pendingResult = result
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2301)
                } else { result.success(runMode()) }
            }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 2301) {
            val result = pendingResult
            pendingResult = null
            result?.success(if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) runMode() else false)
        }
    }
    override fun onNewIntent(newIntent: Intent) { super.onNewIntent(newIntent); setIntent(newIntent) }
    private fun runMode(): Boolean = if (orderMode) scheduleOrder(orderCode ?: "", orderLabel) else if (dailyMode) scheduleDaily() else scheduleJourney()
    private fun orderBase(code: String) = 40000 + (code.hashCode() and 0x3fff) * 4
    private fun cancelOrder(code: String) {
        val alarm = getSystemService(ALARM_SERVICE) as AlarmManager
        for (i in 0..3) {
            val pending = PendingIntent.getBroadcast(this, orderBase(code) + i, Intent(this, DeliveryNotificationReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarm.cancel(pending)
        }
    }
    /** Demo order: four phone notifications, 2.5 minutes apart (Delivered at 10 minutes). */
    private fun scheduleOrder(code: String, label: String): Boolean {
        return false // Timer-based notifications disabled.
    }
    private fun cancelDaily() {
        val alarm = getSystemService(ALARM_SERVICE) as AlarmManager
        for (id in 3200..3202) {
            val intent = Intent(this, DeliveryNotificationReceiver::class.java)
            val pending = PendingIntent.getBroadcast(this, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarm.cancel(pending)
        }
    }
    private fun scheduleDaily(): Boolean {
        return false // Timer-based notifications disabled.
    }
    private fun scheduleJourney(): Boolean {
        return false // Timer-based notifications disabled.
    }
    // In-app update: APK is downloaded over HTTP in Dart and handed to the
    // Android package installer here. The only system steps are the one-time
    // "install unknown apps" toggle and the installer confirm, both owned by
    // Android. Also serves the app's versionName and cache dir so the Dart
    // side needs no extra plugins.
    private fun registerUpdateChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "appVersion" -> result.success(
                        packageManager.getPackageInfo(packageName, 0).versionName
                    )
                    "cacheDir" -> result.success(cacheDir.absolutePath)
                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                    )
                    "openInstallSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        }
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        val file = path?.let { File(it) }
                        if (file == null || !file.exists()) {
                            result.error("no_apk", "APK not found: $path", null)
                            return@setMethodCallHandler
                        }
                        val uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.updateprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(
                                uri,
                                "application/vnd.android.package-archive"
                            )
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

}
