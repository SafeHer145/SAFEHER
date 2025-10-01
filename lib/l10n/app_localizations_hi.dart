// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'सेफहर - महिला सुरक्षा ऐप';

  @override
  String get sos => 'आपातकाल (SOS)';

  @override
  String get loginWithPhone => 'फोन नंबर से लॉगिन';

  @override
  String get loginWithEmail => 'ईमेल से लॉगिन';

  @override
  String get chooseLoginMethod => 'अपना लॉगिन तरीका चुनें';

  @override
  String get viewInstructions => 'निर्देश देखें';

  @override
  String get demoButton => 'डेमो आज़माएं (बिना साइन-इन)';

  @override
  String get verifyYourEmail => 'अपना ईमेल सत्यापित करें';

  @override
  String get verificationEmailSent =>
      'हमने आपके ईमेल पर सत्यापन लिंक भेजा है। कृपया जारी रखने के लिए सत्यापित करें।';

  @override
  String get verificationEmailSentWithSpam =>
      'हमने आपके ईमेल पर सत्यापन लिंक भेजा है। कृपया आगे बढ़ने के लिए सत्यापित करें।\n\nयदि आपको एक मिनट में ईमेल नहीं दिखे, तो कृपया स्पैम/प्रोमोशंस फ़ोल्डर देखें और उसे \'स्पैम नहीं\' के रूप में चिन्हित करें।';

  @override
  String get iveVerified => 'मैंने सत्यापित कर लिया है';

  @override
  String get resendEmail => 'ईमेल दोबारा भेजें';

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
