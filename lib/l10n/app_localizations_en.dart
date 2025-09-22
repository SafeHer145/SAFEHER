// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SafeHer - Women Safety App';

  @override
  String get sos => 'SOS';

  @override
  String get loginWithPhone => 'Login with Phone Number';

  @override
  String get loginWithEmail => 'Login with Email';

  @override
  String get chooseLoginMethod => 'Choose your login method';

  @override
  String get viewInstructions => 'View Instructions';

  @override
  String get demoButton => 'Try DEMO (No Sign-in)';

  @override
  String get verifyYourEmail => 'Verify your email';

  @override
  String get verificationEmailSent =>
      'We\'ve sent a verification link to your email. Please verify to continue.';

  @override
  String get iveVerified => 'I\'ve Verified';

  @override
  String get resendEmail => 'Resend Email';
}
