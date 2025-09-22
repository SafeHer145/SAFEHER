import 'dart:math';
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

  Future<bool> _sendProgrammaticSMS(String phone, String message) async {
    try {
      final bool? ok = await _smsChannel.invokeMethod('sendSMS', {
        'phone': phone,
        'message': message,
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

      // Send SMS to each contact (programmatic first, then fallback)
      int successCount = 0;
      int preparedCount = 0; // messages opened in SMS app but not auto-sent
      for (final contact in contacts) {
        try {
          final phone = contact['phone'];
          final name = contact['name'] ?? 'Contact';
          final message = emergencyMessage;
          // Try programmatic send first if permission granted
          bool sent = false;
          if (await Permission.sms.isGranted || await requestSMSPermission()) {
            sent = await _sendProgrammaticSMS(phone, message);
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
      
      // Return both counts so caller can show accurate status
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
      final message = 'SafeHer Verification: Your contact $contactName has added you as an emergency contact. '
                     'Your verification code is: $code. Reply with this code to confirm. '
                     'This ensures you can receive emergency alerts if needed.';
      
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
