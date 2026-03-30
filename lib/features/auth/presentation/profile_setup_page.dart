import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/constants.dart';
import '../../../app/navigation/app_router.dart';
import '../../../widgets/email_verification_banner.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/premium_effects.dart';
import '../../../widgets/avatar_selector.dart';
import '../auth_providers.dart';
import 'providers/auth_controller.dart';

/// Premium Profile setup screen for new users.
class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  WorkoutType _workoutPreference = WorkoutType.other;
  bool _isLoading = false;
  bool _isBeginner = false;
  String? _photoUrl; // For social auth providers
  String? _selectedAvatar; // For avatar selection
  double? _uploadProgress;
  String _uploadStatus = '';
  String _authProvider = 'email'; // Track auth provider

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = GoRouterState.of(context);
      if (state.extra is WorkoutType) {
        setState(() {
          _workoutPreference = state.extra as WorkoutType;
        });
      }

      // Pre-fill data from social providers
      final authState = ref.read(authSessionProvider);
      final user = authState.valueOrNull;

      if (user != null) {
        // Detect auth provider
        final providerData = user.providerIds;
        final isGoogleSignup = providerData.contains('google.com');
        final isFacebookSignup = providerData.contains('facebook.com');

        setState(() {
          if (isGoogleSignup) {
            _authProvider = 'google';
          } else if (isFacebookSignup) {
            _authProvider = 'facebook';
          }

          // Pre-fill name and photo for social signups
          if (_authProvider != 'email') {
            _nameController.text = user.displayName ?? '';
            _photoUrl = user.photoUrl;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authSessionProvider);
      final uid = authState.valueOrNull?.id;

      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // For email signups, use avatarConfig instead of uploading photos
      // For social auth, keep using photoURL from provider
      String? avatarConfigToSave;
      String? photoUrlToSave;

      if (_authProvider == 'email') {
        // Use avatar config for email signups
        avatarConfigToSave = _selectedAvatar;
      } else {
        // Use photo URL from social providers (already set in initState)
        photoUrlToSave = _photoUrl;
      }

      setState(() => _uploadStatus = 'Creating profile...');

      await ref
          .read(authControllerProvider)
          .createUserProfile(
            userId: uid,
            displayName: _nameController.text.trim(),
            workoutPreference: _workoutPreference,
            beginnerFlag: _isBeginner,
            photoUrl: photoUrlToSave,
            avatarConfig: avatarConfigToSave,
            authProvider: _authProvider,
          );

      if (mounted) {
        ref.invalidate(authProfileCompletionProvider);
        context.go(AppRoutes.main);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleSubmit,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Background orbs
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
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
                    AppColors.secondary.withValues(alpha: 0.15),
                    AppColors.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xl),

                    // Header
                    const GradientText(
                      text: 'Set Up Your Profile',
                      style: TextStyle(
                        fontSize: AppFontSize.xxl,
                        fontWeight: FontWeight.bold,
                      ),
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "Let's personalize your experience",
                      style: TextStyle(
                        fontSize: AppFontSize.md,
                        color: AppColors.textSecondaryDark,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Email Verification Banner - only for email signups
                    Consumer(
                      builder: (context, ref, child) {
                        final authState = ref.watch(authSessionProvider);
                        final user = authState.valueOrNull;

                        // Only show for email signups
                        if (user != null &&
                            !user.emailVerified &&
                            _authProvider == 'email') {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xl,
                            ),
                            child: EmailVerificationBanner(
                              onResendPressed: () async {
                                await ref
                                    .read(authControllerProvider)
                                    .sendEmailVerification();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Verification email sent!',
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // Photo/Avatar Selection - conditional based on auth provider
                    if (_authProvider == 'email') ...[
                      // Avatar selector for email signups
                      AvatarSelector(
                        onAvatarSelected: (avatar) {
                          setState(() => _selectedAvatar = avatar);
                        },
                        initialAvatar: _selectedAvatar,
                      ),
                    ] else ...[
                      // Show social profile photo for Google/Facebook
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: AppColors.primaryGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surfaceDark,
                                  image: _photoUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_photoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _photoUrl == null
                                    ? Icon(
                                        Icons.person,
                                        size: 60,
                                        color: AppColors.textSecondaryDark,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Profile photo from ${_authProvider == 'google' ? 'Google' : 'Facebook'}',
                              style: TextStyle(
                                fontSize: AppFontSize.sm,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xxxl),

                    // Name field
                    _buildTextField(
                      controller: _nameController,
                      label: 'Display Name',
                      hint: 'How should we call you?',
                      icon: Icons.person_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Workout preference
                    Text(
                      'What type of workouts do you prefer?',
                      style: TextStyle(
                        fontSize: AppFontSize.md,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildWorkoutChips(),

                    const SizedBox(height: AppSpacing.xxl),

                    // Beginner toggle
                    _buildBeginnerToggle(),

                    const SizedBox(height: AppSpacing.xl),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Submit button
                    ZyntroButton(
                      title: _isLoading ? '' : 'Continue',
                      fullWidth: true,
                      size: ZyntroButtonSize.lg,
                      loading: _isLoading,
                      variant: ZyntroButtonVariant.premium,
                      rightIcon: _isLoading
                          ? null
                          : const Icon(Icons.arrow_forward_rounded),
                      onPressed: _isLoading ? null : _handleSubmit,
                    ),

                    // Upload progress
                    if (_isLoading && _uploadStatus.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      if (_uploadProgress != null && _uploadProgress! < 1.0)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: AppColors.surfaceSecondaryDark,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _uploadStatus,
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: AppFontSize.sm,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textSecondaryDark),
        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
        hintStyle: TextStyle(color: AppColors.textTertiaryDark),
        filled: true,
        fillColor: AppColors.surfaceSecondaryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildWorkoutChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: WorkoutType.values.map((type) {
        final isSelected = _workoutPreference == type;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _workoutPreference = type);
          },
          child: AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(colors: AppColors.primaryGradient)
                  : null,
              color: isSelected ? null : AppColors.surfaceSecondaryDark,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.borderDark,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              type.value.toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondaryDark,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: AppFontSize.sm,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBeginnerToggle() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryDark,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Icon(Icons.school_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "I'm new to fitness",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  "We'll provide extra guidance and tips",
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isBeginner,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _isBeginner = value);
            },
            thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary;
              }
              return null;
            }),
            trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary.withValues(alpha: 0.3);
              }
              return null;
            }),
          ),
        ],
      ),
    );
  }
}
