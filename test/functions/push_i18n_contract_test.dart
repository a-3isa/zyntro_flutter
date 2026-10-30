import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Cloud Functions push copy supports Arabic (Z-I18N-003)', () {
    // pushCopy moved into functions/lib/push_copy.js, which index.js requires.
    final source = File('functions/index.js').readAsStringSync() +
        File('functions/lib/push_copy.js').readAsStringSync();
    expect(source, contains('async function getUserLocale'));
    expect(source, contains('function pushCopy'));
    expect(source, contains('دعوة جلسة'));
    expect(source, contains('دورك!'));
    expect(source, contains('دعوة صديق تمارين'));
    expect(source, contains('منشور مشترك؟'));
    expect(source, contains('رسالة صوتية'));
    expect(source, contains('انتهت صلاحية المنشور المشترك'));

    final locale = File('lib/core/l10n/locale_provider.dart').readAsStringSync();
    expect(locale, contains("'locale':"));
  });
}
