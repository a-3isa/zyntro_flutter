import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recap share card has copy-stats action (Z-ENH-013 slice)', () {
    final src = File(
      'lib/features/session/presentation/widgets/recap_widgets.dart',
    ).readAsStringSync();
    expect(src, contains('Copy stats'));
    expect(src, contains('Clipboard.setData'));
  });
}
