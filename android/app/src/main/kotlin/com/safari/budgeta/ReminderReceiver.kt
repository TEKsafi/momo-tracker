package com.safari.budgeta

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("ReminderReceiver", "Alarm received: ${intent.action}")

        val notificationId = intent.getIntExtra("notificationId", 9002)
        val intervalMinutes = intent.getIntExtra("intervalMinutes", 30)

        val channelId = "cash_reminders"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Cash reminders",
                NotificationManager.IMPORTANCE_HIGH,
            )
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setContentTitle("Record cash on hand")
            .setContentText("Did you spend or receive cash? Add it before you forget.")
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(notificationId, builder.build())
        Log.d("ReminderReceiver", "Notification posted id=$notificationId intervalMinutes=$intervalMinutes")

        if (intent.action == "com.safari.budgeta.INTERVAL_REMINDER") {
            ReminderScheduler.scheduleIntervalAlarm(context, intervalMinutes)
        }
    }
}
