import 'package:flutter/services.dart';

class SMSRoleService {
  static const MethodChannel _roleChannel = MethodChannel('safeher/sms_role');

  Future<bool> isDefaultSmsApp() async {
    try {
      final bool ok = await _roleChannel.invokeMethod('isDefaultSmsApp');
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestDefaultSmsRole() async {
    try {
      final bool ok = await _roleChannel.invokeMethod('requestDefaultSmsRole');
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ensureDefaultSmsAppIfNeeded() async {
    final isDefault = await isDefaultSmsApp();
    if (isDefault) return true;
    await requestDefaultSmsRole();
    // Give the system a moment; user must accept the prompt.
    await Future.delayed(const Duration(seconds: 1));
    return await isDefaultSmsApp();
    }
}
