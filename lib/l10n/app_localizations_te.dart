// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appTitle => 'సేఫ్‌హర్ - మహిళా భద్రత యాప్';

  @override
  String get sos => 'SOS';

  @override
  String get loginWithPhone => 'ఫోన్ నంబర్ తో లాగిన్';

  @override
  String get loginWithEmail => 'ఇమెయిల్ తో లాగిన్';

  @override
  String get chooseLoginMethod => 'మీ లాగిన్ విధానాన్ని ఎంచుకోండి';

  @override
  String get viewInstructions => 'సూచనలు చూడండి';

  @override
  String get demoButton => 'డెమో ప్రయత్నించండి (సైన్-ఇన్ అవసరం లేదు)';

  @override
  String get verifyYourEmail => 'మీ ఇమెయిల్‌ను ధృవీకరించండి';

  @override
  String get verificationEmailSent =>
      'మీ ఇమెయిల్‌కు ధృవీకరణ లింక్ పంపాము. దయచేసి కొనసాగించడానికి ధృవీకరించండి.';

  @override
  String get verificationEmailSentWithSpam =>
      'మీ ఇమెయిల్‌కు ధృవీకరణ లింక్ పంపాము. దయచేసి కొనసాగించడానికి ధృవీకరించండి.\n\nఒక నిమిషంలో మెయిల్ కనిపించకపోతే, దయచేసి స్పామ్/ప్రోమోషన్స్ ఫోల్డర్‌లో చూసి \'స్పామ్ కాదు\'గా గుర్తించండి.';

  @override
  String get iveVerified => 'నేను ధృవీకరించాను';

  @override
  String get resendEmail => 'ఇమెయిల్ మళ్లీ పంపండి';

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
