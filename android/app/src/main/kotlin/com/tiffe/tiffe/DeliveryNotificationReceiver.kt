package com.ambi.tiffe

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

class DeliveryNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        createChannel(context)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!manager.areNotificationsEnabled()) return
        val open = PendingIntent.getActivity(context, 3100, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val notification = builder
            .setSmallIcon(R.drawable.ic_tiffe_notification)
            .setContentTitle(intent.getStringExtra("title") ?: "Tiffe delivery")
            .setContentText(intent.getStringExtra("body") ?: "Your Tiffe journey has an update.")
            .setContentIntent(open).setAutoCancel(true)
            .setCategory(Notification.CATEGORY_STATUS).build()
        manager.notify(intent.getIntExtra("id", 3100), notification)
    }
    companion object {
        const val CHANNEL = "tiffe_delivery"
        fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "Tiffe delivery updates", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Tiffin left, on-the-way and arrival alerts"
            })
        }
    }
}
