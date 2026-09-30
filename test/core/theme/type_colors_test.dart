import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

void main() {
  setUp(() => AppColors.setAccent(AppColors.accentLime));

  group('typeColors covers the real workout types', () {
    test('every WorkoutType value has an entry', () {
      for (final type in WorkoutType.values) {
        expect(
          AppColors.typeColors.containsKey(type.value),
          isTrue,
          reason: '${type.value} has no accent colour',
        );
      }
    });

    test('every category has an entry too', () {
      // Post.type stores a category ('strength' / 'cardio'), and feed_page
      // passes it straight to typeColor.
      for (final category in WorkoutType.values.map((t) => t.category).toSet()) {
        expect(
          AppColors.typeColors.containsKey(category),
          isTrue,
          reason: '$category has no accent colour',
        );
      }
    });
  });

  group('typeColor resolution', () {
    test('cardio types share the sky accent', () {
      expect(AppColors.typeColor('running'), AppColors.accentSky);
      expect(AppColors.typeColor('walking'), AppColors.accentSky);
      expect(AppColors.typeColor('cardio'), AppColors.accentSky);
    });

    test('each distinct discipline keeps its own colour', () {
      expect(AppColors.typeColor('cycling'), AppColors.accentPurple);
      expect(AppColors.typeColor('swimming'), AppColors.accentCyan);
      expect(AppColors.typeColor('yoga'), AppColors.accentEmerald);
      expect(AppColors.typeColor('hiit'), AppColors.warnV2);
    });

    test('gym follows the user accent', () {
      AppColors.setAccent(AppColors.accentPink);
      expect(AppColors.typeColor('gym'), AppColors.accentPink);
    });

    test('an unknown type falls back to the user accent', () {
      AppColors.setAccent(AppColors.accentCyan);
      expect(AppColors.typeColor('kitesurfing'), AppColors.accentCyan);
    });
  });

  group('screens agree on workout type colours', () {
    // The bug this guards: session_page and start_session_page each had their
    // own switch, and they disagreed — cycling was emerald on one screen and
    // purple on the other, with yoga reversed. Both now delegate to
    // AppColors.typeColor, so no screen may reintroduce a local mapping.
    const screens = [
      'lib/features/session/presentation/session_page.dart',
      'lib/features/session/presentation/start_session_page.dart',
    ];

    for (final path in screens) {
      test('${path.split('/').last} has no colour literals of its own', () {
        final source = File(path).readAsStringSync();
        final literals = RegExp(r'Color\(0x[A-Fa-f0-9]{8}\)').allMatches(source);

        expect(
          literals.map((m) => m.group(0)).toList(),
          isEmpty,
          reason: 'route colours through AppColors instead',
        );
      });
    }
  });

  group('user accent choices', () {
    test('offers eight distinct swatches', () {
      expect(AppColors.userAccentChoices, hasLength(8));
      expect(AppColors.userAccentChoices.toSet(), hasLength(8));
    });

    test('leads with the default accent', () {
      expect(AppColors.userAccentChoices.first, AppColors.accentLime);
    });
  });
}
