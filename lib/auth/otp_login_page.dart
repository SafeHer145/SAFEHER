import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pinput/pinput.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:country_picker/country_picker.dart';
import '../services/firebase_sms_service.dart';
import '../dashboard/dashboard_page.dart';
import 'login_page.dart';
import 'dart:async';

class OTPLoginPage extends StatefulWidget {
  const OTPLoginPage({super.key});

  @override
  State<OTPLoginPage> createState() => _OTPLoginPageState();
}

class _OTPLoginPageState extends State<OTPLoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  // Remove SMS service - using Firebase Auth directly
  
  bool _isLoading = false;
  bool _otpSent = false;
  bool _isNewUser = false;
  String? _verificationId;
  // Remove generated OTP - Firebase handles this
  String _selectedCountryCode = '+91';
  Timer? _timer;
  int _resendTime = 60;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _resendTime = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTime == 0) {
        timer.cancel();
      } else {
        setState(() {
          _resendTime--;
        });
      }
    });
  }

  Future<void> _sendOTP() async {
    if (_phoneController.text.trim().isEmpty) {
      _showSnackBar('Please enter your phone number', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String phoneNumber = _selectedCountryCode + _phoneController.text.trim();
      
      // Check if user exists
      QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .get();

      _isNewUser = userQuery.docs.isEmpty;

      // Send OTP using Firebase Authentication
      bool otpSent = await FirebaseSMSService.sendOTP(
        phoneNumber: phoneNumber,
        onCodeSent: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
          });
          _startTimer();
          _showSnackBar(
            _isNewUser 
              ? 'OTP sent! Please complete registration.'
              : 'OTP sent to your phone!', 
            Colors.green
          );
        },
        onVerificationFailed: (String error) {
          _showSnackBar('Failed to send OTP: $error', Colors.red);
        },
        onVerificationCompleted: () {
          // Auto-verification completed
          _navigateToNextScreen();
        },
      );

      if (!otpSent) {
        _showSnackBar('Failed to send OTP. Please try again.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().length != 6) {
      _showSnackBar('Please enter the 6-digit OTP', Colors.red);
      return;
    }

    if (_isNewUser && _nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String enteredOTP = _otpController.text.trim();
      
      // Verify OTP using Firebase Authentication
      UserCredential? userCredential = await FirebaseSMSService.verifyOTP(
        otp: enteredOTP,
        verificationId: _verificationId,
      );

      if (userCredential != null) {
        String phoneNumber = _selectedCountryCode + _phoneController.text.trim();
        String userId = userCredential.user!.uid;
        
        if (_isNewUser) {
          // Store additional user data for new users
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .set({
            'name': _nameController.text.trim(),
            'phone': phoneNumber,
            'createdAt': FieldValue.serverTimestamp(),
            'authMethod': 'phone',
          });
        } else {
          // Update existing user document with Firebase Auth UID
          QuerySnapshot userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: phoneNumber)
              .get();

          if (userQuery.docs.isNotEmpty) {
            String existingUserId = userQuery.docs.first.id;
            
            // Update the existing document with new auth UID
            await FirebaseFirestore.instance
                .collection('users')
                .doc(existingUserId)
                .update({
              'firebaseAuthUid': userId,
              'lastLoginAt': FieldValue.serverTimestamp(),
            });
            
            userId = existingUserId; // Use the existing user ID
          }
        }
        
        _navigateToNextScreen();
      } else {
        _showSnackBar('Invalid OTP. Please try again.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToNextScreen() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardPage(userId: user.uid),
        ),
      );
    }
  }


  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // Header
              FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.security_rounded,
                        size: 60,
                        color: Colors.pink.shade400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SafeHer',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _otpSent 
                        ? 'Enter verification code'
                        : 'Sign in with your phone number',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              if (!_otpSent) ...[
                // Phone Number Input
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phone Number',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            // Country Code Picker
                            InkWell(
                              onTap: () {
                                showCountryPicker(
                                  context: context,
                                  onSelect: (Country country) {
                                    setState(() {
                                      _selectedCountryCode = '+${country.phoneCode}';
                                    });
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedCountryCode,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                  ],
                                ),
                              ),
                            ),
                            // Phone Number Input
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: GoogleFonts.poppins(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Enter phone number',
                                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Send OTP Button
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 400),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Send OTP',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Switch to Email Authentication
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    icon: const Icon(Icons.alternate_email),
                    label: Text(
                      'Use Email instead',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ] else ...[
                // OTP Verification Section
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  child: Column(
                    children: [
                      // OTP Info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.sms_rounded, color: Colors.blue.shade600, size: 32),
                            const SizedBox(height: 12),
                            Text(
                              'OTP sent to',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '$_selectedCountryCode ${_phoneController.text}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Name Input (for new users)
                      if (_isNewUser) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Full Name',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                                color: Colors.grey.shade50,
                              ),
                              child: TextField(
                                controller: _nameController,
                                style: GoogleFonts.poppins(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Enter your full name',
                                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                  prefixIcon: Icon(Icons.person_rounded, color: Colors.grey.shade500),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // OTP Input
                      Text(
                        'Enter OTP',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Pinput(
                        controller: _otpController,
                        length: 6,
                        defaultPinTheme: PinTheme(
                          width: 50,
                          height: 60,
                          textStyle: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.grey.shade50,
                          ),
                        ),
                        focusedPinTheme: PinTheme(
                          width: 50,
                          height: 60,
                          textStyle: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.pink.shade400, width: 2),
                            color: Colors.white,
                          ),
                        ),
                        submittedPinTheme: PinTheme(
                          width: 50,
                          height: 60,
                          textStyle: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.pink.shade400,
                          ),
                        ),
                        onCompleted: (pin) {
                          _otpController.text = pin;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Resend OTP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive OTP? ",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (_resendTime > 0)
                            Text(
                              'Resend in ${_resendTime}s',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            )
                          else
                            InkWell(
                              onTap: () => _sendOTP(),
                              child: Text(
                                'Resend OTP',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.pink.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isNewUser ? 'Create Account' : 'Verify & Login',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Back Button
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _otpSent = false;
                            _otpController.clear();
                            _nameController.clear();
                          });
                          _timer?.cancel();
                        },
                        child: Text(
                          'Change Phone Number',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),

                      // Switch to Email Authentication while on OTP screen
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                          );
                        },
                        icon: const Icon(Icons.alternate_email),
                        label: Text(
                          'Use Email instead',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Footer
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 600),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        '🛡️ Your safety is our priority',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SafeHer - Women Safety App',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
