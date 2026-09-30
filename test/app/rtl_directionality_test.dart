import 'dart:io';

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

  test('session/feed use Directionality-aware insets and announces (Z-I18N-002)',
      () {
    final session = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();
    final postDetail = File(
      'lib/features/feed/presentation/post_detail_page.dart',
    ).readAsStringSync();
    final theme = File('lib/core/theme/app_theme.dart').readAsStringSync();

    expect(session, contains('Directionality.of(context)'));
    expect(session, contains("SemanticsService.announce(\n        '\$partnerName left the session',\n        Directionality.of(context),"));
    expect(postDetail, contains('EdgeInsetsDirectional.only'));
    expect(theme, contains('EdgeInsetsDirectional headerPadding'));
  });
}
