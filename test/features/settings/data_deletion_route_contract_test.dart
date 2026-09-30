import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public data-deletion route exists for Meta (Z-AUTH-004)', () {
    final router = File('lib/app/navigation/app_router.dart').readAsStringSync();
    expect(router, contains("dataDeletion = '/legal/data-deletion'"));
    expect(router, contains('isOnPublicLegal'));
    expect(router, contains('AppRoutes.dataDeletion'));

    expect(File('lib/features/settings/presentation/data_deletion_page.dart').existsSync(), isTrue);
    expect(File('docs/data-deletion.md').existsSync(), isTrue);
  });
}
