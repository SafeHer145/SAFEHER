package com.example.safeher.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_DELIVER_ACTION == intent.action) {
            try {
                val msgs = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                for (msg in msgs) {
                    Log.d("SafeHerSms", "SMS_DELIVER from ${msg.originatingAddress}: ${msg.messageBody}")
                }
            } catch (e: Exception) {
                Log.e("SafeHerSms", "Error handling SMS_DELIVER: ${e.localizedMessage}")
            }
        }
    }
}
