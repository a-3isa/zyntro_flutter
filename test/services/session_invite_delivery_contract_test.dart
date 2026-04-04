import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'session creation persists invitedUserIds for backend push validation',
    () {
      final source = File(
        'lib/services/session_service.dart',
      ).readAsStringSync();

      expect(source, contains("'invitedUserIds': invitedUserIds ?? []"));
    },
  );

  test('post comment push forwards commentId for backend validation', () {
    final source = File('lib/services/post_service.dart').readAsStringSync();

    expect(source, contains('unawaited('));
    expect(
      source,
      contains(
        '_notifyPostComment(postId, userId, userName, text, commentRef.id)',
      ),
    );
    expect(source, contains('Future<void> _notifyPostComment('));
    expect(source, contains('String commentId,'));
    expect(source, contains('commentId: commentId,'));
  });
}
