import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/l10n/locale_format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LocaleFormat registers Arabic timeago and formats numbers (Z-I18N-004)', () {
    LocaleFormat.registerTimeagoLocales();
    final relative = LocaleFormat.relative(
      DateTime.now().subtract(const Duration(minutes: 3)),
      locale: const Locale('ar'),
    );
    expect(relative, isNot(contains('minutes ago')));

    final enNum = LocaleFormat.decimal(1234.5, locale: const Locale('en'));
    expect(enNum, contains('1'));
    final arNum = LocaleFormat.compact(1500, locale: const Locale('ar'));
    expect(arNum, isNotEmpty);
  });
}
