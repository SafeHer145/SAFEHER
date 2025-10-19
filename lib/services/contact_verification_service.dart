import 'dart:async';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'sms_service_simple.dart';

class ContactVerificationService {
  ContactVerificationService._();
  static final ContactVerificationService instance = ContactVerificationService._();

  static const MethodChannel _smsChannel = MethodChannel('safeher/sms');

  final _otpRegex = RegExp(r'(\d{4,8})');

  /// Start verification for a contact (native SMS only)
  /// - Generates OTP, stores it with expiry in Firestore
  /// - Sends SMS to contact with disclaimer and OTP using native SMS
  /// Returns false (initiated). Automatic verification may occur if SMS is captured elsewhere.
  Future<bool> startVerification({
    required String userId,
    required String contactId,
    required String contactName,
    required String phone,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final now = DateTime.now();
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId);

    // Generate OTP and store with expiry (2 minutes by default)
    final code = SMSServiceSimple().generateOTP();
    final expiresAt = now.add(timeout);

    await docRef.set({
      'verificationStatus': 'pending',
      'verified': false,
      'lastVerificationAttemptAt': Timestamp.fromDate(now),
      'otp': code,
      'otpExpiresAt': Timestamp.fromDate(expiresAt),
    }, SetOptions(merge: true));

    // Send SMS with OTP
    try {
      await SMSServiceSimple().sendVerificationSMS(phone, contactName, otp: code);
    } catch (e) {
      debugPrint('❌ Failed to send verification SMS: $e');
      return false;
    }

    // Initiated
    return false;
  }

  /// Stop SMS User Consent listening
  Future<void> stopListening() async {
    try {
      await _smsChannel.invokeMethod('stopSmsUserConsent');
    } catch (_) {}
  }

  /// Manual verification entry (compare with Firestore-stored OTP)
  Future<bool> verifyManually({
    required String userId,
    required String contactId,
    required String code,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId);

    final snap = await docRef.get();
    if (!snap.exists) return false;
    final data = snap.data() as Map<String, dynamic>;
    final String? storedOtp = data['otp']?.toString();
    final Timestamp? expTs = data['otpExpiresAt'];
    final DateTime? expiresAt = expTs?.toDate();

    if (storedOtp == null || storedOtp.isEmpty) return false;
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) return false;

    if (storedOtp == code.trim()) {
      await _markVerified(docRef);
      return true;
    }
    return false;
  }

  /// Internal: handle an incoming SMS message captured via consent
  Future<bool> _handleIncomingMessage(String userId, String contactId, String? message) async {
    if (message == null || message.isEmpty) return false;

    // Extract first numeric code in the message
    final match = _otpRegex.firstMatch(message);
    if (match == null) return false;
    final receivedCode = match.group(0)!;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId);
    final snap = await docRef.get();
    if (!snap.exists) return false;
    final data = snap.data() as Map<String, dynamic>;
    final otp = data['otp']?.toString();
    final Timestamp? expTs = data['otpExpiresAt'];
    final expiresAt = expTs?.toDate();

    if (otp == null || expiresAt == null) return false;
    if (DateTime.now().isAfter(expiresAt)) return false;
    if (otp != receivedCode) return false;

    await _markVerified(docRef);
    return true;
  }

  Future<void> _markVerified(DocumentReference<Map<String, dynamic>> docRef) async {
    await docRef.set({
      'verificationStatus': 'verified',
      'verified': true,
      'verifiedAt': FieldValue.serverTimestamp(),
      'otp': FieldValue.delete(),
      'otpExpiresAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  /// Fetch the currently stored OTP for a contact and print it to console.
  /// Returns the OTP string if found, otherwise null.
  Future<String?> fetchAndLogOtp({
    required String userId,
    required String contactId,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .doc(contactId);
      final snap = await docRef.get();
      if (!snap.exists) {
        debugPrint('❌ fetchAndLogOtp: contact not found ($contactId)');
        print('❌ fetchAndLogOtp: contact not found ($contactId)');
        return null;
      }
      final data = snap.data() as Map<String, dynamic>;
      final otp = data['otp']?.toString();
      debugPrint('🔎 fetchAndLogOtp: contactId=$contactId -> ${otp ?? 'null'}');
      print('🔎 fetchAndLogOtp: contactId=$contactId -> ${otp ?? 'null'}');
      return otp;
    } catch (e) {
      debugPrint('❌ fetchAndLogOtp error: $e');
      print('❌ fetchAndLogOtp error: $e');
      return null;
    }
  }
}
