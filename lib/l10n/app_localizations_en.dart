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
  String get verificationEmailSentWithSpam =>
      'We\'ve sent a verification link to your email. Please verify to continue.\n\nIf you don\'t see the email in a minute, please check your Spam/Promotions folder and mark it as Not spam.';

  @override
  String get iveVerified => 'I\'ve Verified';

  @override
  String get resendEmail => 'Resend Email';

  @override
  String get skip => 'Skip';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get Started';

  @override
  String get tutWelcomeTitle => 'Welcome to SafeHer';

  @override
  String get tutWelcomeDesc =>
      'Your personal safety companion that keeps you protected 24/7';

  @override
  String get tutRegisterTitle => 'Register & Login';

  @override
  String get tutRegisterDesc =>
      'Create your account using phone number or email for secure access';

  @override
  String get tutContactsTitle => 'Add Emergency Contacts';

  @override
  String get tutContactsDesc =>
      'Add up to 5 trusted contacts who will receive your emergency alerts';

  @override
  String get tutSosTitle => 'SOS Emergency Button';

  @override
  String get tutSosDesc =>
      'Press the SOS button to instantly send your location to all emergency contacts';

  @override
  String get tutOfflineTitle => 'Offline SMS Delivery';

  @override
  String get tutOfflineDesc =>
      'Emergency alerts work even without internet - SMS is sent directly to contacts';
}
