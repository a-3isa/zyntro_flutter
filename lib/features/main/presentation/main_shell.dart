import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/navigation/app_route_locations.dart';
import '../../../core/theme/app_theme.dart';

import '../../feed/presentation/feed_page.dart';
import '../../session/presentation/start_session_page.dart'
    show
        StartSessionPage,
        sessionViewResetProvider,
        sessionFabActiveProvider,
        sessionFabLoadingProvider,
        sessionStartTriggerProvider;
import '../../session/presentation/session_invite_listener.dart';
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

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late int _currentIndex;
  DateTime? _lastBackPress;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.index;
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Safety net for go_router 14.x: GoRouterDelegate.popRoute() can return
  // false at the root route without calling navigator.maybePop(), bypassing
  // PopScope(canPop: false). WidgetsBindingObserver.didPopRoute() is invoked
  // after the RouterDelegate declines, so we intercept here.
  @override
  Future<bool> didPopRoute() async {
    if (GoRouter.of(context).canPop()) {
      // There is a real route to pop — let the router handle it.
      return false;
    }
    _onRootBackPress();
    return true;
  }

  void _onRootBackPress() {
    // If not on feed, navigate to feed first instead of showing exit prompt.
    if (_currentIndex != MainShellTab.feed.index) {
      setState(() => _currentIndex = MainShellTab.feed.index);
      context.go(AppRouteLocations.mainTab(MainShellTab.feed));
      return;
    }
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
    } else {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync the tab when the main shell is the topmost page (nothing pushed
    // on top). When a route like session room is pushed, GoRouter rebuilds the
    // shell with initialTab=feed (the URL has no tab param), which would cause
    // a visible flash of the feed tab during the push-in animation.
    // When GoRouter.canPop() is false, we're back at the root level and a
    // tab-targeted navigation (e.g. context.go('/?tab=feed')) should take effect.
    if (!GoRouter.of(context).canPop()) {
      _currentIndex = widget.initialTab.index;
    }
  }

  /// Handle scroll notifications to hide/show the navigation bar.
  bool _handleScrollNotification(ScrollNotification notification) {
    // Never auto-hide the nav bar on the Train tab.
    if (_currentIndex == 1) return false;
    if (notification is UserScrollNotification) {
      final direction = notification.direction;
      if (direction == ScrollDirection.forward) {
        ref.read(navBarVisibleProvider.notifier).state = true;
      } else if (direction == ScrollDirection.reverse) {
        ref.read(navBarVisibleProvider.notifier).state = false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isNavBarVisible = ref.watch(navBarVisibleProvider);
    final pages = [
      FeedPage(onSocialTap: () => setState(() => _currentIndex = 1)),
      const StartSessionPage(),
      SocialPage(initialTab: widget.initialSocialTab),
      const ProfilePage(),
    ];

    return SessionInviteListener(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _onRootBackPress();
        },
        child: Scaffold(
          backgroundColor: AppColors.backgroundV2,
          // Nav lives inside the body Stack so the FAB can overflow above the pill.
          body: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Pages fill the full screen (each manages its own bottom padding)
                Positioned.fill(
                  child: IndexedStack(index: _currentIndex, children: pages),
                ),
                // Floating nav overlaid at the bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    offset:
                        isNavBarVisible ? Offset.zero : const Offset(0, 1),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isNavBarVisible ? 1.0 : 0.0,
                      child: _buildFloatingBottomNav(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    final isSessionActive = _currentIndex == 1;
    final fabReady = ref.watch(sessionFabActiveProvider);
    final fabLoading = ref.watch(sessionFabLoadingProvider);
    // Show the START label whenever on the Train tab; active only when a type is picked.
    final showStart = isSessionActive;
    final canStart = isSessionActive && fabReady;

    // Layout: 20 px protrusion + 72 px pill + 24 px bottom margin = 116 px total.
    // The FAB sits at top=0; the pill starts at top=20.
    return SizedBox(
      height: 116,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Solid fill from pill top downward — kills the black area.
          Positioned(
            top: 20,
            bottom: 0,
            left: 0,
            right: 0,
            child: ColoredBox(color: AppColors.backgroundV2),
          ),
          // Nav pill
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            height: 72,
            child: Container(
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
                  _buildNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    index: 0,
                    label: 'Feed',
                  ),
                  _buildNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person_rounded,
                    index: 3,
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
          // FAB — top edge sits 20 px above the pill, protruding into body content.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (canStart && !fabLoading) {
                    ref.read(sessionStartTriggerProvider.notifier).state++;
                  } else if (!isSessionActive) {
                    ref.read(sessionViewResetProvider.notifier).state++;
                    setState(() => _currentIndex = 1);
                  }
                  // Do nothing when on Train tab with no type selected.
                },
                child: AnimatedBuilder(
                  animation: _pulseScale,
                  builder: (context, child) {
                    // Pulse only when type is selected and ready to start.
                    if (canStart) {
                      if (!_pulseController.isAnimating) {
                        _pulseController.repeat(reverse: true);
                      }
                    } else {
                      if (_pulseController.isAnimating) {
                        _pulseController.stop();
                        _pulseController.reset();
                      }
                    }
                    return Transform.scale(
                      scale: canStart ? _pulseScale.value : 1.0,
                      child: child,
                    );
                  },
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    // Larger when a type is selected and ready to start.
                    width: canStart ? 72 : 64,
                    height: canStart ? 72 : 64,
                    decoration: BoxDecoration(
                      // Active: full accent. Inactive START: dim accent. Dumbbell: surface.
                      color: canStart
                          ? AppColors.userAccent
                          : AppColors.surfaceV2Elevated,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: canStart
                            ? AppColors.userAccent
                            : Colors.white.withValues(alpha: 0.12),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: canStart
                              ? AppColors.userAccent.withValues(alpha: 0.55)
                              : Colors.black.withValues(alpha: 0.4),
                          blurRadius: canStart ? 24 : 14,
                          spreadRadius: canStart ? 2 : 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: fabLoading && isSessionActive
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : showStart
                            ? Center(
                                child: Text(
                                  'START',
                                  style: TextStyle(
                                    color: canStart
                                        ? Colors.white
                                        : AppColors.textV2Secondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.fitness_center_rounded,
                                color: AppColors.userAccent,
                                size: 26,
                              ),
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
        // Sync the URL so that routes pushed from this tab (settings, post detail, etc.)
        // correctly pop back to this tab rather than defaulting to feed.
        context.go(AppRouteLocations.mainTab(MainShellTab.values[index]));
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
                color: isActive
                    ? AppColors.userAccent
                    : AppColors.textV2Tertiary,
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.userAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
