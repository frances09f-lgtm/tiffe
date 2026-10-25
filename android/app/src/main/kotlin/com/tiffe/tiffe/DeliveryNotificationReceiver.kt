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
        // Ignore old timer broadcasts. They do not represent a staff update.
    }
    companion object {
        const val CHANNEL = "tiffe_delivery"
        fun createChannel(context: Context) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "Tiffe delivery updates", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Tiffin left, on-the-way and arrival alerts"
            })
        }
    }
}
