import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/premium_effects.dart';
import '../../../widgets/premium_animations.dart';
import 'providers/auth_controller.dart';
import 'widgets/auth_error_surface.dart';

/// Premium password reset/forgot password page with glassmorphism styling.
/// Allows users to request a password reset email with resend cooldown.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  static const String _lastResendKey = 'password_reset_last_resend';
  static const int _cooldownDuration = 60;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    _checkCooldown();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _cooldownTimer?.cancel();
    _animController.dispose();
    super.dispose();
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

  Future<void> _handleSendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cooldownSeconds > 0) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .sendPasswordResetEmail(_emailController.text.trim());

      await _saveCooldownTimestamp();

      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _emailSent = true;
          _cooldownSeconds = _cooldownDuration;
        });
        _startCooldownTimer();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return 'No account found with this email address.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your connection and try again.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    return 'Failed to send reset email. Please try again.';
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textTertiaryDark,
        fontSize: AppFontSize.md,
      ),
      prefixIcon: Icon(icon, color: AppColors.textSecondaryDark),
      filled: true,
      fillColor: AppColors.surfaceSecondaryDark.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: BorderSide(
          color: AppColors.borderDark.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Gradient orbs background
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.2),
                    AppColors.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    // Back button with bounce animation
                    SlideInAnimation.fromLeft(
                      index: 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: BounceAnimation(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondaryDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.borderDark.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Content based on state
                    _emailSent ? _buildSuccessState() : _buildFormState(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon with pulse animation
          SlideInAnimation.fromBottom(
            index: 0,
            child: Center(
              child: PulseAnimation(
                minScale: 1.0,
                maxScale: 1.05,
                duration: const Duration(milliseconds: 2000),
                child: GlowContainer(
                  glowColor: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 25,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Title with gradient text
          SlideInAnimation.fromBottom(
            index: 1,
            child: const Center(
              child: GradientText(
                text: 'Forgot Password?',
                style: TextStyle(
                  fontSize: AppFontSize.xxxl,
                  fontWeight: FontWeight.bold,
                ),
                colors: [AppColors.textDark, AppColors.textSecondaryDark],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Description
          SlideInAnimation.fromBottom(
            index: 2,
            child: Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: AppColors.textSecondaryDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Error message with pulse animation
          if (_errorMessage != null) ...[
            SlideInAnimation.fromBottom(
              index: 0,
              child: AuthErrorSurface(
                message: _errorMessage!,
                suggestion: 'Verify email format and try sending reset again.',
                onDismiss: () {
                  setState(() => _errorMessage = null);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Email field with slide animation
          SlideInAnimation.fromBottom(
            index: 3,
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: AppColors.textDark),
              decoration: _buildInputDecoration(
                hint: 'Email Address',
                icon: Icons.email_outlined,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email address';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleSendResetEmail(),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Submit button with bounce animation
          SlideInAnimation.fromBottom(
            index: 4,
            child: BounceAnimation(
              onTap: (_isLoading || _cooldownSeconds > 0)
                  ? null
                  : _handleSendResetEmail,
              child: ZyntroButton(
                title: _isLoading
                    ? 'Sending...'
                    : _cooldownSeconds > 0
                    ? 'Resend in ${_cooldownSeconds}s'
                    : 'Send Reset Email',
                fullWidth: true,
                loading: _isLoading,
                size: ZyntroButtonSize.lg,
                rightIcon: _isLoading || _cooldownSeconds > 0
                    ? null
                    : const Icon(Icons.send_rounded),
                onPressed: (_isLoading || _cooldownSeconds > 0)
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        _handleSendResetEmail();
                      },
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Back to login link with scale effect
          SlideInAnimation.fromBottom(
            index: 5,
            child: Center(
              child: ScaleOnTap(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go(AppRoutes.login);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Back to Sign In',
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
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

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success icon with pulsing glow
        SlideInAnimation.fromBottom(
          index: 0,
          child: Center(
            child: PulseAnimation(
              minScale: 1.0,
              maxScale: 1.1,
              duration: const Duration(milliseconds: 1500),
              child: GlowContainer(
                glowColor: AppColors.success.withValues(alpha: 0.5),
                blurRadius: 30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success,
                        AppColors.success.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Success title
        SlideInAnimation.fromBottom(
          index: 1,
          child: const Center(
            child: GradientText(
              text: 'Check Your Email',
              style: TextStyle(
                fontSize: AppFontSize.xxxl,
                fontWeight: FontWeight.bold,
              ),
              colors: [AppColors.textDark, AppColors.textSecondaryDark],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Success message container
        SlideInAnimation.fromBottom(
          index: 2,
          child: GlassContainer(
            blur: 10,
            backgroundColor: AppColors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  'We\'ve sent a password reset link to:',
                  style: TextStyle(
                    fontSize: AppFontSize.md,
                    color: AppColors.textSecondaryDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                GradientText(
                  text: _emailController.text.trim(),
                  style: const TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                  colors: [AppColors.success, AppColors.primary],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Instructions
        SlideInAnimation.fromBottom(
          index: 3,
          child: Text(
            'Click the link in the email to reset your password. If you don\'t see it, check your spam folder.',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondaryDark,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // Resend button
        SlideInAnimation.fromBottom(
          index: 4,
          child: BounceAnimation(
            onTap: (_isLoading || _cooldownSeconds > 0)
                ? null
                : _handleSendResetEmail,
            child: ZyntroButton(
              title: _cooldownSeconds > 0
                  ? 'Resend in ${_cooldownSeconds}s'
                  : 'Resend Email',
              fullWidth: true,
              variant: ZyntroButtonVariant.secondary,
              loading: _isLoading,
              size: ZyntroButtonSize.lg,
              leftIcon: _cooldownSeconds > 0
                  ? null
                  : const Icon(Icons.refresh_rounded),
              onPressed: (_isLoading || _cooldownSeconds > 0)
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      _handleSendResetEmail();
                    },
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Back to login button
        SlideInAnimation.fromBottom(
          index: 5,
          child: BounceAnimation(
            onTap: () {
              HapticFeedback.lightImpact();
              context.go(AppRoutes.login);
            },
            child: ZyntroButton(
              title: 'Back to Sign In',
              fullWidth: true,
              size: ZyntroButtonSize.lg,
              rightIcon: const Icon(Icons.arrow_forward_rounded),
              onPressed: () {
                HapticFeedback.lightImpact();
                context.go(AppRoutes.login);
              },
            ),
          ),
        ),
      ],
    );
  }
}
