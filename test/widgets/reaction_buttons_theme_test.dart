import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';
import 'package:zyntro_flutter/widgets/premium_effects.dart';
import 'package:zyntro_flutter/widgets/reaction_buttons.dart';

void main() {
  testWidgets('selected reaction does not render pulsing glow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ReactionButtons(
            postId: 'post-1',
            currentReaction: ReactionType.fire,
            reactionCounts: const {ReactionType.fire: 2},
            onReactionTap: (_) {},
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(PulsingGlow), findsNothing,
        reason: 'Selected reaction must not be wrapped in PulsingGlow');
    expect(find.byType(ReactionButtons), findsOneWidget);
  });

  test('reaction burst palette stays on navy and signal', () {
    final source = File('lib/widgets/reaction_buttons.dart').readAsStringSync();

    expect(source.contains('Colors.orange'), isFalse);
    expect(source.contains('Colors.purple'), isFalse);
    expect(source.contains('Colors.amber'), isFalse);
    expect(source.contains('AppColors.navy700'), isTrue);
    expect(source.contains('AppColors.navy800'), isTrue);
    expect(source.contains('AppColors.signal'), isTrue);
    expect(source.contains('AppColors.neonGreen'), isFalse);
  });
}
