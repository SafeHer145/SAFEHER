import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

/// Simple SMS service using url_launcher for reliable SMS functionality
class SMSServiceSimple {
  // Programmatic SMS channel (Android only)
  static const MethodChannel _smsChannel = MethodChannel('safeher/sms');
  static const EventChannel _smsEventsChannel = EventChannel('safeher/sms_events');

  // Broadcast stream of native SMS events: {event: sent|delivered|failed|undelivered, phone, id, errorCode?}
  static final StreamController<Map<String, dynamic>> _eventsController = StreamController.broadcast();
  static bool _eventsInitialized = false;

  static void _ensureEventListening() {
    if (_eventsInitialized) return;
    _eventsInitialized = true;
    _smsEventsChannel.receiveBroadcastStream().listen((dynamic data) {
      if (data is Map) {
        final mapped = data.map((key, value) => MapEntry(key.toString(), value));
        _eventsController.add(mapped);
      }
    }, onError: (e) {
      debugPrint('❌ SMS events stream error: $e');
    });
  }

  Stream<Map<String, dynamic>> get smsEvents {
    _ensureEventListening();
    return _eventsController.stream;
  }
  
  /// Request SMS permissions
  Future<bool> requestSMSPermission() async {
    try {
      // For programmatic SMS, we need SEND_SMS. If denied, we can still fallback to url_launcher.
      final status = await Permission.sms.request();
      debugPrint('📱 SEND_SMS permission: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error requesting SMS permission: $e');
      return false;
    }
  }

  Future<bool> _sendProgrammaticSMS(String phone, String message, {String? messageId}) async {
    try {
      final bool? ok = await _smsChannel.invokeMethod('sendSMS', {
        'phone': phone,
        'message': message,
        'messageId': messageId,
      });
      return ok == true;
    } catch (e) {
      debugPrint('❌ Programmatic SMS failed: $e');
      return false;
    }
  }

  /// Send emergency alert to all verified contacts.
  /// Returns a record with counts:
  /// - autoSent: messages sent programmatically (confirmed)
  /// - prepared: SMS composer opened for user to send manually
  Future<({int autoSent, int prepared})> sendEmergencyAlert(String userId, Position position) async {
    try {
      debugPrint('🚨 Starting emergency alert process...');
      
      // Get verified contacts
      final contacts = await _getVerifiedContacts(userId);
      if (contacts.isEmpty) {
        throw Exception('No verified emergency contacts found. Please add and verify contacts first.');
      }

      // Create emergency message
      final emergencyMessage = _createEmergencyMessage(position);
      debugPrint('📝 Emergency message created: $emergencyMessage');

      // Prepare event listening
      _ensureEventListening();
      final Map<String, String> pendingIdsByPhone = {};
      int deliveredCount = 0;

      final sub = _eventsController.stream.listen((event) {
        final ev = event['event']?.toString();
        final phoneEv = event['phone']?.toString();
        if (phoneEv != null) {
          if (ev == 'delivered') {
            deliveredCount++;
            debugPrint('📬 Delivered to $phoneEv');
          } else if (ev == 'sent') {
            debugPrint('📤 Sent to $phoneEv');
          } else if (ev == 'failed' || ev == 'undelivered') {
            debugPrint('⚠️ $ev to $phoneEv');
          }
        }
      });

      // Send SMS to each contact (programmatic first, then fallback)
      int successCount = 0;
      int preparedCount = 0; // messages opened in SMS app but not auto-sent
      for (final contact in contacts) {
        try {
          final phone = contact['phone'];
          final name = contact['name'] ?? 'Contact';
          final message = emergencyMessage;
          final msgId = '${userId}_${phone}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
          pendingIdsByPhone[phone] = msgId;
          // Try programmatic send first if permission granted
          bool sent = false;
          if (await Permission.sms.isGranted || await requestSMSPermission()) {
            sent = await _sendProgrammaticSMS(phone, message, messageId: msgId);
          }
          if (!sent) {
            // Fallback: open SMS composer. We do not count as sent since user must tap send.
            await _sendSMSViaUrlLauncher(phone, message);
            preparedCount++;
          }
          if (sent) {
            debugPrint('✅ Emergency SMS sent (auto) to $name ($phone)');
            successCount++;
          } else {
            debugPrint('✉️ Emergency SMS composer opened for $name ($phone)');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to send to a contact: $e');
        }
      }

      // Log the alert in Firestore
      await _logAlert(userId, position, contacts.length, successCount, preparedCount);
      
      // Small delay to allow final delivered callbacks
      await Future.delayed(const Duration(seconds: 2));
      await sub.cancel();

      // Return counts so caller can show accurate status (delivered is best-effort)
      return (autoSent: successCount, prepared: preparedCount);
      
    } catch (e) {
      debugPrint('❌ Emergency alert failed: $e');
      throw e;
    }
  }

  /// Send verification SMS to a contact. If [otp] is provided, it will be used; otherwise a new OTP will be generated.
  Future<void> sendVerificationSMS(String phoneNumber, String contactName, {String? otp}) async {
    try {
      final code = otp ?? _generateOTP();
      final message = 'SafeHer — Emergency Contact Verification\n\n'
          'Hello, this is SafeHer. The user who owns this phone is adding you as a trusted emergency contact.\n\n'
          'Verification Code: $code\n\n'
          'Disclaimer: Reply with this code ONLY if you recognize this person/number and agree to receive their emergency SMS alerts. '
          'If you do not know this person or did not expect this message, please ignore it.';
      
      // Try programmatic first, fallback to url_launcher
      bool sent = false;
      if (await Permission.sms.isGranted || await requestSMSPermission()) {
        sent = await _sendProgrammaticSMS(phoneNumber, message);
      }
      if (!sent) {
        await _sendSMSViaUrlLauncher(phoneNumber, message);
      }
      debugPrint('✅ Verification SMS sent to $contactName ($phoneNumber)');
      
    } catch (e) {
      debugPrint('❌ Failed to send verification SMS: $e');
      rethrow;
    }
  }

  /// Send SMS using url_launcher (opens native SMS app)
  Future<void> _sendSMSViaUrlLauncher(String phoneNumber, String message) async {
    try {
      // Clean phone number
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Create SMS URL
      final smsUrl = 'sms:$cleanPhone?body=${Uri.encodeComponent(message)}';
      final uri = Uri.parse(smsUrl);
      
      debugPrint('📱 Opening SMS app with URL: $smsUrl');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        debugPrint('✅ SMS app opened successfully');
      } else {
        throw Exception('Could not open SMS app');
      }
      
    } catch (e) {
      debugPrint('❌ Error opening SMS app: $e');
      throw Exception('Failed to open SMS app: $e');
    }
  }

