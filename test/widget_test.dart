// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safeher/main.dart';


void main() {
  testWidgets('SafeHer app builds and renders initial screen', (WidgetTester tester) async {
    // Build the SafeHer app
    await tester.pumpWidget(const SafeHerApp());

    // Verify that a MaterialApp is present
    expect(find.byType(MaterialApp), findsOneWidget);

    // Let initial async work (like SharedPreferences, Firebase init in tests is skipped) settle
    await tester.pump(const Duration(milliseconds: 100));

    // App should render some content (at least a Scaffold or progress)
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
