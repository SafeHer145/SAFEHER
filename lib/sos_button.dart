import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safeher/services/sms_service.dart';
import 'package:permission_handler/permission_handler.dart';

class SOSButton extends StatelessWidget {
  const SOSButton({super.key});

  Future<void> _sendSOS(BuildContext context) async {
    try {
      // Request permissions
      await Permission.sms.request();
      await Permission.location.request();

      // Get location
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Use SMS service to send emergency alert
      final smsService = SMSService();
      await smsService.sendEmergencyAlert('current_user_id', position);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ SOS Sent Successfully")),
        );
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
