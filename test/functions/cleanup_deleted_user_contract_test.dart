import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleanupDeletedUser covers workouts, sessions, storage (Z-FN-003)', () {
    final source = File('functions/index.js').readAsStringSync();
    expect(source, contains('detachUserFromSessions'));
    expect(source, contains('deleteStoragePrefix'));
    expect(
      source,
      contains('db.collection("workouts").where("userId", "==", uid)'),
    );
    expect(source, contains(r'profilePhotos/${uid}/'));
    expect(source, contains('authorIds", "array-contains"'));
    expect(source, contains('getStorage'));
  });
}
