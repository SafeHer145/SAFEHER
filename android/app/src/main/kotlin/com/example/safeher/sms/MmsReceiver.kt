package com.example.safeher.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class MmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if ("android.provider.Telephony.WAP_PUSH_DELIVER" == intent.action) {
            Log.d("SafeHerSms", "MMS_DELIVER received")
        }
    }
}
