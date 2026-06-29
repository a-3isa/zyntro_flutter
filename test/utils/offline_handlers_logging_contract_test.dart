import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline handler stack traces stay debug-only', () {
    final source = File('lib/utils/offline_handlers.dart').readAsStringSync();

    expect(source, contains('import \'package:flutter/foundation.dart\';'));
    expect(source, contains('void _debugPrintStack(StackTrace stack)'));
    expect(source, contains('if (kDebugMode)'));
    expect(
      "debugPrint('[OfflineHandlers] Stack: \$stack');".allMatches(source),
      hasLength(1),
    );
    expect(
      '_debugPrintStack(stack);'.allMatches(source).length,
      greaterThan(1),
    );
  });

  test('session error handler stack traces stay debug-only', () {
    final source = File(
      'lib/utils/session_error_handler.dart',
    ).readAsStringSync();

    expect(source, contains('import \'package:flutter/foundation.dart\';'));
    expect(source, contains('void _debugPrintStack(StackTrace stackTrace)'));
    expect(source, contains('if (kDebugMode)'));
    expect(
      "debugPrint('[SessionErrorHandler] Stack: \$stackTrace');".allMatches(
        source,
      ),
      hasLength(1),
    );
    expect(
      "debugPrint('[SessionErrorHandler] Stack: \$stackTrace');".allMatches(
        source.substring(source.indexOf('static Future<void> handleError')),
      ),
      isEmpty,
    );
  });
}
