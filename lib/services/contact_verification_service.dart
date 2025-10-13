import 'dart:async';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'sms_service_simple.dart';
import 'verification_api_client.dart';

class ContactVerificationService {
  ContactVerificationService._();
  static final ContactVerificationService instance = ContactVerificationService._();

  static const MethodChannel _smsChannel = MethodChannel('safeher/sms');

  final _otpRegex = RegExp(r'(\d{4,8})');

  /// Start verification for a contact
  /// - Generates OTP, stores it with expiry, sends SMS with disclaimer
  /// - Starts SMS User Consent to auto-capture reply and verify
  /// Returns true if verified automatically, false if only initiated.
  Future<bool> startVerification({
    required String userId,
    required String contactId,
    required String contactName,
    required String phone,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    // Twilio Verify flow: call backend to send code, then wait for Firestore status to flip to 'verified'
    final now = DateTime.now();
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId);

    // Mark pending in Firestore for UI
    await docRef.set({
      'verificationStatus': 'pending',
      'verified': false,
      'lastVerificationAttemptAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    // Start Verify via backend
    try {
      await const VerificationApiClient().startVerify(phone: phone, userId: userId, contactId: contactId);
    } catch (e) {
      debugPrint('❌ verify/start failed: $e');
      return false;
    }

    // Listen for status change to verified with timeout
    final completer = Completer<bool>();
    final sub = docRef.snapshots().listen((snap) {
      final data = snap.data();
      final status = data?['verificationStatus']?.toString();
      if (status == 'verified' || data?['verified'] == true) {
        if (!completer.isCompleted) completer.complete(true);
      }
    }, onError: (_) {
      if (!completer.isCompleted) completer.complete(false);
    });

    try {
      final ok = await completer.future.timeout(timeout, onTimeout: () => false);
      await sub.cancel();
      return ok;
    } catch (_) {
      await sub.cancel();
      return false;
    }
  }

  /// Stop SMS User Consent listening
  Future<void> stopListening() async {
    try {
      await _smsChannel.invokeMethod('stopSmsUserConsent');
    } catch (_) {}
  }

  /// Manual verification entry
  Future<bool> verifyManually({
    required String userId,
    required String contactId,
    required String code,
  }) async {
    // Use Twilio Verify check via backend. We need the contact phone from Firestore.
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId);

    final snap = await docRef.get();
    if (!snap.exists) return false;
    final data = snap.data() as Map<String, dynamic>;
    final String? phone = data['phone']?.toString();
    if (phone == null || phone.isEmpty) return false;

    try {
      final ok = await const VerificationApiClient().checkVerify(
        phone: phone,
        code: code.trim(),
        userId: userId,
        contactId: contactId,
      );
      return ok;
    } catch (e) {
      debugPrint('❌ verify/check failed: $e');
      return false;
    }
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
