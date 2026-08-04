import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An undisposed AnimationController keeps a ticker attached to the scheduler
/// for the life of the app, burning a frame callback every frame and holding
/// its State (and everything the State references) alive.
///
/// The audit flagged 89 `AnimationController` mentions against 62 `dispose()`
/// methods as a possible leak. It was not one — a single dispose() frees
/// several controllers — but nothing stopped the next one from leaking, so this
/// scans for it instead of trusting a count.
void main() {
  test('every AnimationController field is disposed in its own file', () {
    final declaration = RegExp(
      r'(?:late\s+)?(?:final\s+)?AnimationController\??\s+(\w+)\s*[;=]',
    );
    final disposal = RegExp(r'(\w+)\s*\??\.dispose\(\)');

    final offenders = <String>[];
    var fieldsChecked = 0;

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final source = entity.readAsStringSync();
      final declared = declaration
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();
      if (declared.isEmpty) continue;

      final disposed = disposal
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();

      fieldsChecked += declared.length;
      final missing = declared.difference(disposed);
      if (missing.isNotEmpty) {
        final path = entity.path.replaceAll(r'\', '/');
        offenders.add('$path: ${missing.join(', ')}');
      }
    }

    // Guard against the scan silently matching nothing and passing vacuously.
    expect(
      fieldsChecked,
      greaterThan(20),
      reason: 'the declaration pattern stopped matching; fix the scan',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'AnimationController(s) never passed to dispose():\n'
          '${offenders.join('\n')}',
    );
  });
}
