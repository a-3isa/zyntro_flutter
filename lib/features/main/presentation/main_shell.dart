import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/navigation/app_router.dart';
import '../../../core/theme/app_theme.dart';

import '../../feed/presentation/feed_page.dart';
import '../../session/presentation/session_page.dart';
import '../../social/presentation/social_page.dart';
import '../../profile/presentation/profile_page.dart';

/// Provider to share scroll hide state across the app.
final navBarVisibleProvider = StateProvider<bool>((ref) => true);

/// Premium Main shell with floating bottom navigation that hides on scroll.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  final List<Widget> _pages = const [
    FeedPage(),
    SessionPage(),
    SocialPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScale = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _fabController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _pages),
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
    // Helper to build the content row with visibility logic
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
          // Session FAB Logic
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
          // Background Layer (The Blurred Pill)
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
          // Foreground Layer (Floating Elements)
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
    return GestureDetector(
      onTapDown: (_) => _fabController.forward(),
      onTapUp: (_) {
        _fabController.reverse();
        context.push(AppRoutes.startSession);
      },
      onTapCancel: () => _fabController.reverse(),
      child: AnimatedBuilder(
        animation: _fabScale,
        builder: (context, child) {
          return Transform.scale(scale: _fabScale.value, child: child);
        },
        child: Container(
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
        ),
      ),
    );
  }
}
