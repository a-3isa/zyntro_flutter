import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../utils/validators.dart';
import '../../../widgets/zyntro_button.dart';
import 'providers/auth_controller.dart';
import 'widgets/auth_error_surface.dart';

/// Login screen — v2 design (true-black, no glassmorphism).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _errorSuggestion;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
          _errorSuggestion = 'Confirm credentials and retry, or use password reset.';
        });
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Login failed. Please try again';
          _errorSuggestion = 'Confirm credentials and retry, or use password reset.';
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
          _errorSuggestion = null;
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
          _errorSuggestion = null;
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
      hintStyle: AppTextStyles.bodyLarge.copyWith(
        color: AppColors.textV2Tertiary,
      ),
      prefixIcon: Icon(icon, color: AppColors.textV2Secondary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceV2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppColors.surfaceV2Elevated,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppColors.accentLime,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.errorV2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.errorV2, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.go(AppRoutes.splash);
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 16,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Heading
                Text(
                  'Welcome back',
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                    letterSpacing: -1.2,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 6),

                // Subtitle
                Text(
                  'Sign in to continue your fitness journey',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textV2Secondary,
                    height: 1.5,
                  ),
                ),

                const Spacer(),

                // Error message
                if (_errorMessage != null) ...[
                  AuthErrorSurface(
                    message: _errorMessage!,
                    suggestion: _errorSuggestion,
                    onDismiss: () {
                      setState(() {
                        _errorMessage = null;
                        _errorSuggestion = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textV2Primary,
                  ),
                  decoration: _buildInputDecoration(
                    hint: 'Email',
                    icon: Icons.email_outlined,
                  ),
                  validator: validateEmail,
                ),

                const SizedBox(height: 12),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textV2Primary,
                  ),
                  decoration: _buildInputDecoration(
                    hint: 'Password',
                    icon: Icons.lock_outlined,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textV2Secondary,
                        size: 20,
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

                const SizedBox(height: 8),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.forgotPassword);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Forgot password?',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textV2Secondary,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Sign In button
                ZyntroButton(
                  title: _isLoading ? 'Signing In...' : 'Sign In',
                  fullWidth: true,
                  loading: _isLoading,
                  size: ZyntroButtonSize.lg,
                  variant: ZyntroButtonVariant.primary,
                  onPressed: _isLoading
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          _handleLogin();
                        },
                ),

                const SizedBox(height: 20),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.surfaceV2Elevated,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or sign in with',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          color: AppColors.textV2Tertiary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.surfaceV2Elevated,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Google Sign In
                GestureDetector(
                  onTap: _isLoading ? null : _handleGoogleSignIn,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.surfaceV2Elevated,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.g_mobiledata,
                            size: 24,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Continue with Google',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontSize: 15,
                            color: AppColors.textV2Primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Facebook Sign In
                GestureDetector(
                  onTap: _isLoading ? null : _handleFacebookSignIn,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.surfaceV2Elevated,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1877F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.facebook,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Continue with Facebook',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontSize: 15,
                            color: AppColors.textV2Primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textV2Secondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.go(AppRoutes.signUp);
                      },
                      child: Text(
                        'Sign Up',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.accentLime,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Email verification dialog.
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
    return Dialog(
      backgroundColor: AppColors.surfaceV2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
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
            const SizedBox(height: 20),

            // Title
            Text(
              'Verify Your Email',
              style: AppTextStyles.h4.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textV2Primary,
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              "We've sent a verification email to:",
              style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              widget.email,
              style: AppTextStyles.label.copyWith(
                color: AppColors.accentLime,
              ),
            ),
            const SizedBox(height: 20),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please click the link in the email to verify your account.',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
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
                const SizedBox(width: 12),
                Expanded(
                  child: ZyntroButton(
                    title: "I've Verified",
                    variant: ZyntroButtonVariant.primary,
                    loading: _isChecking,
                    onPressed: _handleCheck,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
