import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audit findings meta reflects closed backlog (Z-REPO-004 deferred only)', () {
    final raw = File(
      'docs/audits/2026-09-17-full-audit-findings.json',
    ).readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final meta = json['meta'] as Map<String, dynamic>;
    expect(meta['playBlockers'], isEmpty);
    expect(meta['appStoreBlockers'], isEmpty);
    final findings = json['findings'] as List<dynamic>;
    final deferred = findings
        .where((f) => (f as Map)['status'] == 'deferred')
        .map((f) => (f as Map)['id'])
        .toList();
    expect(deferred, ['Z-REPO-004']);
    final open = findings.where((f) => (f as Map)['status'] == 'open');
    expect(open, isEmpty);
  });
}
