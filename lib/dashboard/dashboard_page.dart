import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/location_service.dart';
import '../services/sms_service_simple.dart';
import '../add_contact_page.dart';
import '../auth/otp_login_page.dart';

class DashboardPage extends StatefulWidget {
  final String userId;
  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isEmergencyActive = false;
  final LocationService _locationService = LocationService();
  final SMSServiceSimple _smsService = SMSServiceSimple();

  Future<void> _triggerSOS() async {
    if (_isEmergencyActive) return;

    setState(() {
      _isEmergencyActive = true;
    });

    try {
      // Haptic feedback for emergency button
      HapticFeedback.heavyImpact();

      // Show immediate feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚨 Emergency Alert Triggered! Getting location..."),
          backgroundColor: Colors.red,
        ),
      );

      // Get current location
      final location = await _locationService.getCurrentLocation();
      
      if (location != null) {
        // Send SMS to all emergency contacts
        await _smsService.sendEmergencyAlert(widget.userId, location);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Emergency alerts sent successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ Could not get location. Please try again."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error sending alert: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEmergencyActive = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OTPLoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "SafeHer",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.pink.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Welcome message
            FadeInDown(
              duration: const Duration(milliseconds: 800),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.pink.shade50, Colors.pink.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.shade200.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 40,
                      color: Colors.pink.shade600,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "🛡️ You're protected with SafeHer",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.pink.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Press the SOS button in emergency",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.pink.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Large SOS Button - Main Feature
            Expanded(
              flex: 2,
              child: Center(
                child: Pulse(
                  infinite: !_isEmergencyActive,
                  duration: const Duration(seconds: 2),
                  child: GestureDetector(
                    onTap: _isEmergencyActive ? null : _triggerSOS,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isEmergencyActive 
                          ? LinearGradient(
                              colors: [Colors.grey.shade400, Colors.grey.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [Colors.red.shade400, Colors.red.shade700],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                        boxShadow: [
                          BoxShadow(
                            color: _isEmergencyActive 
                              ? Colors.grey.withValues(alpha: 0.3)
                              : Colors.red.withValues(alpha: 0.4),
                            spreadRadius: 15,
                            blurRadius: 25,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isEmergencyActive)
                            const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 5,
                            )
                          else
                            Icon(
                              Icons.emergency_rounded,
                              size: 90,
                              color: Colors.white,
                            ),
                          const SizedBox(height: 20),
                          Text(
                            _isEmergencyActive ? "SENDING..." : "SOS",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          if (!_isEmergencyActive)
                            Text(
                              "EMERGENCY",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Action buttons
            Expanded(
              flex: 1,
              child: FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 400),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade500, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade300.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddContactPage(userId: widget.userId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.contacts_rounded, size: 24),
                        label: Text(
                          "Manage Emergency Contacts",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade50, Colors.orange.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.orange.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "The SOS button will send your location to all verified emergency contacts via SMS",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
