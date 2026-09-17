import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client secrets runbook covers rotation (Z-SEC-009 / Z-AND-004)', () {
    final doc = File('docs/CLIENT_SECRETS.md').readAsStringSync();
    expect(doc, contains('Z-SEC-009'));
    expect(doc, contains('Z-AND-004'));
    expect(doc, contains('restrict'));
    expect(doc, contains('rotate'));
    expect(doc, contains('Facebook App ID'));

    final gitignore = File('.gitignore').readAsStringSync();
    expect(gitignore, contains('.env'));
    expect(gitignore, contains('.codex/'));
  });
}
