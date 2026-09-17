import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:zyntro_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/auth/presentation/login_page.dart';
import 'package:zyntro_flutter/features/auth/presentation/providers/auth_controller.dart';
import 'package:zyntro_flutter/features/auth/presentation/signup_page.dart';
import 'package:zyntro_flutter/features/auth/presentation/widgets/social_auth_row.dart';

class MockAuthController extends Mock implements AuthController {}

const _user = AuthUserEntity(
  id: 'user-1',
  email: 'athlete@example.com',
  displayName: 'Athlete',
  photoUrl: null,
  emailVerified: false,
  providerIds: ['password'],
);

Widget _wrap(Widget page, AuthController controller) {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWithValue(controller)],
    child: MaterialApp(
      // LoginPage reads AppLocalizations, so the harness must supply the same
      // delegates MaterialApp.router installs in production.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: page,
    ),
  );
}

void main() {
  group('LoginPage email sign-in', () {
    testWidgets('renders email + password fields and the sign-in action', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoginPage(), MockAuthController()));

      // Hint text is rendered by the decoration, not as a widget label.
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('blocks submit and shows validation errors when empty', (
      tester,
    ) async {
      final controller = MockAuthController();
      await tester.pumpWidget(_wrap(const LoginPage(), controller));

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
      verifyNever(() => controller.signInWithEmail(any(), any()));
    });

    testWidgets('rejects a malformed email before calling the controller', (
      tester,
    ) async {
      final controller = MockAuthController();
      await tester.pumpWidget(_wrap(const LoginPage(), controller));

      await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
      await tester.enterText(find.byType(TextFormField).last, 'Passw0rd!');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      verifyNever(() => controller.signInWithEmail(any(), any()));
    });

    testWidgets('calls signInWithEmail with the trimmed email', (tester) async {
      final controller = MockAuthController();
      when(
        () => controller.signInWithEmail(any(), any()),
      ).thenAnswer((_) async => _user);

      await tester.pumpWidget(_wrap(const LoginPage(), controller));

      await tester.enterText(
        find.byType(TextFormField).first,
        '  athlete@example.com  ',
      );
      await tester.enterText(find.byType(TextFormField).last, 'Passw0rd!');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      verify(
        () => controller.signInWithEmail('athlete@example.com', 'Passw0rd!'),
      ).called(1);
    });

    testWidgets('surfaces the AuthFlowException message on failure', (
      tester,
    ) async {
      final controller = MockAuthController();
      when(() => controller.signInWithEmail(any(), any())).thenThrow(
        const AuthFlowException(
          message: 'Invalid email or password. Please try again.',
          code: 'invalid-credential',
        ),
      );

      await tester.pumpWidget(_wrap(const LoginPage(), controller));

      await tester.enterText(
        find.byType(TextFormField).first,
        'athlete@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'wrongpass');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(
        find.text('Invalid email or password. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('layout fits small phones', () {
    // 360x640 dp — the smallest viewport we support. A RenderFlex overflow
    // would fail the test via the exception reported by the framework.
    Future<void> pumpAt360x640(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(page, MockAuthController()));
      await tester.pumpAndSettle();
    }

    testWidgets('LoginPage renders without overflow', (tester) async {
      await pumpAt360x640(tester, const LoginPage());

      expect(tester.takeException(), isNull);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(SocialAuthRow), findsOneWidget);
    });

    testWidgets('SignUpPage renders without overflow', (tester) async {
      await pumpAt360x640(tester, const SignUpPage());

      expect(tester.takeException(), isNull);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.byType(SocialAuthRow), findsOneWidget);
    });

    testWidgets('LoginPage shows Apple with Google and Facebook on iOS', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const LoginPage(), MockAuthController()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('SignUpPage email sign-up', () {
    testWidgets('renders email, password and confirm fields', (tester) async {
      await tester.pumpWidget(_wrap(const SignUpPage(), MockAuthController()));

      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Create Account'), findsWidgets);
    });

    testWidgets('rejects a weak password', (tester) async {
      final controller = MockAuthController();
      await tester.pumpWidget(_wrap(const SignUpPage(), controller));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'athlete@example.com');
      await tester.enterText(fields.at(1), 'weak');
      await tester.enterText(fields.at(2), 'weak');
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
      verifyNever(() => controller.signUpWithEmail(any(), any()));
    });

    testWidgets('rejects mismatched confirmation', (tester) async {
      final controller = MockAuthController();
      await tester.pumpWidget(_wrap(const SignUpPage(), controller));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'athlete@example.com');
      await tester.enterText(fields.at(1), 'Passw0rd!');
      await tester.enterText(fields.at(2), 'Passw0rd!different');
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
      verifyNever(() => controller.signUpWithEmail(any(), any()));
    });

    testWidgets('calls signUpWithEmail when the form is valid', (tester) async {
      final controller = MockAuthController();
      when(
        () => controller.signUpWithEmail(any(), any()),
      ).thenAnswer((_) async => _user);

      await tester.pumpWidget(_wrap(const SignUpPage(), controller));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'athlete@example.com');
      await tester.enterText(fields.at(1), 'Passw0rd!');
      await tester.enterText(fields.at(2), 'Passw0rd!');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Account').last);
      await tester.pump();

      verify(
        () => controller.signUpWithEmail('athlete@example.com', 'Passw0rd!'),
      ).called(1);
    });

    testWidgets('suggests signing in when the email is already registered', (
      tester,
    ) async {
      final controller = MockAuthController();
      when(() => controller.signUpWithEmail(any(), any())).thenThrow(
        const AuthFlowException(
          message:
              'Unable to create an account with this email. Try signing in or use a different email.',
          code: 'email-already-in-use',
        ),
      );

      await tester.pumpWidget(_wrap(const SignUpPage(), controller));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'athlete@example.com');
      await tester.enterText(fields.at(1), 'Passw0rd!');
      await tester.enterText(fields.at(2), 'Passw0rd!');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Account').last);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Unable to create an account with this email. Try signing in or use a different email.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Try signing in or resetting your password.'),
        findsOneWidget,
      );
    });
  });
}
