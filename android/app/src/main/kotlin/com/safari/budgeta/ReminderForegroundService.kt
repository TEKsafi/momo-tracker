package com.safari.budgeta

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class ReminderForegroundService : Service() {
    companion object {
        const val ACTION_START = "com.safari.budgeta.START_REMINDER"
        const val ACTION_STOP = "com.safari.budgeta.STOP_REMINDER"
        const val CHANNEL_ID = "cash_reminder"
        const val NOTIFICATION_ID = 2002
    }

    private val handler = Handler(Looper.getMainLooper())
    private var nextRun: Runnable? = null
    private var intervalMs: Long = 30L * 60L * 1000L

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopLoop()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val minutes = intent?.getIntExtra("intervalMinutes", 30) ?: 30
                intervalMs = (minutes.coerceAtLeast(1) * 60L * 1000L)
                startLoop()
                val notification = buildNotification(minutes)
                startForeground(NOTIFICATION_ID, notification)
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopLoop()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Cash reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Tracks your chosen reminder cadence and posts a cash-flow check-in"
                enableVibration(true)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(minutes: Int): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Budgeta cash reminder")
            .setContentText("Next reminder in ${minutes} minute${if (minutes == 1) "" else "s"}.")
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .build()
    }

    private fun startLoop() {
        stopLoop()
        nextRun = object : Runnable {
            override fun run() {
                showReminderNotification()
                handler.postDelayed(this, intervalMs)
            }
        }
        handler.postDelayed(nextRun!!, intervalMs)
    }

    private fun stopLoop() {
        nextRun?.let { handler.removeCallbacks(it) }
        nextRun = null
    }

    private fun showReminderNotification() {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Record cash on hand")
            .setContentText("Did you spend or receive cash? Add it before you forget.")
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID + 1, builder.build())
    }
}
