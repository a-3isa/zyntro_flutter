import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../utils/validators.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/responsive_center.dart';
import 'providers/auth_controller.dart';
import 'widgets/auth_error_surface.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
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

  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _confirmPasswordTouched = false;
  bool _formSubmitted = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _validateFields() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _emailValid = validateEmail(email) == null && email.isNotEmpty;
      _passwordValid = validatePassword(password) == null && password.isNotEmpty;
      _confirmPasswordValid = confirmPassword == password && confirmPassword.isNotEmpty;
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
      await ref.read(authControllerProvider).signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        final parentContext = context;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _VerifyEmailDialog(
            onResend: () async {
              await ref.read(authControllerProvider).sendEmailVerification();
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text('Verification email sent!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            onContinue: () {
              Navigator.pop(dialogContext);
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
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _errorMessage = 'Sign up failed. Please try again');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        final profileComplete = await ref.read(authControllerProvider).isProfileComplete(user.id);
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
      if (mounted) setState(() => _isLoading = false);
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
        final profileComplete = await ref.read(authControllerProvider).isProfileComplete(user.id);
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
      if (mounted) setState(() => _isLoading = false);
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
      hintStyle: TextStyle(color: AppColors.textV2Tertiary, fontSize: AppFontSize.md),
      prefixIcon: Icon(icon, color: AppColors.textV2Secondary),
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isValid != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                isValid ? Icons.check_circle : Icons.error_outline,
                color: isValid ? AppColors.success : AppColors.error,
                size: 20,
              ),
            ),
          if (suffix != null) suffix,
        ],
      ),
      filled: true,
      fillColor: AppColors.surfaceV2Elevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: BorderSide(color: AppColors.surfaceV2Active),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: const BorderSide(color: AppColors.accentLime, width: 2),
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
    final allMet = strength.hasMinLength &&
        strength.hasUppercase &&
        strength.hasNumber &&
        strength.hasSpecialChar;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: allMet ? AppColors.success.withValues(alpha: 0.1) : AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: allMet ? AppColors.success.withValues(alpha: 0.3) : AppColors.surfaceV2Active,
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
                color: allMet ? AppColors.success : AppColors.textV2Secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Password Requirements',
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: FontWeight.w600,
                  color: allMet ? AppColors.success : AppColors.textV2Secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildRequirementRow('At least 8 characters', strength.hasMinLength, 0),
          const SizedBox(height: 4),
          _buildRequirementRow('One uppercase letter (A-Z)', strength.hasUppercase, 1),
          const SizedBox(height: 4),
          _buildRequirementRow('One number (0-9)', strength.hasNumber, 2),
          const SizedBox(height: 4),
          _buildRequirementRow('One special character (!@#\$%^&*)', strength.hasSpecialChar, 3),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet, int index) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isMet ? AppColors.success : AppColors.textV2Tertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          text,
          style: TextStyle(
            fontSize: AppFontSize.xs,
            color: isMet ? AppColors.success : AppColors.textV2Tertiary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: ResponsiveCenter(
        maxContentWidth: true,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),

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
                          color: AppColors.surfaceV2Elevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceV2Elevated,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.fitness_center,
                              size: 32,
                              color: AppColors.accentLime,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Create Account',
                          style: GoogleFonts.syne(
                            fontSize: AppFontSize.xxxl,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textV2Primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Join Zyntro and start your fitness journey',
                          style: GoogleFonts.outfit(
                            fontSize: AppFontSize.md,
                            color: AppColors.textV2Secondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  if (_errorMessage != null) ...[
                    AuthErrorSurface(
                      message: _errorMessage!,
                      suggestion: 'Review input fields and retry account creation.',
                      onDismiss: () => setState(() => _errorMessage = null),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: AppColors.textV2Primary),
                    decoration: _buildInputDecoration(
                      hint: 'Email',
                      icon: Icons.email_outlined,
                      isValid: _emailController.text.isNotEmpty ? _emailValid : null,
                    ),
                    validator: (value) {
                      if (!_emailTouched && !_formSubmitted) return null;
                      return validateEmail(value);
                    },
                    onChanged: (_) {
                      if (!_emailTouched) setState(() => _emailTouched = true);
                      _validateFields();
                    },
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: AppColors.textV2Primary),
                    decoration: _buildInputDecoration(
                      hint: 'Password',
                      icon: Icons.lock_outlined,
                      isValid: _passwordController.text.isNotEmpty ? _passwordValid : null,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textV2Secondary,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (!_passwordTouched && !_formSubmitted) return null;
                      return validatePassword(value);
                    },
                    onChanged: (_) {
                      if (!_passwordTouched) setState(() => _passwordTouched = true);
                      _validateFields();
                      setState(() {});
                    },
                  ),

                  if (_showPasswordRequirements && _passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildPasswordRequirements(),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Confirm password
                  TextFormField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocusNode,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: AppColors.textV2Primary),
                    decoration: _buildInputDecoration(
                      hint: 'Confirm Password',
                      icon: Icons.lock_outlined,
                      isValid: _confirmPasswordController.text.isNotEmpty
                          ? _confirmPasswordValid
                          : null,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textV2Secondary,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (!_confirmPasswordTouched && !_formSubmitted) return null;
                      if (value == null || value.isEmpty) return 'Please confirm your password';
                      if (value != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                    onChanged: (_) {
                      if (!_confirmPasswordTouched) setState(() => _confirmPasswordTouched = true);
                      _validateFields();
                    },
                    onFieldSubmitted: (_) => _handleSignUp(),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Sign up button
                  ZyntroButton(
                    title: _isLoading ? 'Creating Account...' : 'Create Account',
                    fullWidth: true,
                    loading: _isLoading,
                    size: ZyntroButtonSize.lg,
                    rightIcon: _isLoading ? null : const Icon(Icons.arrow_forward_rounded),
                    onPressed: _isLoading
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            _handleSignUp();
                          },
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Container(height: 1, color: AppColors.surfaceV2Active)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Text(
                          'or sign up with',
                          style: GoogleFonts.outfit(
                            fontSize: AppFontSize.sm,
                            color: AppColors.textV2Tertiary,
                          ),
                        ),
                      ),
                      Expanded(child: Container(height: 1, color: AppColors.surfaceV2Active)),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Google Sign In
                  GestureDetector(
                    onTap: _isLoading ? null : _handleGoogleSignIn,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2Elevated,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        border: Border.all(color: AppColors.surfaceV2Active),
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
                            child: const Icon(Icons.g_mobiledata, size: 24, color: Colors.black87),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'Sign up with Google',
                            style: GoogleFonts.outfit(
                              fontSize: AppFontSize.md,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textV2Primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Facebook Sign Up
                  GestureDetector(
                    onTap: _isLoading ? null : _handleFacebookSignUp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2Elevated,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        border: Border.all(color: AppColors.surfaceV2Active),
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
                            child: const Icon(Icons.facebook, size: 24, color: Colors.white),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'Sign up with Facebook',
                            style: GoogleFonts.outfit(
                              fontSize: AppFontSize.md,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textV2Primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: GoogleFonts.outfit(
                          fontSize: AppFontSize.md,
                          color: AppColors.textV2Secondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.go(AppRoutes.login);
                        },
                        child: Text(
                          'Sign In',
                          style: GoogleFonts.outfit(
                            fontSize: AppFontSize.md,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentLime,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifyEmailDialog extends StatelessWidget {
  final VoidCallback onResend;
  final VoidCallback onContinue;

  const _VerifyEmailDialog({required this.onResend, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceV2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
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
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Verify Your Email',
              style: GoogleFonts.syne(
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.w700,
                color: AppColors.textV2Primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "We've sent a verification email to your inbox. Please verify your email to access all features.",
              style: GoogleFonts.outfit(
                color: AppColors.textV2Secondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: ZyntroButton(
                    title: 'Resend',
                    variant: ZyntroButtonVariant.outline,
                    onPressed: onResend,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ZyntroButton(
                    title: 'Continue',
                    variant: ZyntroButtonVariant.primary,
                    onPressed: onContinue,
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
