package com.example.safeher

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.telephony.SmsManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "safeher/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val phone: String? = call.argument("phone")
                    val message: String? = call.argument("message")
                    if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "phone and message are required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val sms = SmsManager.getDefault()
                        val parts = sms.divideMessage(message)
                        if (parts != null && parts.size > 1) {
                            sms.sendMultipartTextMessage(phone, null, parts, null, null)
                        } else {
                            sms.sendTextMessage(phone, null, message, null, null)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_FAILED", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
