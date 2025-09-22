import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safeher/services/sms_service_simple.dart';
import 'package:permission_handler/permission_handler.dart';

class SOSButton extends StatelessWidget {
  const SOSButton({super.key});

  Future<void> _sendSOS(BuildContext context) async {
    try {
      // Request permissions
      await Permission.location.request();
      final smsStatus = await Permission.sms.request();

      // Get location
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Resolve current user ID from Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;

      if (userId == null) {
        throw Exception('User not authenticated. Please log in to use SOS.');
      }

      // Use SMS service (programmatic if granted, else fallback to composer)
      final smsService = SMSServiceSimple();
      final result = await smsService.sendEmergencyAlert(userId, position);

      if (context.mounted) {
        final auto = result.autoSent;
        final prepared = result.prepared;
        final granted = smsStatus.isGranted;
        String message;
        if (auto > 0) {
          message = '✅ SOS sent automatically to $auto contact(s).';
          if (prepared > 0) {
            message += ' ✉️ Opened SMS composer for $prepared contact(s).';
          }
        } else if (prepared > 0) {
          message = '✉️ SOS message opened in your SMS app for $prepared contact(s). Please tap Send.';
        } else if (!granted) {
          message = '⚠️ SMS permission denied. Could not auto-send. Please grant SMS permission.';
        } else {
          message = '⚠️ SOS could not be sent. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error sending SOS: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      ),
      onPressed: () => _sendSOS(context),
      child: const Text("🚨 Send SOS", style: TextStyle(fontSize: 18)),
    );
  }
}
