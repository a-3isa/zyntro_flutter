import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recap presentation widgets extracted (Z-ARCH-002)', () {
    final widgets = File(
      'lib/features/session/presentation/widgets/recap_widgets.dart',
    ).readAsStringSync();
    expect(widgets, contains('class RecapDoneHeader'));
    expect(widgets, contains('class RecapStatCell'));
    expect(widgets, contains('class RecapPostToFeedSection'));
    expect(widgets, contains('class RecapGhostButton'));

    final page = File(
      'lib/features/session/presentation/recap_page.dart',
    ).readAsStringSync();
    expect(page, contains('RecapDoneHeader'));
    expect(page, contains('recap_widgets.dart'));
    expect(page, isNot(contains('class RecapDoneHeader')));
    expect(page, isNot(contains('class _DoneHeader')));
  });
}
