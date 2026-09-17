package com.safari.budgeta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log

class MomoSmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "MomoSmsReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

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

            val senderMatches = MomoSmsParser.isMomoSender(sender)
            val bodyLooksLikeMomo = MomoSmsParser.isMomoBody(body)
            if (!senderMatches && !bodyLooksLikeMomo) continue

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
}
