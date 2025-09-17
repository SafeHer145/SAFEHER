import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/twilio_config.dart';

class TwilioSMSService {
  static const String twilioApiUrl = TwilioConfig.apiUrl;

  /// Send SMS using Twilio API
  static Future<bool> sendSMS({
    required String to,
    required String message,
  }) async {
    try {
      debugPrint('🚀 Sending SMS via Twilio to: $to');
      debugPrint('📱 Message: $message');

      // Prepare authentication header
      String basicAuth = 'Basic ${base64Encode(utf8.encode('${TwilioConfig.accountSid}:${TwilioConfig.authToken}'))}';

      // Prepare request body
      Map<String, String> body = {
        'From': TwilioConfig.twilioPhoneNumber,
        'To': to,
        'Body': message,
      };

      // Make HTTP POST request to Twilio API
      final response = await http.post(
        Uri.parse(twilioApiUrl),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      debugPrint('📊 Twilio Response Status: ${response.statusCode}');
      debugPrint('📊 Twilio Response Body: ${response.body}');

      if (response.statusCode == 201) {
        // Parse response to get message SID
        final responseData = json.decode(response.body);
        final messageSid = responseData['sid'];
        debugPrint('✅ SMS sent successfully via Twilio! Message SID: $messageSid');
        return true;
      } else {
        // Handle error response
        final errorData = json.decode(response.body);
        debugPrint('❌ Twilio SMS failed: ${errorData['message']}');
        debugPrint('❌ Error Code: ${errorData['code']}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Exception sending SMS via Twilio: $e');
      return false;
    }
  }

  /// Send OTP SMS
  static Future<bool> sendOTP({
    required String phoneNumber,
    required String otp,
  }) async {
    String message = '''🔐 SafeHer Security Code

Your verification code: $otp

This code expires in 10 minutes. Do not share this code with anyone.

- SafeHer Team''';

    return await sendSMS(to: phoneNumber, message: message);
  }

  /// Send Emergency Alert SMS
  static Future<bool> sendEmergencyAlert({
    required String phoneNumber,
    required String contactName,
    required String userLocation,
  }) async {
    String message = '''🚨 EMERGENCY ALERT - SafeHer

Your contact needs IMMEDIATE HELP!

Location: $userLocation

This is an automated emergency message. Please contact them immediately or call local emergency services.

Time: ${DateTime.now().toString()}

- SafeHer Emergency System''';

    return await sendSMS(to: phoneNumber, message: message);
  }

  /// Send Contact Verification SMS
  static Future<bool> sendVerificationSMS({
    required String phoneNumber,
    required String otp,
  }) async {
    String message = '''🛡️ SafeHer Contact Verification

Someone has added you as an emergency contact.

Your verification code: $otp

Reply with this code to confirm, or ignore to decline.

You may receive emergency alerts with location information if they need help.

- SafeHer Team''';

    return await sendSMS(to: phoneNumber, message: message);
  }
}
