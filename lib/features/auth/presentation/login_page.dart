import 'dart:async';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
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
import 'widgets/social_auth_row.dart';

/// Login screen — concrete charcoal, no glassmorphism.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  String? _socialLoading; // 'google' | 'facebook' | 'apple' | null
  bool _emailLoading = false;
  String? _errorMessage;
  String? _errorSuggestion;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool get _isLoading => _socialLoading != null || _emailLoading;

  Future<void> _handleEmailSignIn() async {
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
          .signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );

      if (mounted) {
        HapticFeedback.mediumImpact();
        // Router decides main vs onboarding based on profile completeness.
        context.go(AppRoutes.main);
      }
    } on AuthFlowException catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = e.message;
          _errorSuggestion = e.code == 'user-not-found'
              ? 'Create an account to get started.'
              : null;
        });
      }
    } catch (_) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Sign-in failed. Please try again.';
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

  Future<void> _handleFacebookSignIn() async {
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
      if (mounted) setState(() => _socialLoading = null);
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _socialLoading = 'apple';
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authControllerProvider).signInWithApple();

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
            _errorMessage = 'Apple Sign-In failed. Please try again.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _socialLoading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                  const SizedBox(height: 16),

                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceV2,
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.go(AppRoutes.splash);
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Heading
                  Text(
                    l10n.welcomeBack,
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Primary,
                      letterSpacing: -1,
                      height: 1.1,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    l10n.signInSubtitle,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textV2Secondary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 20),

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

                  // Email
                  AuthTextField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    hint: l10n.emailAddress,
                    icon: Icons.email_outlined,
                    enabled: !_isLoading,
                    validator: validateEmail,
                    autofillHints: const [AutofillHints.email],
                    onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  ),

                  const SizedBox(height: 12),

                  // Password. Sign-in only checks the credential against Firebase,
                  // so it must not enforce the sign-up strength rules — an older
                  // account may legitimately have a weaker password.
                  AuthTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    hint: l10n.password,
                    icon: Icons.lock_outline,
                    isPassword: true,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    validator: (value) => (value == null || value.isEmpty)
                        ? l10n.enterPassword
                        : null,
                    onFieldSubmitted: (_) => _handleEmailSignIn(),
                  ),

                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              context.push(AppRoutes.forgotPassword);
                            },
                      child: Text(
                        l10n.forgotPassword,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.signal,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  ZyntroButton(
                    title: l10n.signIn,
                    fullWidth: true,
                    loading: _emailLoading,
                    size: ZyntroButtonSize.lg,
                    onPressed: _isLoading ? null : _handleEmailSignIn,
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

                  const SizedBox(height: 16),

                  SocialAuthRow(
                    onGoogle: _handleGoogleSignIn,
                    onFacebook: _handleFacebookSignIn,
                    onApple: _handleAppleSignIn,
                    loadingProvider: _socialLoading,
                    enabled: !_isLoading,
                  ),

                  const SizedBox(height: 20),

                  // Sign up link
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textV2Secondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.go(AppRoutes.signUp);
                          },
                          child: Text(
                            l10n.signUp,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.signal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
