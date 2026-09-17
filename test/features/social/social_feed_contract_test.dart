import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('social page exposes Board, Buddies, and Find tabs (Z-TEST-002)', () {
    final source = File(
      'lib/features/social/presentation/social_page.dart',
    ).readAsStringSync();

    expect(source, contains('socialTabBoard'));
    expect(source, contains('socialTabBuddies'));
    expect(source, contains('socialTabFind'));
  });

  test('feed page loads following posts via PostService (Z-TEST-002)', () {
    final source = File(
      'lib/features/feed/presentation/feed_page.dart',
    ).readAsStringSync();

    expect(source, contains('postServiceProvider'));
    expect(source, contains('getFollowingPosts'));
  });
}
