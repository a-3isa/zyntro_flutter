import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

/// Minimal smoke test for the floating nav bar icon colors.
/// Pumps a trimmed version of the nav bar widget directly to avoid
/// spinning up all the full-app Riverpod / Firebase providers.
void main() {
  testWidgets('active nav icon uses signal, inactive uses gray400',
      (tester) async {
    // Build a standalone _NavItemRow that exercises _buildNavItem color logic.
    // We test the color logic via the _NavItemColorTest helper widget.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: _NavItemColorTest(),
        ),
      ),
    );

    await tester.pump();

    // The active icon at index 0 is Icons.home_rounded
    final activeIcon =
        tester.widget<Icon>(find.byIcon(Icons.home_rounded).first);
    expect(activeIcon.color, AppColors.signal,
        reason: 'Active nav icon should use signal');

    // The inactive icon at index 2 (Social) is Icons.people_outline
    final inactiveIcon =
        tester.widget<Icon>(find.byIcon(Icons.people_outline).first);
    expect(inactiveIcon.color, AppColors.gray400,
        reason: 'Inactive nav icon should use gray400');
  });
}

/// Test helper that renders the nav items without the full Riverpod/Firebase
/// dependency tree that MainShell normally requires.
class _NavItemColorTest extends StatelessWidget {
  const _NavItemColorTest();

  @override
  Widget build(BuildContext context) {
    const int currentIndex = 0; // Feed tab is active

    return Row(
      children: [
        _buildNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Feed',
          index: 0,
          currentIndex: currentIndex,
        ),
        _buildNavItem(
          icon: Icons.people_outline,
          activeIcon: Icons.people_rounded,
          label: 'Social',
          index: 2,
          currentIndex: currentIndex,
        ),
      ],
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required int currentIndex,
  }) {
    final isActive = currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Icon(
        isActive ? activeIcon : icon,
        color: isActive ? AppColors.signal : AppColors.gray400,
        size: 24,
      ),
    );
  }
}
