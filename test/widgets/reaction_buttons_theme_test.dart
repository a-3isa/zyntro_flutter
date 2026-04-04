import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';
import 'package:zyntro_flutter/widgets/premium_effects.dart';
import 'package:zyntro_flutter/widgets/reaction_buttons.dart';

void main() {
  testWidgets('selected reactions use the approved neon-green treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ReactionButtons(
            postId: 'post-1',
            currentReaction: ReactionType.fire,
            reactionCounts: const {ReactionType.fire: 5},
            onReactionTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(PulsingGlow), findsNothing);

    final selectedEmoji = tester.widget<Text>(find.text('🔥'));
    final selectedContainer = tester
        .widgetList<AnimatedContainer>(
          find.descendant(
            of: find.byType(ReactionButtons),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .first;
    final decoration = selectedContainer.decoration! as BoxDecoration;

    expect(selectedEmoji.style?.color, AppColors.neonGreen);
    expect(decoration.border, isNotNull);
    expect(
      (decoration.border! as Border).top.color,
      AppColors.neonGreen.withValues(alpha: 0.55),
    );
    expect(decoration.gradient, isNotNull);
    expect(decoration.gradient, isA<LinearGradient>());
    expect(
      (decoration.gradient! as LinearGradient).colors,
      contains(AppColors.neonGreen.withValues(alpha: 0.08)),
    );
    expect(decoration.boxShadow, isNotNull);
    expect((decoration.boxShadow!.single.color.a * 255.0).round(), 64);
  });

  test('reaction burst palette stays on the navy and neon system', () {
    final source = File('lib/widgets/reaction_buttons.dart').readAsStringSync();

    expect(source.contains('Colors.orange'), isFalse);
    expect(source.contains('Colors.purple'), isFalse);
    expect(source.contains('Colors.amber'), isFalse);
    expect(source.contains('AppColors.navy700'), isTrue);
    expect(source.contains('AppColors.navy800'), isTrue);
    expect(source.contains('AppColors.neonGreen'), isTrue);
  });
}
