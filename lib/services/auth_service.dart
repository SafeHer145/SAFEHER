import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Enhanced Firebase Authentication Service for SafeHer
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Store verification ID for OTP verification
  static String? _verificationId;
  static int? _resendToken;

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;

  /// Sign in with email and password
  static Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Signing in with email: $email');
      
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Reload to ensure latest state
      await userCredential.user?.reload();
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-null', message: 'User not available after sign-in');
      }

      // Enforce email verification
      if (!user.emailVerified) {
        try { await user.sendEmailVerification(); } catch (_) {}
        await _auth.signOut();
        throw FirebaseAuthException(code: 'email-not-verified', message: 'Please verify your email before logging in.');
      }

      // Ensure Firestore user exists and is active
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists || (userDoc.data()?['isActive'] == false)) {
        await _auth.signOut();
        throw FirebaseAuthException(code: 'user-inactive', message: 'Your account has been removed or is inactive.');
      }

      debugPrint('✅ Email sign-in successful');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Email sign-in failed: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Unexpected error during email sign-in: $e');
      throw Exception('Failed to sign in. Please try again.');
    }
  }

  /// Register with email and password
  static Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      debugPrint('📝 Registering with email: $email');
      
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(name);
      
      // Create user profile in Firestore
      await _createUserProfile(
        userId: userCredential.user!.uid,
        email: email,
        name: name,
        phone: null,
      );
      
      debugPrint('✅ Email registration successful');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Email registration failed: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Unexpected error during email registration: $e');
      throw Exception('Failed to register. Please try again.');
    }
  }

  /// Send OTP to phone number
  static Future<bool> sendPhoneOTP({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onVerificationFailed,
    required Function() onVerificationCompleted,
  }) async {
    try {
      debugPrint('📱 Sending OTP to: $phoneNumber');
      
      // Format phone number to E.164 format
      String formattedPhone = _formatPhoneNumber(phoneNumber);
      debugPrint('📞 Formatted phone: $formattedPhone');
      
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('✅ Auto-verification completed');
          try {
            UserCredential userCredential = await _auth.signInWithCredential(credential);
            await _handlePhoneSignIn(userCredential, formattedPhone);
            onVerificationCompleted();
          } catch (e) {
            debugPrint('❌ Auto-verification sign-in failed: $e');
            onVerificationFailed('Auto-verification failed');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Phone verification failed: ${e.message}');
          onVerificationFailed(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('📤 OTP sent successfully');
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏰ Auto-retrieval timeout');
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ Error sending OTP: $e');
      onVerificationFailed('Failed to send OTP: $e');
      return false;
    }
  }

  /// Verify OTP and sign in
  static Future<UserCredential?> verifyPhoneOTP({
    required String otp,
    required String name,
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
      await _handlePhoneSignIn(userCredential, userCredential.user?.phoneNumber, name);
      
      debugPrint('✅ Phone OTP verification successful');
      return userCredential;
    } catch (e) {
      debugPrint('❌ OTP verification failed: $e');
      throw Exception('Invalid OTP. Please try again.');
    }
  }

  /// Resend OTP
  static Future<bool> resendPhoneOTP({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onVerificationFailed,
    required Function() onVerificationCompleted,
  }) async {
    debugPrint('🔄 Resending OTP to: $phoneNumber');
    return await sendPhoneOTP(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onVerificationFailed: onVerificationFailed,
      onVerificationCompleted: onVerificationCompleted,
    );
  }

  /// Handle phone sign-in and create/update user profile
  static Future<void> _handlePhoneSignIn(
    UserCredential userCredential, 
    String? phoneNumber, 
    [String? name]
  ) async {
    try {
      String userId = userCredential.user!.uid;
      
      // Check if user profile exists
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        // Create new user profile
        await _createUserProfile(
          userId: userId,
          phone: phoneNumber,
          name: name ?? 'SafeHer User',
          email: userCredential.user?.email,
        );
      } else {
        // Update last login
        await _firestore.collection('users').doc(userId).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('❌ Error handling phone sign-in: $e');
    }
  }

  /// Create user profile in Firestore
  static Future<void> _createUserProfile({
    required String userId,
    String? email,
    String? phone,
    required String name,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      
      debugPrint('✅ User profile created successfully');
    } catch (e) {
      debugPrint('❌ Error creating user profile: $e');
      throw Exception('Failed to create user profile');
    }
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

  /// Handle Firebase Auth exceptions
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'invalid-verification-id':
        return 'Invalid verification ID. Please request a new code.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      _verificationId = null;
      _resendToken = null;
      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Error signing out: $e');
      throw Exception('Failed to sign out');
    }
  }

  /// Get user profile from Firestore
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Update user profile in Firestore
  static Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? email,
    String? phone,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      
      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;
      
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection('users').doc(userId).update(updates);
      debugPrint('✅ User profile updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
      throw Exception('Failed to update profile');
    }
  }
}
