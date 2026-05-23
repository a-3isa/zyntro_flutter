import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('environment exposure contracts', () {
    test('does not bundle local env files as Flutter assets', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, isNot(contains('    - .env')));
      expect(pubspec, isNot(contains('    - .env.dev')));
      expect(pubspec, isNot(contains('    - .env.staging')));
      expect(pubspec, isNot(contains('    - .env.prod')));
    });

    test('ignores all local env files but keeps examples trackable', () {
      final gitignore = File('.gitignore').readAsStringSync();

      expect(gitignore, contains('.env'));
      expect(gitignore, contains('.env.*'));
      expect(gitignore, contains('!.env.example'));
    });
  });
}
