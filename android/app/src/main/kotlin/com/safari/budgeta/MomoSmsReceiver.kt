package com.safari.budgeta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import org.json.JSONArray
import java.util.Locale

class MomoSmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "MomoSmsReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val MESSAGE_SOURCES_KEY = "momo_message_sources"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        Log.d(TAG, "SMS broadcast received")

        val bundle = intent.extras ?: return
        val pdus = bundle.get("pdus") as? Array<*> ?: return

        for (pdu in pdus) {
            val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                SmsMessage.createFromPdu(pdu as ByteArray, bundle.getString("format"))
            } else {
                SmsMessage.createFromPdu(pdu as ByteArray)
            }

            val sender = sms.originatingAddress ?: ""
            val body = sms.messageBody ?: ""
            val isFlash = sms.messageClass == SmsMessage.MessageClass.CLASS_0
            val normalizedSender = sender.trim().lowercase(Locale.ROOT)

            Log.d(TAG, "Checking sender=$normalizedSender body=${body.take(120)}")

            if (!isEnabledSender(context, normalizedSender)) {
                Log.d(TAG, "Dropping SMS from disabled sender: $normalizedSender")
                continue
            }

            val senderMatches = MomoSmsParser.isMomoSender(sender)
            val bodyLooksLikeMomo = MomoSmsParser.isMomoBody(body)
            if (!senderMatches && !bodyLooksLikeMomo) {
                Log.d(TAG, "No MoMo match for sender=$normalizedSender body=${body.take(120)}")
                continue
            }

            val parsed = MomoSmsParser.parse(sender, body, isFlash)
            Log.d(TAG, "M-Money alert received: sender=${parsed.sender}, amount=${parsed.amount}, referenceId=${parsed.referenceId}, flash=${parsed.isFlash}, body=${parsed.rawBody}")

            val messageIntent = Intent("com.safari.budgeta.MOMO_SMS_RECEIVED")
            messageIntent.putExtra("sender", parsed.sender)
            messageIntent.putExtra("amount", parsed.amount)
            messageIntent.putExtra("referenceId", parsed.referenceId)
            messageIntent.putExtra("body", parsed.rawBody)
            messageIntent.putExtra("isFlash", parsed.isFlash)
            context.sendBroadcast(messageIntent)

            // Enable this if you want to block the default SMS from being processed further.
            // abortBroadcast()
        }
    }

    private fun isEnabledSender(context: Context, senderLower: String): Boolean {
        val fallbackKeywords = listOf("m-money", "mtnmomo", "mtn", "momo")
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(MESSAGE_SOURCES_KEY, null)

            if (raw.isNullOrBlank()) {
                Log.d(TAG, "No sender list found, using M-Money safe defaults")
                return fallbackKeywords.any { senderLower.contains(it) }
            }

            val array = JSONArray(raw)
            val enabledKeywords = mutableListOf<String>()

            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                if (!item.optBoolean("enabled", true)) continue

                val keywords = item.optJSONArray("senderKeywords") ?: continue
                for (j in 0 until keywords.length()) {
                    val keyword = keywords.getString(j).trim().lowercase(Locale.ROOT)
                    if (keyword.isNotEmpty()) {
                        enabledKeywords.add(keyword)
                    }
                }
            }

            if (enabledKeywords.isEmpty()) {
                Log.d(TAG, "Sender list exists but no enabled entries; using M-Money safe defaults")
                return fallbackKeywords.any { senderLower.contains(it) }
            }

            val allKeywords = (enabledKeywords + fallbackKeywords).distinct()
            val matchFound = allKeywords.any { keyword -> senderLower.contains(keyword) }
            Log.d(TAG, "Sender evaluation: sender=$senderLower matchFound=$matchFound enabledKeywords=$allKeywords")
            return matchFound
        } catch (t: Throwable) {
            Log.e(TAG, "Sender preference lookup failed", t)
            return fallbackKeywords.any { senderLower.contains(it) }
        }
    }
}
