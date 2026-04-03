import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/main/presentation/main_shell.dart';

void main() {
  const testUser = AuthUserEntity(
    id: 'user-1',
    email: 'test@example.com',
    displayName: 'Test User',
    photoUrl: null,
    emailVerified: true,
    providerIds: ['password'],
  );

  testWidgets('main shell renders the approved nav pill and fab', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream<AuthUserEntity?>.value(testUser),
          ),
        ],
        child: MaterialApp(theme: ThemeData.dark(), home: const MainShell()),
      ),
    );

    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(MainShell), findsOneWidget);

    final pillContainer = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(BackdropFilter),
            matching: find.byType(Container),
          ),
        )
        .firstWhere((container) => container.decoration is BoxDecoration);
    final pillDecoration = pillContainer.decoration! as BoxDecoration;

    expect(pillDecoration.color, AppColors.navy800.withValues(alpha: 0.85));
    expect(pillDecoration.border, isA<Border>());
    expect((pillDecoration.border! as Border).top.color, AppColors.navy700);
    expect(pillDecoration.boxShadow, isNotNull);
    expect(
      pillDecoration.boxShadow!.single.color,
      Colors.black.withValues(alpha: 0.32),
    );

    final navIcons = tester.widgetList<Icon>(
      find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byType(Icon),
      ),
    );

    expect(
      navIcons.firstWhere((icon) => icon.icon == Icons.home_rounded).color,
      AppColors.neonGreen,
    );
    expect(
      navIcons.firstWhere((icon) => icon.icon == Icons.people_outline).color,
      AppColors.gray400,
    );

    final navLabels = tester.widgetList<AnimatedDefaultTextStyle>(
      find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byType(AnimatedDefaultTextStyle),
      ),
    );

    expect(
      (navLabels
              .firstWhere(
                (label) =>
                    label.child is Text && (label.child as Text).data == 'Feed',
              )
              .style)
          .color,
      AppColors.neonGreen,
    );
    expect(
      (navLabels
              .firstWhere(
                (label) =>
                    label.child is Text &&
                    (label.child as Text).data == 'Social',
              )
              .style)
          .color,
      AppColors.gray400,
    );

    final fabContainer = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(BackdropFilter),
            matching: find.byType(Container),
          ),
        )
        .firstWhere(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration! as BoxDecoration).shape == BoxShape.circle,
        );
    final fabDecoration = fabContainer.decoration! as BoxDecoration;
    final fabGradient = fabDecoration.gradient! as LinearGradient;
    final fabIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byIcon(Icons.fitness_center),
      ),
    );

    expect(fabGradient.colors, AppColors.primaryGradient);
    expect(fabDecoration.boxShadow, isNotNull);
    expect(
      fabDecoration.boxShadow!.single.color,
      Colors.black.withValues(alpha: 0.35),
    );
    expect(fabIcon.color, AppColors.navy900);
  });
}
