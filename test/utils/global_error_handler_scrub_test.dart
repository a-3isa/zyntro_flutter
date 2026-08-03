import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/utils/global_error_handler.dart';

/// An error whose message carries user content, the way real SDK errors do.
class _NoisyError implements Exception {
  final String message;
  _NoisyError(this.message);
  @override
  String toString() => 'FirebaseException: $message';
}

void main() {
  group('scrubForReport', () {
    test('removes email addresses', () {
      final scrubbed = scrubForReport(
        _NoisyError('No account for a7med3isa000@gmail.com'),
      );

      expect(scrubbed, isNot(contains('a7med3isa000')));
      expect(scrubbed, isNot(contains('gmail.com')));
      expect(scrubbed, contains('[email]'));
    });

    test('removes signed media URLs', () {
      final scrubbed = scrubForReport(
        _NoisyError(
          'Upload failed for https://firebasestorage.googleapis.com/v0/b/x/o/y?token=secret',
        ),
      );

      expect(scrubbed, isNot(contains('firebasestorage')));
      expect(scrubbed, isNot(contains('token=secret')));
      expect(scrubbed, contains('[url]'));
    });

    test('removes Firebase-length document and user ids', () {
      final scrubbed = scrubForReport(
        _NoisyError('Missing doc for user aBcDeFgHiJkLmNoPqRsTuVwX'),
      );

      expect(scrubbed, isNot(contains('aBcDeFgHiJkLmNoPqRsTuVwX')));
      expect(scrubbed, contains('[id]'));
    });

    test('removes phone numbers', () {
      final scrubbed = scrubForReport(_NoisyError('SMS to +20 100 123 4567'));

      expect(scrubbed, isNot(contains('100 123 4567')));
      expect(scrubbed, contains('[phone]'));
    });

    test('keeps the exception type, which is the diagnostic part', () {
      expect(
        scrubForReport(_NoisyError('failed for user@example.com')),
        startsWith('FirebaseException:'),
      );
    });

    test('leaves an error with no identifying content untouched', () {
      expect(
        scrubForReport(StateError('Bad state: no active session')),
        contains('no active session'),
      );
    });

    test('does not mangle short words or ordinary numbers', () {
      final scrubbed = scrubForReport(
        _NoisyError('Expected 3 sets but found 12'),
      );

      expect(scrubbed, contains('Expected 3 sets but found 12'));
    });

    test('truncates a very long message', () {
      // Short words, so nothing here is caught by the id pattern first — this
      // exercises the length ceiling itself.
      final scrubbed = scrubForReport(_NoisyError('set logged ok. ' * 500));

      expect(scrubbed.length, lessThan(400));
      expect(scrubbed, endsWith('[truncated]'));
    });

    test('collapses a single very long token to an id placeholder', () {
      // A 5000-character unbroken token is a blob or a token, never prose.
      expect(scrubForReport(_NoisyError('x' * 5000)), 'FirebaseException: [id]');
    });

    test('scrubs every occurrence, not only the first', () {
      final scrubbed = scrubForReport(
        _NoisyError('one@a.com and two@b.com and three@c.com'),
      );

      expect(scrubbed, isNot(contains('@a.com')));
      expect(scrubbed, isNot(contains('@b.com')));
      expect(scrubbed, isNot(contains('@c.com')));
    });

    test('scrubs a mixture of identifier kinds in one message', () {
      final scrubbed = scrubForReport(
        _NoisyError(
          'user@example.com uid aBcDeFgHiJkLmNoPqRsTuVwX at https://x.test/a',
        ),
      );

      expect(scrubbed, contains('[email]'));
      expect(scrubbed, contains('[id]'));
      expect(scrubbed, contains('[url]'));
      expect(scrubbed, isNot(contains('example.com')));
    });
  });
}
