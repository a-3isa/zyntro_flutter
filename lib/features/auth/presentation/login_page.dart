import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
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
  String? _socialLoading; // 'google' | 'facebook' | null
  String? _errorMessage;
  String? _errorSuggestion;

  bool get _isLoading => _socialLoading != null;

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
                          color: AppColors.userAccent,
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
