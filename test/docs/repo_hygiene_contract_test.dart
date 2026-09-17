import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('worktrees are ignored and not committed as gitlinks (Z-REPO-002)', () {
    final gitignore = File('.gitignore').readAsStringSync();
    final hygiene = File('docs/REPO_HYGIENE.md').readAsStringSync();

    expect(gitignore, contains('.claude/'));
    expect(gitignore, contains('.worktrees/'));
    expect(hygiene, contains('160000'));
    expect(hygiene, contains('Z-REPO-002'));
  });
}
