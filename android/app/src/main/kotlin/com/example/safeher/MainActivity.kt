package com.example.safeher

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import com.google.android.gms.auth.api.phone.SmsRetriever
import android.app.Activity
import android.app.PendingIntent
import android.app.role.RoleManager
import android.os.Build
import android.provider.Telephony

class MainActivity : FlutterActivity() {
    private val CHANNEL = "safeher/sms"
    private val EVENTS = "safeher/sms_events"
    private var consentReceiver: BroadcastReceiver? = null
    private var pendingConsentResult: MethodChannel.Result? = null
    private val REQ_USER_CONSENT = 2001
    private var eventSink: EventChannel.EventSink? = null

    private val ACTION_SMS_SENT = "com.example.safeher.SMS_SENT"
    private val ACTION_SMS_DELIVERED = "com.example.safeher.SMS_DELIVERED"
    private var sentReceiverRegistered = false
    private var deliveredReceiverRegistered = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Event channel for SMS status callbacks
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                registerSmsStatusReceivers()
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
                unregisterSmsStatusReceivers()
            }
        })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val phone: String? = call.argument("phone")
                    val message: String? = call.argument("message")
                    val messageId: String? = call.argument("messageId")
                    val subIdArg: Int? = call.argument("subscriptionId")
                    if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "phone and message are required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val sms = try {
                            val sm = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                            val resolvedId = subIdArg ?: run {
                                val defaultId = SubscriptionManager.getDefaultSmsSubscriptionId()
                                if (defaultId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                                    defaultId
                                } else {
                                    val list = sm.activeSubscriptionInfoList
                                    if (list != null && list.isNotEmpty()) list[0].subscriptionId else SubscriptionManager.INVALID_SUBSCRIPTION_ID
                                }
                            }
                            if (resolvedId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                                SmsManager.getSmsManagerForSubscriptionId(resolvedId)
                            } else {
                                SmsManager.getDefault()
                            }
                        } catch (e: Exception) {
                            SmsManager.getDefault()
                        }
                        val parts = sms.divideMessage(message)
                        val sentIntent = Intent(ACTION_SMS_SENT).apply {
                            putExtra("phone", phone)
                            putExtra("messageId", messageId ?: "")
                        }
                        val deliveredIntent = Intent(ACTION_SMS_DELIVERED).apply {
                            putExtra("phone", phone)
                            putExtra("messageId", messageId ?: "")
                        }
                        val sentPI = PendingIntent.getBroadcast(this, (messageId ?: phone).hashCode(), sentIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
                        val deliveredPI = PendingIntent.getBroadcast(this, (messageId ?: phone).hashCode(), deliveredIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
                        if (parts != null && parts.size > 1) {
                            val sentIntents = ArrayList<PendingIntent>()
                            val deliveredIntents = ArrayList<PendingIntent>()
                            repeat(parts.size) {
                                sentIntents.add(sentPI)
                                deliveredIntents.add(deliveredPI)
                            }
                            sms.sendMultipartTextMessage(phone, null, parts, sentIntents, deliveredIntents)
                        } else {
                            sms.sendTextMessage(phone, null, message, sentPI, deliveredPI)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_FAILED", e.localizedMessage, null)
                    }
                }
                "getActiveSmsSubscriptions" -> {
                    try {
                        val sm = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                        val list = sm.activeSubscriptionInfoList
                        val mapped = list?.map {
                            mapOf(
                                "id" to it.subscriptionId,
                                "displayName" to (it.displayName?.toString() ?: "SIM"),
                                "number" to (it.number ?: "")
                            )
                        } ?: emptyList<Map<String, Any>>()
                        result.success(mapped)
                    } catch (e: Exception) {
                        result.error("SUBS_ERROR", e.localizedMessage, null)
                    }
                }
                "startSmsUserConsent" -> {
                    if (pendingConsentResult != null) {
                        result.error("ALREADY_LISTENING", "SMS consent already in progress", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val client = SmsRetriever.getClient(this)
                        val task = client.startSmsUserConsent(null) // null = any sender
                        task.addOnSuccessListener {
                            registerConsentReceiver()
                            pendingConsentResult = result
                        }
                        task.addOnFailureListener { e ->
                            result.error("CONSENT_START_FAILED", e.localizedMessage, null)
                        }
                    } catch (e: Exception) {
                        result.error("CONSENT_ERROR", e.localizedMessage, null)
                    }
                }
                "stopSmsUserConsent" -> {
                    unregisterConsentReceiver()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Role channel for requesting/checking default SMS app role
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safeher/sms_role").setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultSmsApp" -> {
                    try {
                        val pkg = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) Telephony.Sms.getDefaultSmsPackage(this) else null
                        result.success(pkg == packageName)
                    } catch (e: Exception) {
                        result.error("ROLE_ERROR", e.localizedMessage, null)
                    }
                }
                "getDefaultSmsPackage" -> {
                    try {
                        val pkg = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) Telephony.Sms.getDefaultSmsPackage(this) else null
                        result.success(pkg ?: "")
                    } catch (e: Exception) {
                        result.error("ROLE_ERROR", e.localizedMessage, null)
                    }
                }
                "requestDefaultSmsRole" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val roleManager = getSystemService(RoleManager::class.java)
                            if (roleManager.isRoleAvailable(RoleManager.ROLE_SMS)) {
                                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.error("ROLE_UNAVAILABLE", "ROLE_SMS not available", null)
                            }
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                            val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
                            intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("ROLE_UNSUPPORTED", "Android version too low", null)
                        }
                    } catch (e: Exception) {
                        result.error("ROLE_REQUEST_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun registerConsentReceiver() {
        if (consentReceiver != null) return
        consentReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (SmsRetriever.SMS_RETRIEVED_ACTION == intent?.action) {
                    val extras = intent.extras
                    val status = extras?.get(SmsRetriever.EXTRA_STATUS) as? com.google.android.gms.common.api.Status
                    when (status?.statusCode) {
                        com.google.android.gms.common.api.CommonStatusCodes.SUCCESS -> {
                            val consentIntent = extras.getParcelable<Intent>(SmsRetriever.EXTRA_CONSENT_INTENT)
                            try {
                                startActivityForResult(consentIntent, REQ_USER_CONSENT)
                            } catch (e: Exception) {
                                pendingConsentResult?.error("CONSENT_INTENT_ERROR", e.localizedMessage, null)
                                clearPending()
                            }
                        }
                        com.google.android.gms.common.api.CommonStatusCodes.TIMEOUT -> {
                            pendingConsentResult?.error("CONSENT_TIMEOUT", "Timed out waiting for SMS", null)
                            clearPending()
                        }
                        else -> {
                            pendingConsentResult?.error("CONSENT_FAILED", "Failed to retrieve SMS", null)
                            clearPending()
                        }
                    }
                }
            }
        }
        val intentFilter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
        registerReceiver(consentReceiver, intentFilter, RECEIVER_EXPORTED)
    }

    private fun unregisterConsentReceiver() {
        consentReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        consentReceiver = null
    }

    private fun clearPending() {
        unregisterConsentReceiver()
        pendingConsentResult = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_USER_CONSENT) {
            if (resultCode == Activity.RESULT_OK) {
                val message = data?.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE)
                pendingConsentResult?.success(message)
            } else {
                pendingConsentResult?.error("CONSENT_DENIED", "User denied SMS read consent", null)
            }
            clearPending()
        }
    }

    private fun registerSmsStatusReceivers() {
        if (!sentReceiverRegistered) {
            registerReceiver(object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    val phone = intent?.getStringExtra("phone") ?: ""
                    val id = intent?.getStringExtra("messageId") ?: ""
                    val payload = hashMapOf(
                        "event" to "sent",
                        "phone" to phone,
                        "id" to id
                    )
                    when (resultCode) {
                        Activity.RESULT_OK -> eventSink?.success(payload)
                        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> eventSink?.success(payload.apply { put("event", "failed"); put("errorCode", "GENERIC_FAILURE") })
                        SmsManager.RESULT_ERROR_NO_SERVICE -> eventSink?.success(payload.apply { put("event", "failed"); put("errorCode", "NO_SERVICE") })
                        SmsManager.RESULT_ERROR_NULL_PDU -> eventSink?.success(payload.apply { put("event", "failed"); put("errorCode", "NULL_PDU") })
                        SmsManager.RESULT_ERROR_RADIO_OFF -> eventSink?.success(payload.apply { put("event", "failed"); put("errorCode", "RADIO_OFF") })
                        else -> eventSink?.success(payload.apply { put("event", "failed"); put("errorCode", resultCode.toString()) })
                    }
                }
            }, IntentFilter(ACTION_SMS_SENT), RECEIVER_EXPORTED)
            sentReceiverRegistered = true
        }
        if (!deliveredReceiverRegistered) {
            registerReceiver(object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    val phone = intent?.getStringExtra("phone") ?: ""
                    val id = intent?.getStringExtra("messageId") ?: ""
                    val payload = hashMapOf(
                        "event" to "delivered",
                        "phone" to phone,
                        "id" to id
                    )
                    when (resultCode) {
                        Activity.RESULT_OK -> eventSink?.success(payload)
                        Activity.RESULT_CANCELED -> eventSink?.success(payload.apply { put("event", "undelivered") })
                        else -> eventSink?.success(payload)
                    }
                }
            }, IntentFilter(ACTION_SMS_DELIVERED), RECEIVER_EXPORTED)
            deliveredReceiverRegistered = true
        }
    }

    private fun unregisterSmsStatusReceivers() {
        // Using anonymous receivers; can't unregister specifically. Keeping registered is fine.
    }
}
