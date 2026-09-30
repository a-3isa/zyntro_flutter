import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/services/content_filter_service.dart';

void main() {
  late ContentFilterService service;

  setUp(() {
    service = ContentFilterService();
  });

  group('containsProfanity', () {
    test('is false for empty text', () {
      expect(service.containsProfanity(''), isFalse);
    });

    test('is false for ordinary text', () {
      expect(service.containsProfanity('Great session today'), isFalse);
    });

    test('is true for profanity', () {
      expect(service.containsProfanity('this is shit'), isTrue);
    });
  });

  group('gym vocabulary is not treated as profanity', () {
    // The app is a workout tracker, so a filter that flags lifting terminology
    // would block legitimate post titles and exercise names. Several Olympic
    // and powerlifting movements are words a naive filter trips on.
    const liftingTerms = [
      'Clean and jerk',
      'Snatch',
      'Hang clean',
      'Push press',
      'Hip thrust',
      'Sumo deadlift',
      'Back squat',
      'Bench press',
      'Butterfly machine',
      'Skull crushers',
      'Bent-over row',
      'Farmer carry',
    ];

    for (final term in liftingTerms) {
      test('"$term" is allowed', () {
        expect(service.containsProfanity(term), isFalse, reason: term);
        expect(
          () => service.validateText(term, 'title'),
          returnsNormally,
          reason: term,
        );
      });
    }
  });

  group('allowlisted gym terms', () {
    test('an allowlisted term is not reported as a detected word', () {
      expect(service.getDetectedWords('Snatch'), isEmpty);
    });

    test('an allowlisted term is left uncensored', () {
      expect(service.censorText('Snatch PR today'), 'Snatch PR today');
    });

    test('allowlisting is case-insensitive', () {
      for (final variant in ['snatch', 'Snatch', 'SNATCH']) {
        expect(service.containsProfanity(variant), isFalse, reason: variant);
      }
    });

    test('real profanity beside an allowlisted term is still caught', () {
      // The allowlist must not become a way to smuggle profanity through.
      expect(service.containsProfanity('snatch this shit'), isTrue);
      expect(service.getDetectedWords('snatch this shit'), contains('shit'));
      expect(service.getDetectedWords('snatch this shit'), isNot(contains('snatch')));
    });
  });

  group('censorText', () {
    test('leaves empty text alone', () {
      expect(service.censorText(''), '');
    });

    test('leaves clean text unchanged', () {
      expect(service.censorText('Leg day'), 'Leg day');
    });

    test('masks profanity rather than deleting the text', () {
      final censored = service.censorText('this is shit');

      expect(censored, isNot(contains('shit')));
      expect(censored, contains('this is '));
    });
  });

  group('getDetectedWords', () {
    test('is empty for empty text', () {
      expect(service.getDetectedWords(''), isEmpty);
    });

    test('is empty for clean text', () {
      expect(service.getDetectedWords('Morning run'), isEmpty);
    });

    test('reports the offending word', () {
      expect(service.getDetectedWords('this is shit'), contains('shit'));
    });
  });

  group('validateText', () {
    test('passes clean text through', () {
      expect(
        () => service.validateText('Chest and triceps', 'post title'),
        returnsNormally,
      );
    });

    test('passes empty text through', () {
      expect(() => service.validateText('', 'post title'), returnsNormally);
    });

    test('throws on profanity', () {
      expect(
        () => service.validateText('this is shit', 'post title'),
        throwsA(isA<ContentFilterException>()),
      );
    });

    test('names the field in the message so the user knows what to fix', () {
      expect(
        () => service.validateText('this is shit', 'post title'),
        throwsA(
          isA<ContentFilterException>().having(
            (e) => e.message,
            'message',
            contains('post title'),
          ),
        ),
      );
    });

    test('does not leak the offending word back to the user', () {
      try {
        service.validateText('this is shit', 'post title');
        fail('expected a ContentFilterException');
      } on ContentFilterException catch (e) {
        expect(e.message, isNot(contains('shit')));
      }
    });
  });

  group('Z-SOC-001 hardened matching', () {
    test('catches leetspeak English', () {
      expect(service.containsProfanity('this is sh1t'), isTrue);
      expect(service.containsProfanity('f.u.c.k off'), isTrue);
    });

    test('catches Spanish blocklist tokens', () {
      expect(service.containsProfanity('que mierda'), isTrue);
      expect(service.containsProfanity('pendejo'), isTrue);
    });

    test('normalize strips separators', () {
      expect(
        ContentFilterService.normalizeForFilter('f.u.c.k'),
        contains('fuck'),
      );
    });

    test('still allows gym vocabulary', () {
      expect(service.containsProfanity('Clean and jerk'), isFalse);
    });
  });
}
