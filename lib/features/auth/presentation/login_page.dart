import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../utils/validators.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/premium_effects.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/responsive_center.dart';
import 'providers/auth_controller.dart';
import 'widgets/auth_error_surface.dart';

/// Premium Login screen with glassmorphism and gradient accents.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

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
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref
          .read(authControllerProvider)
          .signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );

      if (mounted) {
        if (!user.emailVerified) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => _EmailVerificationDialog(
                email: user.email ?? '',
                onResend: () async {
                  await ref
                      .read(authControllerProvider)
                      .sendEmailVerification();
                  if (dialogContext.mounted && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Verification email sent!'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
                onCheckVerification: () async {
                  await ref.read(authControllerProvider).reloadCurrentUser();
                  final currentUser = await ref
                      .read(authControllerProvider)
                      .getCurrentUser();
                  if (currentUser?.emailVerified == true) {
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      if (mounted) context.go(AppRoutes.main);
                    }
                  } else {
                    if (dialogContext.mounted && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Email not verified yet. Please check your inbox.',
                          ),
                          backgroundColor: AppColors.warning,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            );
          }
          return;
        }
        HapticFeedback.heavyImpact();
        context.go(AppRoutes.main);
      }
    } on AuthFlowException catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Login failed. Please try again';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authControllerProvider).signInWithGoogle();

      if (user != null && mounted) {
        final profile = await ref
            .read(authControllerProvider)
            .getUserProfile(user.id);
        // Check mounted again after async call
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        if (profile != null) {
          context.go(AppRoutes.main);
        } else {
          context.go(AppRoutes.main);
        }
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          if (e.toString().contains('network_error')) {
            _errorMessage = 'Network error during Google Sign-In';
          } else if (e.toString().contains('sign_in_canceled')) {
            _errorMessage = null;
          } else {
            _errorMessage = 'Google Sign-In failed. Please try again.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFacebookSignIn() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authControllerProvider).signInWithFacebook();

      if (user != null && mounted) {
        HapticFeedback.mediumImpact();
        context.go(AppRoutes.main);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          if (e.toString().contains('canceled')) {
            _errorMessage = null;
          } else {
            _errorMessage = 'Facebook Sign-In failed. Please try again.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textTertiaryDark,
        fontSize: AppFontSize.md,
      ),
      prefixIcon: Icon(icon, color: AppColors.textSecondaryDark),
      suffixIcon: suffix,
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
      body: ResponsiveCenter(
        padding: const EdgeInsets.all(AppSpacing.lg),
        maxContentWidth: true,
        child: Stack(
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
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.xxl),

                        // Back button with bounce animation
                        SlideInAnimation.fromLeft(
                          index: 0,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: BounceAnimation(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                context.go(AppRoutes.splash);
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

                        const SizedBox(height: AppSpacing.xl),

                        // Logo Section with pulse animation
                        SlideInAnimation.fromBottom(
                          index: 1,
                          child: Center(
                            child: Column(
                              children: [
                                // Logo with pulsing glow
                                PulseAnimation(
                                  minScale: 1.0,
                                  maxScale: 1.05,
                                  duration: const Duration(milliseconds: 2000),
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: AppColors.primaryGradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Z',
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.backgroundDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                const GradientText(
                                  text: 'Welcome Back',
                                  style: TextStyle(
                                    fontSize: AppFontSize.xxxl,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  colors: [
                                    AppColors.textDark,
                                    AppColors.textSecondaryDark,
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Sign in to continue your fitness journey',
                                  style: TextStyle(
                                    fontSize: AppFontSize.md,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xxxl),

                        // Error message with pulse animation
                        if (_errorMessage != null) ...[
                          SlideInAnimation.fromBottom(
                            index: 0,
                            child: AuthErrorSurface(
                              message: _errorMessage!,
                              suggestion:
                                  'Confirm credentials and retry, or use password reset.',
                              onDismiss: () {
                                setState(() => _errorMessage = null);
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        // Email field with slide animation
                        SlideInAnimation.fromBottom(
                          index: 2,
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: AppColors.textDark),
                            decoration: _buildInputDecoration(
                              hint: 'Email',
                              icon: Icons.email_outlined,
                            ),
                            validator: validateEmail,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // Password field with slide animation
                        SlideInAnimation.fromBottom(
                          index: 3,
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(color: AppColors.textDark),
                            decoration: _buildInputDecoration(
                              hint: 'Password',
                              icon: Icons.lock_outlined,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textSecondaryDark,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) {
                              FocusScope.of(context).unfocus();
                              _handleLogin();
                            },
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Forgot password with scale effect
                        SlideInAnimation.fromBottom(
                          index: 4,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ScaleOnTap(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                context.push(AppRoutes.forgotPassword);
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: AppFontSize.sm,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // Sign In button with bounce animation
                        SlideInAnimation.fromBottom(
                          index: 5,
                          child: BounceAnimation(
                            onTap: _isLoading ? null : _handleLogin,
                            child: ZyntroButton(
                              title: _isLoading ? 'Signing In...' : 'Sign In',
                              fullWidth: true,
                              loading: _isLoading,
                              size: ZyntroButtonSize.lg,
                              rightIcon: _isLoading
                                  ? null
                                  : const Icon(Icons.arrow_forward_rounded),
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      FocusScope.of(context).unfocus();
                                      _handleLogin();
                                    },
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // Divider with fade animation
                        SlideInAnimation.fromBottom(
                          index: 6,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppColors.borderDark,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                ),
                                child: Text(
                                  'or continue with',
                                  style: TextStyle(
                                    fontSize: AppFontSize.sm,
                                    color: AppColors.textTertiaryDark,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppColors.borderDark,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // Google Sign In with ScaleOnTap
                        SlideInAnimation.fromBottom(
                          index: 7,
                          child: ScaleOnTap(
                            onTap: _isLoading ? null : _handleGoogleSignIn,
                            child: GlassContainer(
                                blur: 10,
                                backgroundColor: AppColors.surfaceSecondaryDark
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.lg,
                                ),
                                border: Border.all(
                                  color: AppColors.borderDark.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.lg,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.g_mobiledata,
                                          size: 24,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      const Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          fontSize: AppFontSize.md,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // Facebook Sign In with ScaleOnTap
                        SlideInAnimation.fromBottom(
                          index: 8,
                          child: ScaleOnTap(
                            onTap: _isLoading ? null : _handleFacebookSignIn,
                            child: GlassContainer(
                                blur: 10,
                                backgroundColor: AppColors.surfaceSecondaryDark
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.lg,
                                ),
                                border: Border.all(
                                  color: AppColors.borderDark.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.lg,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1877F2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.facebook,
                                          size: 24,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      const Text(
                                        'Continue with Facebook',
                                        style: TextStyle(
                                          fontSize: AppFontSize.md,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xxxl),

                        // Sign up link with scale effect
                        SlideInAnimation.fromBottom(
                          index: 9,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  fontSize: AppFontSize.md,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                              ScaleOnTap(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context.go(AppRoutes.signUp);
                                },
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    fontSize: AppFontSize.md,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Email verification dialog with premium styling.
class _EmailVerificationDialog extends StatefulWidget {
  final String email;
  final VoidCallback onResend;
  final VoidCallback onCheckVerification;

  const _EmailVerificationDialog({
    required this.email,
    required this.onResend,
    required this.onCheckVerification,
  });

  @override
  State<_EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<_EmailVerificationDialog> {
  bool _isResending = false;
  bool _isChecking = false;
  Timer? _timer;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        if (mounted) {
          setState(() => _cooldownSeconds--);
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleResend() async {
    if (_isResending || _cooldownSeconds > 0) return;

    HapticFeedback.lightImpact();
    setState(() => _isResending = true);
    try {
      widget.onResend();
      _startCooldown();
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleCheck() async {
    HapticFeedback.lightImpact();
    setState(() => _isChecking = true);
    try {
      widget.onCheckVerification();
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeInAnimation(
      child: Dialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with pulse animation
              PulseAnimation(
                minScale: 1.0,
                maxScale: 1.1,
                duration: const Duration(milliseconds: 1500),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppColors.warning,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Title with slide animation
              SlideInAnimation.fromBottom(
                index: 0,
                child: const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: AppFontSize.xl,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              SlideInAnimation.fromBottom(
                index: 1,
                child: Text(
                  "We've sent a verification email to:",
                  style: TextStyle(color: AppColors.textSecondaryDark),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SlideInAnimation.fromBottom(
                index: 2,
                child: Text(
                  widget.email,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Info box with fade animation
              SlideInAnimation.fromBottom(
                index: 3,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.info,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Please click the link in the email to verify your account.',
                          style: TextStyle(
                            fontSize: AppFontSize.sm,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Actions with bounce animations
              SlideInAnimation.fromBottom(
                index: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: BounceAnimation(
                        onTap: (_isResending || _cooldownSeconds > 0)
                            ? null
                            : _handleResend,
                        child: ZyntroButton(
                          title: _cooldownSeconds > 0
                              ? 'Resend in ${_cooldownSeconds}s'
                              : 'Resend Email',
                          variant: ZyntroButtonVariant.outline,
                          disabled: _isResending || _cooldownSeconds > 0,
                          loading: _isResending,
                          onPressed: _handleResend,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: BounceAnimation(
                        onTap: _handleCheck,
                        child: ZyntroButton(
                          title: "I've Verified",
                          variant: ZyntroButtonVariant.primary,
                          loading: _isChecking,
                          onPressed: _handleCheck,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
