import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile award card extracted and ARCH slice roadmap exists', () {
    expect(
      File(
        'lib/features/profile/presentation/widgets/profile_award_card.dart',
      ).readAsStringSync(),
      contains('class ProfileAwardCard'),
    );
    final page = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();
    expect(page, contains('ProfileAwardCard'));
    expect(page, isNot(contains('class _AwardCard')));

    final roadmap = File('docs/ARCH_002_SLICES.md').readAsStringSync();
    expect(roadmap, contains('Z-ARCH-002'));
    expect(roadmap, contains('098'));
  });
}
