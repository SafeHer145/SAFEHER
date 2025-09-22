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
  String get iveVerified => 'मैंने सत्यापित कर लिया है';

  @override
  String get resendEmail => 'ईमेल दोबारा भेजें';
}
