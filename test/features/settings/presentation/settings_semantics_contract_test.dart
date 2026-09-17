import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings rows expose Semantics button labels (Z-A11Y-001)', () {
    final source = File(
      'lib/features/settings/presentation/settings_page.dart',
    ).readAsStringSync();

    expect(source, contains('Widget _chevronRow({'));
    expect(source, contains('Widget _dangerRow({'));
    expect(source, contains('Semantics('));
    expect(source, contains('button: true'));
    expect(source, contains(r"sub == null ? label : '$label. $sub'"));
  });
}
