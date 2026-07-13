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
import 'widgets/auth_text_field.dart';

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
  String? _socialLoading; // 'google' | 'facebook' | null
  String? _errorMessage;
  String? _errorSuggestion;
  bool _showPasswordRequirements = false;

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

  bool _emailLoading = false;

  bool get _isLoading => _socialLoading != null || _emailLoading;

  Future<void> _handleEmailSignUp() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    HapticFeedback.lightImpact();
    setState(() {
      _emailLoading = true;
      _errorMessage = null;
      _errorSuggestion = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .signUpWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );

      if (mounted) {
        HapticFeedback.mediumImpact();
        // New accounts have no profile yet — the router sends them to
        // onboarding rather than straight into the app.
        context.go(AppRoutes.main);
      }
    } on AuthFlowException catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = e.message;
          _errorSuggestion = e.code == 'email-already-in-use'
              ? 'Sign in instead, or reset your password.'
              : null;
        });
      }
    } catch (_) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Sign-up failed. Please try again.';
          _errorSuggestion = null;
        });
      }
    } finally {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _socialLoading = 'google';
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authControllerProvider).signInWithGoogle();

      if (user != null && mounted) {
        HapticFeedback.mediumImpact();
        // Router decides main vs onboarding based on profile completeness.
        context.go(AppRoutes.main);
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
      if (mounted) setState(() => _socialLoading = null);
    }
  }

  Future<void> _handleFacebookSignUp() async {
    if (_isLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _socialLoading = 'facebook';
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authControllerProvider).signInWithFacebook();

      if (user != null && mounted) {
        HapticFeedback.mediumImpact();
        // Router decides main vs onboarding based on profile completeness.
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
            _errorMessage = 'Facebook Sign-Up failed. Please try again.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _socialLoading = null);
    }
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),

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

                  const SizedBox(height: 12),

                  // Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceV2Elevated,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.fitness_center,
                              size: 26,
                              color: AppColors.userAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Create Account',
                          style: AppTextStyles.h2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textV2Primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Join Zyntro and start your fitness journey',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textV2Secondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    AuthErrorSurface(
                      message: _errorMessage!,
                      suggestion: _errorSuggestion,
                      onDismiss: () => setState(() {
                        _errorMessage = null;
                        _errorSuggestion = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Email
                  AuthTextField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    hint: 'Email Address',
                    icon: Icons.email_outlined,
                    enabled: !_isLoading,
                    validator: validateEmail,
                    autofillHints: const [AutofillHints.email],
                    onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  ),

                  const SizedBox(height: 12),

                  // Password
                  AuthTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    hint: 'Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    enabled: !_isLoading,
                    validator: validatePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) =>
                        _confirmPasswordFocusNode.requestFocus(),
                  ),

                  if (_showPasswordRequirements) ...[
                    const SizedBox(height: 10),
                    PasswordRequirements(password: _passwordController.text),
                  ],

                  const SizedBox(height: 12),

                  // Confirm password
                  AuthTextField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocusNode,
                    hint: 'Confirm Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _handleEmailSignUp(),
                  ),

                  const SizedBox(height: 20),

                  ZyntroButton(
                    title: 'Create Account',
                    fullWidth: true,
                    loading: _emailLoading,
                    size: ZyntroButtonSize.lg,
                    onPressed: _isLoading ? null : _handleEmailSignUp,
                  ),

                  const SizedBox(height: 20),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: AppColors.surfaceV2Elevated),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textV2Tertiary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: AppColors.surfaceV2Elevated),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Google Sign Up
                  GestureDetector(
                    onTap: _isLoading ? null : _handleGoogleSignIn,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2Elevated,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        border: Border.all(color: AppColors.surfaceV2Active),
                      ),
                      child: _socialLoading == 'google'
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.textV2Primary,
                                ),
                              ),
                            )
                          : Row(
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
                                Text(
                                  'Sign up with Google',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textV2Primary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Facebook Sign Up
                  GestureDetector(
                    onTap: _isLoading ? null : _handleFacebookSignUp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2Elevated,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        border: Border.all(color: AppColors.surfaceV2Active),
                      ),
                      child: _socialLoading == 'facebook'
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.textV2Primary,
                                ),
                              ),
                            )
                          : Row(
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
                                Text(
                                  'Sign up with Facebook',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textV2Primary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTextStyles.bodyLarge.copyWith(
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
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.userAccent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
