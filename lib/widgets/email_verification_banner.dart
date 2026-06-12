import 'package:flutter/material.dart';

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/presentation/providers/auth_controller.dart';

/// Enhanced email verification banner with refresh button, cooldown timer,
/// and success animation when email is verified.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  final VoidCallback onResendPressed;
  final bool isSending;

  const EmailVerificationBanner({
    super.key,
    required this.onResendPressed,
    this.isSending = false,
  });

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner>
    with SingleTickerProviderStateMixin {
  bool _isVisible = true;
  bool _isRefreshing = false;
  bool _isVerified = false;
  Timer? _checkTimer;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  static const String _lastResendKey = 'email_verification_last_resend';
  static const int _cooldownDuration = 60;

  late AnimationController _successAnimationController;
  late Animation<double> _successAnimation;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
    _checkCooldown();

    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: Curves.easeOutBack,
      ),
    );
  }

  void _startVerificationCheck() {
    // Check every 3 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final user = ref.read(authSessionProvider).valueOrNull;
      if (user != null && !user.emailVerified) {
        try {
          await ref.read(authControllerProvider).reloadCurrentUser();
          final refreshedUser = await ref
              .read(authControllerProvider)
              .getCurrentUser();

          if (mounted && refreshedUser?.emailVerified == true) {
            // Show success animation before hiding
            setState(() => _isVerified = true);
            _successAnimationController.forward();

            // Refresh auth state to trigger UI updates elsewhere
            ref.invalidate(authSessionProvider);

            // Hide after animation
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _isVisible = false);
            });
          }
        } catch (_) {
          // Ignore transient refresh failures and keep polling.
        }
      } else if (user != null && user.emailVerified && _isVisible && mounted) {
        setState(() => _isVisible = false);
      }
    });
  }

  Future<void> _checkCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResend = prefs.getInt(_lastResendKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsed = now - lastResend;

    if (elapsed < _cooldownDuration) {
      setState(() {
        _cooldownSeconds = _cooldownDuration - elapsed;
      });
      _startCooldownTimer();
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _saveCooldownTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await prefs.setInt(_lastResendKey, now);
  }

  Future<void> _handleResend() async {
    if (_cooldownSeconds > 0 || widget.isSending) return;

    await _saveCooldownTimestamp();
    setState(() => _cooldownSeconds = _cooldownDuration);
    _startCooldownTimer();

    widget.onResendPressed();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await ref.read(authControllerProvider).reloadCurrentUser();
      final refreshedUser = await ref
          .read(authControllerProvider)
          .getCurrentUser();

      if (mounted && refreshedUser?.emailVerified == true) {
        setState(() => _isVerified = true);
        _successAnimationController.forward();
        ref.invalidate(authSessionProvider);

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isVisible = false);
        });
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _cooldownTimer?.cancel();
    _successAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Also hide if auth state provider says we are verified (reactive update)
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user?.emailVerified == true) return const SizedBox.shrink();

    if (!_isVisible) return const SizedBox.shrink();

    // Show verified state with animation
    if (_isVerified) {
      return AnimatedBuilder(
        animation: _successAnimation,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            color: AppColors.success.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Transform.scale(
                  scale: _successAnimation.value,
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Email verified successfully!',
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w500,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return Container(
      width: double.infinity,
      color: AppColors.warning.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Please verify your email address',
                  style: TextStyle(
                    fontSize: AppFontSize.md,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textV2Primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Check your inbox for the verification link',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textV2Secondary,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.warning,
                    ),
                  )
                : const Icon(Icons.refresh, color: AppColors.warning, size: 20),
            onPressed: _isRefreshing ? null : _handleRefresh,
            tooltip: 'Check verification status',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Resend button with cooldown
          if (widget.isSending)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _cooldownSeconds > 0 ? null : _handleResend,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _cooldownSeconds > 0
                    ? 'Resend (${_cooldownSeconds}s)'
                    : 'Resend',
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: _cooldownSeconds > 0
                      ? AppColors.textTertiaryLight
                      : AppColors.userAccent,
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => setState(() => _isVisible = false),
          ),
        ],
      ),
    );
  }
}
