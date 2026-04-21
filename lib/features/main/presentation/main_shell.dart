import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    this.initialSocialTab = SocialTab.buddies,
  });

  final MainShellTab initialTab;
  final SocialTab initialSocialTab;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _fabController;
  late Animation<double> _fabScale;
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.index;
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScale = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _fabController, curve: Curves.easeInOut));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _currentIndex = widget.initialTab.index;
    }
  }

  @override
  void dispose() {
    _fabController.dispose();
    _pulseController.dispose();
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
    final pages = [
      const FeedPage(),
      const StartSessionPage(),
      SocialPage(initialTab: widget.initialSocialTab),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
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
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
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
    final isActive = _currentIndex == 1;

    return GestureDetector(
      onTapDown: (_) => _fabController.forward(),
      onTapUp: (_) {
        _fabController.reverse();
        setState(() => _currentIndex = MainShellTab.session.index);
      },
      onTapCancel: () => _fabController.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_fabScale, _pulseScale]),
        builder: (context, child) {
          final scale =
              _fabController.isAnimating || _fabController.isCompleted
              ? _fabScale.value
              : _pulseScale.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive
                  ? AppColors.secondaryGradient
                  : AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.fitness_center,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
