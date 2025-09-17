import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'location_service.dart';

/// Simple SMS service using url_launcher for reliable SMS functionality
class SMSServiceSimple {
  // final LocationService _locationService = LocationService();
  
  /// Request SMS permissions
  Future<bool> requestSMSPermission() async {
    try {
      var status = await Permission.sms.request();
      debugPrint('📱 SMS Permission Status: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error requesting SMS permission: $e');
      return false;
    }
  }

  /// Send emergency alert to all verified contacts
  Future<void> sendEmergencyAlert(String userId, Position position) async {
    try {
      debugPrint('🚨 Starting emergency alert process...');
      
      // Get verified contacts
      final contacts = await _getVerifiedContacts(userId);
      if (contacts.isEmpty) {
        throw Exception('No verified emergency contacts found. Please add and verify contacts first.');
      }

      // Create emergency message
      final message = _createEmergencyMessage(position);
      debugPrint('📝 Emergency message created: $message');

      // Send SMS to each contact using url_launcher
      int successCount = 0;
      for (var contact in contacts) {
        final phoneNumber = contact['phone'] as String;
        final name = contact['name'] as String;
        
        try {
          await _sendSMSViaUrlLauncher(phoneNumber, message);
          successCount++;
          debugPrint('✅ SMS sent successfully to $name ($phoneNumber)');
        } catch (e) {
          debugPrint('❌ Failed to send SMS to $name ($phoneNumber): $e');
        }
      }

      // Log the alert in Firestore
      await _logAlert(userId, position, contacts.length, successCount);
      
      if (successCount == 0) {
        throw Exception('Failed to send SMS to any contacts. Please check your SMS app.');
      }
      
      debugPrint('🎉 Emergency alert completed. Sent to $successCount/${contacts.length} contacts');
      
    } catch (e) {
      debugPrint('❌ Emergency alert failed: $e');
      rethrow;
    }
  }

  /// Send verification SMS to a contact
  Future<void> sendVerificationSMS(String phoneNumber, String contactName) async {
    try {
      final otp = _generateOTP();
      final message = 'SafeHer Verification: Your contact $contactName has added you as an emergency contact. '
                     'Your verification code is: $otp. Reply with this code to confirm. '
                     'This ensures you can receive emergency alerts if needed.';
      
      await _sendSMSViaUrlLauncher(phoneNumber, message);
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
  Future<void> _logAlert(String userId, Position position, int totalContacts, int successCount) async {
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
        'sentTo': '$successCount verified contacts',
        'totalContacts': totalContacts,
        'successCount': successCount,
        'status': successCount > 0 ? 'sent' : 'failed',
        'method': 'url_launcher_sms',
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
