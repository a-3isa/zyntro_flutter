import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

void main() {
  testWidgets('main shell contract renders the approved nav pill and fab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const _MainShellContractHarness(),
      ),
    );

    final pillContainer = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(ClipRRect),
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

    final visibleNavIcons = tester.widgetList<Icon>(
      find.descendant(of: find.byType(ClipRRect), matching: find.byType(Icon)),
    );
    expect(
      visibleNavIcons
          .firstWhere((icon) => icon.icon == Icons.home_rounded)
          .color,
      AppColors.neonGreen,
    );
    expect(
      visibleNavIcons
          .firstWhere((icon) => icon.icon == Icons.people_outline)
          .color,
      AppColors.gray400,
    );

    final fabContainer = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(Positioned),
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
        of: find.byType(Positioned),
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

class _MainShellContractHarness extends StatefulWidget {
  const _MainShellContractHarness();

  @override
  State<_MainShellContractHarness> createState() =>
      _MainShellContractHarnessState();
}

class _MainShellContractHarnessState extends State<_MainShellContractHarness> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBody: true,
      body: const SizedBox.expand(),
      bottomNavigationBar: _buildFloatingBottomNav(),
    );
  }

  Widget _buildFloatingBottomNav() {
    Widget buildContentRow({required bool isForeground}) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItemGhostAware(
            isForeground: isForeground,
            child: _buildNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Feed',
              index: 0,
            ),
          ),
          isForeground
              ? Transform.translate(
                  offset: const Offset(0, -24),
                  child: Transform.scale(
                    scale: 1.15,
                    child: _buildSessionFab(),
                  ),
                )
              : Opacity(
                  opacity: 0.0,
                  child: IgnorePointer(child: _buildSessionFab()),
                ),
          _buildNavItemGhostAware(
            isForeground: isForeground,
            child: _buildNavItem(
              icon: Icons.people_outline,
              activeIcon: Icons.people_rounded,
              label: 'Social',
              index: 2,
            ),
          ),
          _buildNavItemGhostAware(
            isForeground: isForeground,
            child: _buildNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              index: 3,
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.navy800.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.navy700),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 26,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: buildContentRow(isForeground: false),
              ),
            ),
          ),
          Positioned.fill(child: buildContentRow(isForeground: true)),
        ],
      ),
    );
  }

  Widget _buildNavItemGhostAware({
    required bool isForeground,
    required Widget child,
  }) {
    if (isForeground) {
      return IgnorePointer(child: Opacity(opacity: 0.0, child: child));
    }
    return child;
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.15 : 1.0,
              duration: AppDurations.fast,
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.neonGreen : AppColors.gray400,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppDurations.fast,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.neonGreen : AppColors.gray400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionFab() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.fitness_center,
        color: AppColors.navy900,
        size: 26,
      ),
    );
  }
}
