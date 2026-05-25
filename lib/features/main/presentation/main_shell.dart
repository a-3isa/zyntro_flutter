import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/navigation/app_route_locations.dart';
import '../../../core/theme/app_theme.dart';

import '../../feed/presentation/feed_page.dart';
import '../../session/presentation/start_session_page.dart';
import '../../social/presentation/social_page.dart';
import '../../profile/presentation/profile_page.dart';

/// Provider to share scroll hide state across the app.
final navBarVisibleProvider = StateProvider<bool>((ref) => true);

/// Premium Main shell with floating bottom navigation that hides on scroll.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({
    super.key,
    this.initialTab = MainShellTab.feed,
    this.initialSocialTab = SocialTab.board,
  });

  final MainShellTab initialTab;
  final SocialTab initialSocialTab;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.index;
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _currentIndex = widget.initialTab.index;
    }
  }

  /// Handle scroll notifications to hide/show the navigation bar.
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      final direction = notification.direction;
      if (direction == ScrollDirection.forward) {
        // Scrolling up - show nav bar
        ref.read(navBarVisibleProvider.notifier).state = true;
      } else if (direction == ScrollDirection.reverse) {
        // Scrolling down - hide nav bar
        ref.read(navBarVisibleProvider.notifier).state = false;
      }
    }
    return false; // Allow the notification to continue bubbling
  }

  @override
  Widget build(BuildContext context) {
    final isNavBarVisible = ref.watch(navBarVisibleProvider);
    final pages = [
      FeedPage(onSessionTap: () => setState(() => _currentIndex = 1)),
      const StartSessionPage(),
      SocialPage(initialTab: widget.initialSocialTab),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(index: _currentIndex, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: isNavBarVisible ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isNavBarVisible ? 1.0 : 0.0,
          child: _buildFloatingBottomNav(),
        ),
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    final isSessionActive = _currentIndex == 1;
    return SizedBox(
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Nav pill
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceV2,
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x60000000),
                    blurRadius: 32,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, index: 0, label: 'Feed'),
                  const SizedBox(width: 32), // left side of FAB gap
                  const SizedBox(width: 60), // FAB itself
                  const SizedBox(width: 32), // right side of FAB gap
                  _buildNavItem(icon: Icons.people_outline, activeIcon: Icons.people_rounded, index: 2, label: 'Community'),
                  _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, index: 3, label: 'Profile'),
                ],
              ),
            ),
          ),
          // Floating session FAB
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _currentIndex = 1),
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSessionActive ? AppColors.accentLime : AppColors.surfaceV2Elevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSessionActive
                          ? AppColors.accentLime
                          : AppColors.surfaceV2Active,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSessionActive
                            ? AppColors.accentLime.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: isSessionActive ? AppColors.backgroundV2 : AppColors.textV2Secondary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required int index,
    required String label,
  }) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.1 : 1.0,
              duration: AppDurations.fast,
              curve: AppCurves.press,
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.accentLime : AppColors.textV2Tertiary,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: AppDurations.fast,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentLime,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