  /// Get verified emergency contacts from Firestore
  Future<List<Map<String, dynamic>>> _getVerifiedContacts(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .where('verified', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
      
    } catch (e) {
      debugPrint('❌ Error getting verified contacts: $e');
      return [];
    }
  }

  /// Create emergency message with location
  String _createEmergencyMessage(Position position) {
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    
    return '🚨 EMERGENCY ALERT from SafeHer 🚨\n\n'
           'I need immediate help! My current location:\n\n'
           '📍 Coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}\n\n'
           '🗺️ View on Maps: $googleMapsUrl\n\n'
           'Please contact me immediately or call emergency services if you cannot reach me.\n\n'
           'Sent via SafeHer Safety App';
  }

  /// Generate 6-digit OTP
  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Public method to generate OTP for external use
  String generateOTP() {
    return _generateOTP();
  }

  /// Log alert in Firestore
  Future<void> _logAlert(String userId, Position position, int totalContacts, int successCount, int preparedCount) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('alerts')
          .add({
        'type': 'emergency_sos',
        'timestamp': FieldValue.serverTimestamp(),
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        },
        'sentAutoCount': successCount,
        'preparedComposerCount': preparedCount,
        'totalContacts': totalContacts,
        'successCount': successCount,
        'status': (successCount > 0 || preparedCount > 0) ? 'attempted' : 'failed',
        'method': successCount > 0 ? 'programmatic_sms' : 'sms_intent',
      });
      
      debugPrint('📊 Alert logged in Firestore');
    } catch (e) {
      debugPrint('❌ Error logging alert: $e');
    }
  }

  /// Send OTP for phone authentication
  Future<void> sendAuthOTP(String phoneNumber, String otp) async {
    try {
      final message = 'SafeHer Login Code: $otp\n\n'
                     'Enter this code to complete your login to SafeHer.\n'
                     'This code expires in 10 minutes.\n\n'
                     'If you did not request this code, please ignore this message.';
      
      await _sendSMSViaUrlLauncher(phoneNumber, message);
      debugPrint('✅ Auth OTP sent to $phoneNumber');
      
    } catch (e) {
      debugPrint('❌ Failed to send auth OTP: $e');
      rethrow;
    }
  }

  /// Check if SMS functionality is available
  Future<bool> isSMSAvailable() async {
    try {
      final uri = Uri.parse('sms:');
      return await canLaunchUrl(uri);
    } catch (e) {
      debugPrint('❌ Error checking SMS availability: $e');
      return false;
    }
  }
}
