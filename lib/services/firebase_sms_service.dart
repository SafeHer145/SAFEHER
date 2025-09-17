import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseSMSService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Store verification ID for OTP verification
  static String? _verificationId;
  static int? _resendToken;
  
  /// Send OTP via Firebase Phone Authentication
  static Future<bool> sendOTP({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onVerificationFailed,
    required Function() onVerificationCompleted,
  }) async {
    try {
      debugPrint('🔄 Sending OTP via Firebase to: $phoneNumber');
      
      // Ensure phone number is in E.164 format
      String formattedPhone = _formatPhoneNumber(phoneNumber);
      debugPrint('📱 Formatted phone: $formattedPhone');
      
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('✅ Auto-verification completed');
          onVerificationCompleted();
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Firebase SMS verification failed: ${e.message}');
          onVerificationFailed(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('📤 Firebase OTP sent successfully');
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏰ Auto-retrieval timeout for: $verificationId');
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ Error sending Firebase OTP: $e');
      onVerificationFailed('Failed to send OTP: $e');
      return false;
    }
  }
  
  /// Verify OTP code
  static Future<UserCredential?> verifyOTP({
    required String otp,
    String? verificationId,
  }) async {
    try {
      debugPrint('🔍 Verifying OTP: $otp');
      
      String verId = verificationId ?? _verificationId ?? '';
      if (verId.isEmpty) {
        throw Exception('No verification ID available');
      }
      
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verId,
        smsCode: otp,
      );
      
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      debugPrint('✅ OTP verification successful');
      
      return userCredential;
    } catch (e) {
      debugPrint('❌ OTP verification failed: $e');
      return null;
    }
  }
  
  /// Resend OTP
  static Future<bool> resendOTP({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onVerificationFailed,
    required Function() onVerificationCompleted,
  }) async {
    debugPrint('🔄 Resending OTP to: $phoneNumber');
    return await sendOTP(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onVerificationFailed: onVerificationFailed,
      onVerificationCompleted: onVerificationCompleted,
    );
  }
  
  /// Format phone number to E.164 format
  static String _formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // If starts with 91 (India), add +
    if (digits.startsWith('91') && digits.length == 12) {
      return '+$digits';
    }
    
    // If starts with 0, replace with +91
    if (digits.startsWith('0') && digits.length == 11) {
      return '+91${digits.substring(1)}';
    }
    
    // If 10 digits, assume India and add +91
    if (digits.length == 10) {
      return '+91$digits';
    }
    
    // If already has country code but no +, add it
    if (!phoneNumber.startsWith('+')) {
      return '+$digits';
    }
    
    return phoneNumber;
  }
  
  /// Get current user phone number
  static String? getCurrentUserPhone() {
    return _auth.currentUser?.phoneNumber;
  }
  
  /// Sign out current user
  static Future<void> signOut() async {
    await _auth.signOut();
    _verificationId = null;
    _resendToken = null;
  }
}
