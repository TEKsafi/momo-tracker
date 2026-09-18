package com.safari.budgeta

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object ReminderScheduler {
    private const val TAG = "ReminderScheduler"
    private const val DAILY_CHECKIN_REQUEST_CODE = 101
    private const val INTERVAL_REQUEST_CODE = 102

    fun scheduleDailyCheckin(context: Context, hour: Int, minute: Int) {
        Log.d(TAG, "Scheduling daily check-in for ${hour}:${minute}")
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = "com.safari.budgeta.DAILY_CHECKIN"
            putExtra("notificationId", 9001)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            DAILY_CHECKIN_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pendingIntent)

        val calendar = java.util.Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, minute)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
            if (timeInMillis > System.currentTimeMillis()) {
                // keep as-is
            } else {
                add(java.util.Calendar.DAY_OF_YEAR, 1)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent,
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent,
            )
        }
    }

    fun scheduleIntervalAlarm(context: Context, intervalMinutes: Int) {
        val minutes = intervalMinutes.coerceAtLeast(1)
        Log.d(TAG, "Scheduling interval reminder every ${minutes} minutes")
        cancelIntervalAlarm(context)

        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = "com.safari.budgeta.INTERVAL_REMINDER"
            putExtra("notificationId", 9002)
            putExtra("intervalMinutes", minutes)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            INTERVAL_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val triggerAt = System.currentTimeMillis() + (minutes * 60L * 1000L)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent,
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent,
            )
        }
    }

    fun cancelIntervalAlarm(context: Context) {
        Log.d(TAG, "Cancelling active interval reminder")
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = "com.safari.budgeta.INTERVAL_REMINDER"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            INTERVAL_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }
}
