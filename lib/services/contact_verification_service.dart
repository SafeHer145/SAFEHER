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
    final sms = SMSServiceSimple();

    // 1) Generate and store OTP
    final otp = sms.generateOTP();
    debugPrint('🔐 Generated OTP for contactId=$contactId, phone=$phone -> $otp');
    print('🔐 Generated OTP for contactId=$contactId, phone=$phone -> $otp');
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 10));

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId);

    await docRef.set({
      'verificationStatus': 'pending',
      'otp': otp,
      'otpExpiresAt': Timestamp.fromDate(expiresAt),
      'lastVerificationAttemptAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    // Read-back and log the stored OTP so it always reflects DB state
    try {
      final snapCheck = await docRef.get();
      final dataCheck = snapCheck.data();
      final dbOtp = dataCheck != null ? dataCheck['otp']?.toString() : null;
      debugPrint('📦 Firestore stored OTP for contactId=$contactId -> ${dbOtp ?? 'null'}');
      print('📦 Firestore stored OTP for contactId=$contactId -> ${dbOtp ?? 'null'}');
    } catch (e) {
      debugPrint('⚠️ Could not read-back OTP from Firestore: $e');
    }

    // 2) Send SMS with disclaimer + OTP
    await sms.sendVerificationSMS(phone, contactName, otp: otp);

    // 3) Start SMS User Consent and wait for reply
    try {
      final completer = Completer<bool>();

      // Start listening; returns message string on success
      Future<void>.microtask(() async {
        try {
          final dynamic msg = await _smsChannel.invokeMethod('startSmsUserConsent');
          // If the platform returns immediately with a message, handle it
          _handleIncomingMessage(userId, contactId, msg?.toString()).then(completer.complete).catchError((e) {
            completer.complete(false);
          });
        } on PlatformException catch (_) {
          // Could not start consent; still allow manual flow
          completer.complete(false);
        }
      });

      // Also set a timeout to avoid waiting forever
      final verified = await completer.future.timeout(timeout, onTimeout: () => false);
      // Stop listening regardless
      await stopListening();
      return verified;
    } catch (e) {
      debugPrint('Contact verification consent error: $e');
      await stopListening();
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
    if (otp != code.trim()) return false;

    await _markVerified(docRef);
    return true;
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
