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

/// Premium Sign up screen with matching aesthetics to login.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  bool _showPasswordRequirements = false;
  bool _emailValid = false;
  bool _passwordValid = false;
  bool _confirmPasswordValid = false;

  // Track if fields have been touched/interacted with
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _confirmPasswordTouched = false;
  bool _formSubmitted = false;

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

    // Add listener for password focus
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus && !_showPasswordRequirements) {
        setState(() => _showPasswordRequirements = true);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _validateFields() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _emailValid = validateEmail(email) == null && email.isNotEmpty;
      _passwordValid =
          validatePassword(password) == null && password.isNotEmpty;
      _confirmPasswordValid =
          confirmPassword == password && confirmPassword.isNotEmpty;
    });
  }

  Future<void> _handleSignUp() async {
    setState(() => _formSubmitted = true);
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .signUpWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );

      if (mounted) {
        HapticFeedback.heavyImpact();
        // Capture parent context for use after dialog is dismissed
        final parentContext = context;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _VerifyEmailDialog(
            onResend: () async {
              await ref.read(authControllerProvider).sendEmailVerification();
              // Use ScaffoldMessenger captured from parent context
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text('Verification email sent!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            onContinue: () {
              Navigator.pop(dialogContext);
              // Use parent context for navigation (not the dialog's context)
              if (parentContext.mounted) {
                parentContext.go(AppRoutes.main);
              }
            },
          ),
        );
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
          _errorMessage = 'Sign up failed. Please try again';
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
        HapticFeedback.mediumImpact();

        // Check if profile is complete
        final profileComplete = await ref
            .read(authControllerProvider)
            .isProfileComplete(user.id);

        // Check mounted again after async call
        if (!mounted) return;

        if (profileComplete) {
          context.go(AppRoutes.main);
        } else {
          context.go(AppRoutes.profileSetup);
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

  Future<void> _handleFacebookSignUp() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authControllerProvider).signInWithFacebook();

      if (user != null && mounted) {
        HapticFeedback.mediumImpact();

        // Check if profile is complete
        final profileComplete = await ref
            .read(authControllerProvider)
            .isProfileComplete(user.id);

        // Check mounted again after async call
        if (!mounted) return;

        if (profileComplete) {
          context.go(AppRoutes.main);
        } else {
          context.go(AppRoutes.profileSetup);
        }
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          if (e.toString().contains('canceled')) {
            _errorMessage = null;
          } else {
            _errorMessage = 'Facebook Sign-Up failed. Please try again.';
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
    bool? isValid,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textTertiaryDark,
        fontSize: AppFontSize.md,
      ),
      prefixIcon: Icon(icon, color: AppColors.textSecondaryDark),
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Validation indicator
          if (isValid != null)
            FadeInAnimation(
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  isValid ? Icons.check_circle : Icons.error_outline,
                  color: isValid ? AppColors.success : AppColors.error,
                  size: 20,
                ),
              ),
            ),
          if (suffix != null) suffix,
        ],
      ),
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

  Widget _buildPasswordRequirements() {
    final strength = checkPasswordStrength(_passwordController.text);
    final allMet =
        strength.hasMinLength &&
        strength.hasUppercase &&
        strength.hasNumber &&
        strength.hasSpecialChar;

    return FadeInAnimation(
      duration: const Duration(milliseconds: 300),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: allMet
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.surfaceSecondaryDark.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: allMet
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.borderDark.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allMet ? Icons.check_circle : Icons.info_outline,
                  size: 16,
                  color: allMet
                      ? AppColors.success
                      : AppColors.textSecondaryDark,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Password Requirements',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w600,
                    color: allMet
                        ? AppColors.success
                        : AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildRequirementRow(
              'At least 8 characters',
              strength.hasMinLength,
              0,
            ),
            const SizedBox(height: 4),
            _buildRequirementRow(
              'One uppercase letter (A-Z)',
              strength.hasUppercase,
              1,
            ),
            const SizedBox(height: 4),
            _buildRequirementRow('One number (0-9)', strength.hasNumber, 2),
            const SizedBox(height: 4),
            _buildRequirementRow(
              'One special character (!@#\$%^&*)',
              strength.hasSpecialChar,
              3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet, int index) {
    return SlideInAnimation.fromLeft(
      index: index,
      duration: const Duration(milliseconds: 200),
      delay: const Duration(milliseconds: 30),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isMet ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: isMet ? AppColors.success : AppColors.textTertiaryDark,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: TextStyle(
              fontSize: AppFontSize.xs,
              color: isMet ? AppColors.success : AppColors.textTertiaryDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: ResponsiveCenter(
        maxContentWidth: true,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Stack(
          children: [
            // Gradient orbs
            Positioned(
              top: -100,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.premium.withValues(alpha: 0.25),
                      AppColors.premium.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 50,
              right: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.lg),

                        // Back button with bounce effect
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

                        const SizedBox(height: AppSpacing.lg),

                        // Header with pulsing logo
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
                                        colors: AppColors.achievementGradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.premium.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.fitness_center,
                                        size: 32,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                const GradientText(
                                  text: 'Create Account',
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
                                  'Join Zyntro and start your fitness journey',
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

                        const SizedBox(height: AppSpacing.xxl),

                        // Error message with pulse animation
                        if (_errorMessage != null) ...[
                          SlideInAnimation.fromBottom(
                            index: 0,
                            child: AuthErrorSurface(
                              message: _errorMessage!,
                              suggestion:
                                  'Review input fields and retry account creation.',
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
                            focusNode: _emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: AppColors.textDark),
                            decoration: _buildInputDecoration(
                              hint: 'Email',
                              icon: Icons.email_outlined,
                              isValid: _emailController.text.isNotEmpty
                                  ? _emailValid
                                  : null,
                            ),
                            validator: (value) {
                              if (!_emailTouched && !_formSubmitted) {
                                return null;
                              }
                              return validateEmail(value);
                            },
                            onChanged: (_) {
                              if (!_emailTouched) {
                                setState(() => _emailTouched = true);
                              }
                              _validateFields();
                            },
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // Password field with slide animation
                        SlideInAnimation.fromBottom(
                          index: 3,
                          child: TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: AppColors.textDark),
                            decoration: _buildInputDecoration(
                              hint: 'Password',
                              icon: Icons.lock_outlined,
                              isValid: _passwordController.text.isNotEmpty
                                  ? _passwordValid
                                  : null,
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
                              if (!_passwordTouched && !_formSubmitted) {
                                return null;
                              }
                              return validatePassword(value);
                            },
                            onChanged: (_) {
                              if (!_passwordTouched) {
                                setState(() => _passwordTouched = true);
                              }
                              _validateFields();
                              setState(() {});
                            },
                          ),
                        ),

                        // Password requirements with fade animation
                        if (_showPasswordRequirements &&
                            _passwordController.text.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildPasswordRequirements(),
                        ],

                        const SizedBox(height: AppSpacing.lg),

                        // Confirm password with slide animation
                        SlideInAnimation.fromBottom(
                          index: 4,
                          child: TextFormField(
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocusNode,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(color: AppColors.textDark),
                            decoration: _buildInputDecoration(
                              hint: 'Confirm Password',
                              icon: Icons.lock_outlined,
                              isValid:
                                  _confirmPasswordController.text.isNotEmpty
                                  ? _confirmPasswordValid
                                  : null,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textSecondaryDark,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  );
                                },
                              ),
                            ),
                            validator: (value) {
                              if (!_confirmPasswordTouched && !_formSubmitted) {
                                return null;
                              }
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            onChanged: (_) {
                              if (!_confirmPasswordTouched) {
                                setState(() => _confirmPasswordTouched = true);
                              }
                              _validateFields();
                            },
                            onFieldSubmitted: (_) => _handleSignUp(),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // Sign up button with bounce animation
                        SlideInAnimation.fromBottom(
                          index: 5,
                          child: BounceAnimation(
                            onTap: _isLoading ? null : _handleSignUp,
                            child: ZyntroButton(
                              title: _isLoading
                                  ? 'Creating Account...'
                                  : 'Create Account',
                              fullWidth: true,
                              loading: _isLoading,
                              size: ZyntroButtonSize.lg,
                              variant: ZyntroButtonVariant.premium,
                              rightIcon: _isLoading
                                  ? null
                                  : const Icon(Icons.arrow_forward_rounded),
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      FocusScope.of(context).unfocus();
                                      _handleSignUp();
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
                                  'or sign up with',
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
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.g_mobiledata,
                                        size: 24,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    const Text(
                                      'Sign up with Google',
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

                        // Facebook Sign Up with ScaleOnTap
                        SlideInAnimation.fromBottom(
                          index: 8,
                          child: ScaleOnTap(
                            onTap: _isLoading ? null : _handleFacebookSignUp,
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
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.facebook,
                                        size: 24,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    const Text(
                                      'Sign up with Facebook',
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

                        const SizedBox(height: AppSpacing.xxl),

                        // Login link with scale effect
                        SlideInAnimation.fromBottom(
                          index: 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  fontSize: AppFontSize.md,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                              ScaleOnTap(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context.go(AppRoutes.login);
                                },
                                child: const Text(
                                  'Sign In',
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

/// Premium email verification dialog for signup.
class _VerifyEmailDialog extends StatelessWidget {
  final VoidCallback onResend;
  final VoidCallback onContinue;

  const _VerifyEmailDialog({required this.onResend, required this.onContinue});

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
              // Success icon with pulse
              PulseAnimation(
                minScale: 1.0,
                maxScale: 1.1,
                duration: const Duration(milliseconds: 1500),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    color: AppColors.success,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

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

              SlideInAnimation.fromBottom(
                index: 1,
                child: Text(
                  'We\'ve sent a verification email to your inbox. Please verify your email to access all features.',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              SlideInAnimation.fromBottom(
                index: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: BounceAnimation(
                        onTap: onResend,
                        child: ZyntroButton(
                          title: 'Resend',
                          variant: ZyntroButtonVariant.outline,
                          onPressed: onResend,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: BounceAnimation(
                        onTap: onContinue,
                        child: ZyntroButton(
                          title: 'Continue',
                          variant: ZyntroButtonVariant.primary,
                          onPressed: onContinue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ), // ResponsiveCenter
      ), // Scaffold
    );
  }
}
