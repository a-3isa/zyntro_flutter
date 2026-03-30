import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/auth/presentation/widgets/auth_error_surface.dart';

void main() {
  testWidgets('renders auth error message and suggestion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuthErrorSurface(
            message: 'Authentication failed.',
            suggestion: 'Please try again.',
          ),
        ),
      ),
    );

    expect(find.text('Authentication failed.'), findsOneWidget);
    expect(find.text('Please try again.'), findsOneWidget);
    expect(find.byType(AuthErrorSurface), findsOneWidget);
  });

  testWidgets('invokes onDismiss callback', (tester) async {
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthErrorSurface(
            message: 'Authentication failed.',
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Dismiss error'));
    await tester.pump();

    expect(dismissed, isTrue);
  });
}
