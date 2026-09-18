package com.safari.budgeta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.safari.budgeta/momo_sms"
    private val eventChannelName = "com.safari.budgeta/momo_sms_events"
    private val reminderChannelName = "com.safari.budgeta/reminders"

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var reminderMethodChannel: MethodChannel
    private var eventSink: EventChannel.EventSink? = null

    private val smsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != "com.safari.budgeta.MOMO_SMS_RECEIVED") return

            val payload = hashMapOf(
                "sender" to (intent.getStringExtra("sender") ?: ""),
                "amount" to (intent.getStringExtra("amount") ?: ""),
                "referenceId" to (intent.getStringExtra("referenceId") ?: ""),
                "body" to (intent.getStringExtra("body") ?: ""),
                "isFlash" to intent.getBooleanExtra("isFlash", false),
            )
            eventSink?.success(payload)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListener" -> {
                    startForegroundListener()
                    result.success(true)
                }
                "stopListener" -> {
                    stopForegroundListener()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        reminderMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, reminderChannelName)
        reminderMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startReminder" -> {
                    val minutes = call.argument<Int>("intervalMinutes") ?: 30
                    ReminderScheduler.scheduleIntervalAlarm(this, minutes)
                    result.success(true)
                }
                "stopReminder" -> {
                    ReminderScheduler.cancelIntervalAlarm(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter("com.safari.budgeta.MOMO_SMS_RECEIVED")
        registerReceiver(smsReceiver, filter)
        startForegroundListener()
    }

    override fun onDestroy() {
        unregisterReceiver(smsReceiver)
        stopForegroundListener()
        super.onDestroy()
    }

    private fun startForegroundListener() {
        val serviceIntent = Intent(this, MomoSmsForegroundService::class.java).apply {
            action = MomoSmsForegroundService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun stopForegroundListener() {
        val serviceIntent = Intent(this, MomoSmsForegroundService::class.java).apply {
            action = MomoSmsForegroundService.ACTION_STOP
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun startReminderService(minutes: Int) {
        val serviceIntent = Intent(this, ReminderForegroundService::class.java).apply {
            action = ReminderForegroundService.ACTION_START
            putExtra("intervalMinutes", minutes)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun stopReminderService() {
        val serviceIntent = Intent(this, ReminderForegroundService::class.java).apply {
            action = ReminderForegroundService.ACTION_STOP
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
}
