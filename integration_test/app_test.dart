import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safeher/main.dart';
import 'package:safeher/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SAFEHER E2E - onboarding to auth choice', () {
    testWidgets('skips tutorial and shows AuthChoicePage', (WidgetTester tester) async {
      // 1) Initialize Firebase (since we don't call main())
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      // 2) Skip tutorial by mocking SharedPreferences key
      SharedPreferences.setMockInitialValues(<String, Object>{
        'has_seen_tutorial': true,
      });

      // 3) Pump the root app
      await tester.pumpWidget(const SafeHerApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 4) Expect Auth Choice screen visible
      expect(find.text('SafeHer'), findsOneWidget);
      // Buttons like phone/email login should be present
      expect(find.byIcon(Icons.phone_android), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });
  });
}
