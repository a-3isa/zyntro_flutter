import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/core/l10n/locale_provider.dart';
import 'package:zyntro_flutter/l10n/app_localizations.dart';

Widget _host(Locale locale, Widget child) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('supported locales', () {
    test('ships English and Arabic', () {
      final codes =
          AppLocalizations.supportedLocales.map((l) => l.languageCode).toList();

      expect(codes, containsAll(<String>['en', 'ar']));
    });
  });

  group('translations', () {
    testWidgets('renders English strings for the en locale', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        _host(
          const Locale('en'),
          Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(l10n.signIn, 'Sign In');
      expect(l10n.welcomeBack, 'Welcome back');
    });

    testWidgets('renders Arabic strings for the ar locale', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        _host(
          const Locale('ar'),
          Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(l10n.signIn, 'تسجيل الدخول');
      expect(l10n.welcomeBack, 'أهلاً بعودتك');
    });

    testWidgets('every Arabic string differs from its English original',
        (tester) async {
      late AppLocalizations en;
      late AppLocalizations ar;

      await tester.pumpWidget(_host(
        const Locale('en'),
        Builder(builder: (c) {
          en = AppLocalizations.of(c);
          return const SizedBox();
        }),
      ));
      await tester.pumpWidget(_host(
        const Locale('ar'),
        Builder(builder: (c) {
          ar = AppLocalizations.of(c);
          return const SizedBox();
        }),
      ));

      // A missing Arabic entry silently falls back to English, which looks
      // fine until an Arabic user sees half the screen in English.
      final pairs = <String, List<String>>{
        'signIn': [en.signIn, ar.signIn],
        'signUp': [en.signUp, ar.signUp],
        'welcomeBack': [en.welcomeBack, ar.welcomeBack],
        'emailAddress': [en.emailAddress, ar.emailAddress],
        'password': [en.password, ar.password],
        'forgotPassword': [en.forgotPassword, ar.forgotPassword],
        'enterPassword': [en.enterPassword, ar.enterPassword],
        'signInFailed': [en.signInFailed, ar.signInFailed],
        'tryAgain': [en.tryAgain, ar.tryAgain],
      };

      pairs.forEach((key, value) {
        expect(value[1], isNot(value[0]), reason: '$key is not translated');
      });
    });

    testWidgets('placeholders survive translation', (tester) async {
      late AppLocalizations ar;
      await tester.pumpWidget(_host(
        const Locale('ar'),
        Builder(builder: (c) {
          ar = AppLocalizations.of(c);
          return const SizedBox();
        }),
      ));

      expect(ar.resendInSeconds(30), contains('30'));
    });
  });

  group('text direction', () {
    testWidgets('Arabic lays out right-to-left', (tester) async {
      late TextDirection direction;
      await tester.pumpWidget(
        _host(
          const Locale('ar'),
          Builder(
            builder: (context) {
              direction = Directionality.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(direction, TextDirection.rtl);
    });

    testWidgets('English lays out left-to-right', (tester) async {
      late TextDirection direction;
      await tester.pumpWidget(
        _host(
          const Locale('en'),
          Builder(
            builder: (context) {
              direction = Directionality.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(direction, TextDirection.ltr);
    });
  });

  group('isRtlLocale', () {
    test('is true for Arabic', () {
      expect(isRtlLocale(const Locale('ar')), isTrue);
    });

    test('is false for English', () {
      expect(isRtlLocale(const Locale('en')), isFalse);
    });

    test('covers the other right-to-left languages', () {
      for (final code in ['he', 'fa', 'ur']) {
        expect(isRtlLocale(Locale(code)), isTrue, reason: code);
      }
    });
  });
}
