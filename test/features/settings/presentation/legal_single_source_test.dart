import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/features/settings/presentation/privacy_policy_page.dart';
import 'package:zyntro_flutter/features/settings/presentation/data_deletion_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legal pages point at docs markdown assets (Z-PRV-003)', () {
    final privacy =
        File('lib/features/settings/presentation/privacy_policy_page.dart')
            .readAsStringSync();
    final terms =
        File('lib/features/settings/presentation/terms_of_service_page.dart')
            .readAsStringSync();
    final deletion =
        File('lib/features/settings/presentation/data_deletion_page.dart')
            .readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(privacy, contains("assetPath: 'docs/privacy-policy.md'"));
    expect(terms, contains("assetPath: 'docs/terms-of-service.md'"));
    expect(deletion, contains("assetPath: 'docs/data-deletion.md'"));
    expect(pubspec, contains('docs/privacy-policy.md'));
    expect(pubspec, contains('docs/data-deletion.md'));

    final doc = File('docs/privacy-policy.md').readAsStringSync();
    expect(doc, contains('Meta'));
    expect(doc, contains('/legal/data-deletion'));
  });

  testWidgets('privacy policy page renders markdown from asset', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Privacy Policy'), findsWidgets);
    expect(find.textContaining('Meta'), findsWidgets);
  });

  testWidgets('data deletion page renders markdown from asset', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DataDeletionPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Data Deletion'), findsWidgets);
    expect(find.textContaining('Facebook'), findsWidgets);
  });
}
