import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:telephony/telephony.dart';  // DISCONTINUED PACKAGE
import 'twilio_sms_service.dart';
import 'location_service.dart';

class SMSService {
  final LocationService _locationService = LocationService();
  // final Telephony telephony = Telephony.instance;  // DISCONTINUED PACKAGE
  
  // Enhanced SMS permission handling using permission_handler
  Future<bool> requestSMSPermission() async {
    try {
      var status = await Permission.sms.status;
      if (!status.isGranted) {
        status = await Permission.sms.request();
      }
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting SMS permission: $e');
      return false;
    }
  }

  // Generate OTP
  String generateOTP() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Send emergency SMS using Firebase Auth for contact verification only
  // OTP authentication is now handled by Firebase Auth directly in FirebaseSMSService

  Future<void> sendEmergencyAlert(String userId, Position location) async {
    try {
      debugPrint('🚨 Starting emergency alert for user: $userId');
      debugPrint('📍 Location: ${location.latitude}, ${location.longitude}');
      
      // Request SMS permission first
      bool hasPermission = await requestSMSPermission();
      if (!hasPermission) {
        debugPrint('❌ SMS permission not granted for emergency alert');
        throw Exception('SMS permission not granted');
      }
      
      QuerySnapshot contactsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();

      debugPrint('👥 Found ${contactsSnapshot.docs.length} contacts');

      if (contactsSnapshot.docs.isEmpty) {
        throw Exception('No emergency contacts found. Please add contacts first.');
      }

      String mapsLink = _locationService.generateGoogleMapsLink(location);
      debugPrint('🗺️ Generated maps link: $mapsLink');

      String emergencyMessage = '''🚨 EMERGENCY ALERT - SafeHer 🚨

I need help! This is an automated emergency message.

My current location:
$mapsLink

Coordinates: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}

Please contact me immediately or call emergency services if needed.

- Sent via SafeHer App''';

      List<String> failedContacts = [];
      List<String> sentContacts = [];

      for (var doc in contactsSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          String phoneNumber = data?['phone'] ?? '';
          String contactName = data?['name'] ?? 'Unknown';
          bool isVerified = data?['verified'] ?? false;

          debugPrint('📞 Processing contact: $contactName ($phoneNumber) - Verified: $isVerified');

          // Only send to verified contacts
          if (phoneNumber.isNotEmpty && isVerified) {
            try {
              debugPrint('📤 Sending emergency SMS to: $contactName ($phoneNumber)');
              
              // Try Twilio API first for reliable SMS delivery
              bool twilioSuccess = await TwilioSMSService.sendEmergencyAlert(
                phoneNumber: phoneNumber,
                contactName: contactName,
                userLocation: 'Lat: ${location.latitude.toStringAsFixed(6)}, Lng: ${location.longitude.toStringAsFixed(6)}',
              );
              
              if (twilioSuccess) {
                debugPrint('📊 Emergency SMS sent via Twilio to $contactName');
              } else {
                debugPrint('⚠️ Twilio failed for $contactName, trying device SMS');
                
                // Fallback to device SMS via url_launcher
                debugPrint('📱 Opening SMS app for $contactName');
                  final Uri smsUri = Uri(
                    scheme: 'sms',
                    path: phoneNumber,
                    queryParameters: {'body': emergencyMessage},
                  );
                  
                  if (await canLaunchUrl(smsUri)) {
                    await launchUrl(smsUri);
                    debugPrint('📊 Emergency SMS app opened for $contactName');
                  } else {
                    throw Exception('Cannot launch SMS app for $contactName');
                  }
              }
              await _logAlert(userId, phoneNumber, location);
              
              sentContacts.add(contactName);
              debugPrint('✅ Emergency SMS sent successfully to: $contactName');
              
              // Small delay between SMS sends to avoid rate limiting
              await Future.delayed(const Duration(milliseconds: 500));
              
            } catch (e) {
              failedContacts.add('$contactName ($phoneNumber)');
              debugPrint('❌ SMS failed for $contactName ($phoneNumber): $e');
            }
          } else if (!isVerified) {
            failedContacts.add('$contactName (not verified)');
            debugPrint('⚠️ Skipping unverified contact: $contactName');
          } else {
            debugPrint('⚠️ Skipping contact with empty phone: $contactName');
          }
        } catch (e) {
          failedContacts.add(doc.id);
          debugPrint('❌ Failed to process contact ${doc.id}: $e');
        }
      }

      debugPrint('📊 Emergency Alert Summary:');
      debugPrint('✅ Sent to: ${sentContacts.join(', ')}');
      if (failedContacts.isNotEmpty) {
        debugPrint('❌ Failed: ${failedContacts.join(', ')}');
      }

      if (sentContacts.isEmpty) {
        throw Exception('No emergency alerts were sent. Please verify your contacts.');
      }

      if (failedContacts.isNotEmpty) {
        throw Exception('Some alerts failed: ${failedContacts.join(', ')}');
      }
    } catch (e) {
      debugPrint('❌ Error sending emergency alert: $e');
      rethrow;
    }
  }

  Future<void> _logAlert(String userId, String phoneNumber, Position location) async {
    try {
      await FirebaseFirestore.instance
          .collection('users') // ✅ lowercase
          .doc(userId)
          .collection('alerts') // ✅ lowercase
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
        'sentTo': phoneNumber,
        'status': 'sent',
      });
    } catch (e) {
      debugPrint('Error logging alert: $e');
    }
  }

  // Enhanced verification SMS with OTP using sms_advanced
  Future<bool> sendVerificationSMS(String phoneNumber, String contactName, String otp) async {
    try {
      debugPrint('📞 Sending verification SMS to: $phoneNumber for contact: $contactName');
      debugPrint('🔢 Verification OTP: $otp');
      
      bool hasPermission = await requestSMSPermission();
      if (!hasPermission) {
        debugPrint('❌ SMS permission not granted for verification');
        throw Exception('SMS permission not granted');
      }
      debugPrint('✅ SMS permission granted for verification');

      String verificationMessage = '''SafeHer Contact Verification

Hello! You have been added as an emergency contact for $contactName in the SafeHer women's safety app.

Your verification code: $otp

Reply with this code to confirm, or ignore to decline.

You may receive emergency alerts with location information if they need help.

- SafeHer Team''';

      debugPrint('📱 Verification SMS Message: $verificationMessage');

      // Try Twilio API first for reliable SMS delivery
      bool twilioSuccess = await TwilioSMSService.sendVerificationSMS(
        phoneNumber: phoneNumber,
        otp: otp,
      );
      
      if (twilioSuccess) {
        debugPrint('📊 Verification SMS sent via Twilio');
      } else {
        debugPrint('⚠️ Twilio failed for verification, trying device SMS');
        
        // Fallback to device SMS via url_launcher
        debugPrint('📱 Opening SMS app for verification');
        final Uri smsUri = Uri(
          scheme: 'sms',
          path: phoneNumber,
          queryParameters: {'body': verificationMessage},
        );
        
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
          debugPrint('📊 Verification SMS app opened successfully');
        } else {
          throw Exception('Cannot launch SMS app for verification');
        }
      }
      
      debugPrint('✅ Verification SMS sent successfully to $phoneNumber');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending verification SMS to $phoneNumber: $e');
      return false;
    }
  }
}
