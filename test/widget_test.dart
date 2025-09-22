// ShineNET VPN Widget Tests
// Tests for VPN application functionality

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:shinenet_vpn/main.dart';

void main() {
  testWidgets('VPN App loads successfully', (WidgetTester tester) async {
    // Initialize EasyLocalization for testing
    await EasyLocalization.ensureInitialized();
    
    // Build our VPN app and trigger a frame
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: Locale('en', 'US'),
        child: MyApp(),
      ),
    );

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify that the app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Look for common VPN app elements that should be present
    // This is a basic smoke test to ensure the app structure is intact
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
  });

  testWidgets('VPN connection button exists', (WidgetTester tester) async {
    // Initialize EasyLocalization for testing
    await EasyLocalization.ensureInitialized();
    
    // Build our VPN app
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: Locale('en', 'US'),
        child: MyApp(),
      ),
    );

    // Wait for the app to settle and load
    await tester.pumpAndSettle(Duration(seconds: 3));

    // Look for connection-related UI elements
    // Since the app has dynamic content, we'll look for basic structural elements
    final buttonFinder = find.byType(FloatingActionButton);
    final elevatedButtonFinder = find.byType(ElevatedButton);
    
    // Check if either type of button exists
    expect(buttonFinder.evaluate().isNotEmpty || elevatedButtonFinder.evaluate().isNotEmpty, isTrue);
  });
}
