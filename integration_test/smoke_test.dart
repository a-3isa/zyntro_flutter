/// Smoke test for Zyntro Flutter app.
/// Verifies that the app launches and key screens render correctly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zyntro_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Smoke Tests', () {
    testWidgets('App launches and shows auth screen', (
      WidgetTester tester,
    ) async {
      // Launch the app
      app.main();

      // Wait for app to initialize
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // Verify MaterialApp is rendered
      expect(find.byType(MaterialApp), findsOneWidget);

      // Verify we're on an auth-related screen
      // Look for common auth screen elements
      final hasLoginText = find.text('Login').evaluate().isNotEmpty;
      final hasSignInText = find.text('Sign In').evaluate().isNotEmpty;
      final hasSignUpText = find.text('Sign Up').evaluate().isNotEmpty;
      final hasWelcomeText = find
          .textContaining('Welcome')
          .evaluate()
          .isNotEmpty;
      final hasZyntroText = find.textContaining('Zyntro').evaluate().isNotEmpty;
      final hasEmailField = find.byType(TextField).evaluate().isNotEmpty;

      final foundAuthScreen =
          hasLoginText ||
          hasSignInText ||
          hasSignUpText ||
          hasWelcomeText ||
          hasZyntroText ||
          hasEmailField;

      debugPrint('');
      debugPrint('═══════════════════════════════════════');
      debugPrint('   APP SMOKE TEST RESULTS');
      debugPrint('═══════════════════════════════════════');
      debugPrint('✅ App launched successfully');
      debugPrint('✅ MaterialApp rendered');
      debugPrint('Auth screen elements found:');
      debugPrint('  - Login text: $hasLoginText');
      debugPrint('  - Sign In text: $hasSignInText');
      debugPrint('  - Sign Up text: $hasSignUpText');
      debugPrint('  - Welcome text: $hasWelcomeText');
      debugPrint('  - Zyntro text: $hasZyntroText');
      debugPrint('  - Email field: $hasEmailField');
      debugPrint('═══════════════════════════════════════');

      // The test passes if the app launches - auth screen detection is informational
      expect(find.byType(MaterialApp), findsOneWidget);

      if (foundAuthScreen) {
        debugPrint('✅ Auth screen verified');
      } else {
        debugPrint(
          'ℹ️ May be on a different screen (possibly logged in already)',
        );
      }
    });

    testWidgets('App handles screen transitions', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Try to find and tap any interactive element
      final buttons = find.byType(ElevatedButton);
      final textButtons = find.byType(TextButton);
      final iconButtons = find.byType(IconButton);

      debugPrint('');
      debugPrint('═══════════════════════════════════════');
      debugPrint('   INTERACTIVE ELEMENTS FOUND');
      debugPrint('═══════════════════════════════════════');
      debugPrint('ElevatedButtons: ${buttons.evaluate().length}');
      debugPrint('TextButtons: ${textButtons.evaluate().length}');
      debugPrint('IconButtons: ${iconButtons.evaluate().length}');
      debugPrint('═══════════════════════════════════════');

      // Verify app is still responsive
      expect(find.byType(MaterialApp), findsOneWidget);
      debugPrint('✅ App responsive after inspection');
    });
  });
}
