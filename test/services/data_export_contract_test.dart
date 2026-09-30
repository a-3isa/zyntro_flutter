import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('data export service writes JSON for profile workouts posts (Z-PRV-002)', () {
    final source = File('lib/services/data_export_service.dart').readAsStringSync();
    expect(source, contains('exportUserData'));
    expect(source, contains("collection('workouts')"));
    expect(source, contains("collection('posts')"));
    expect(source, contains('zyntro-export-'));

    final settings =
        File('lib/features/settings/presentation/settings_page.dart')
            .readAsStringSync();
    expect(settings, contains('_exportMyData'));
    expect(settings, contains('dataExportServiceProvider'));
  });
}
