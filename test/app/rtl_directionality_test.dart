import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/core/l10n/locale_provider.dart';
import 'package:zyntro_flutter/l10n/app_localizations.dart';

void main() {
  testWidgets('Arabic locale yields RTL Directionality (Z-I18N-002)', (
    tester,
  ) async {
    late TextDirection captured;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            captured = Directionality.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(captured, TextDirection.rtl);
    expect(isRtlLocale(const Locale('ar')), isTrue);
    expect(isRtlLocale(const Locale('en')), isFalse);
  });
}
