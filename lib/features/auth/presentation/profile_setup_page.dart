import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/constants.dart';
import '../../../app/navigation/app_router.dart';
import '../../../widgets/email_verification_banner.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/avatar_selector.dart';
import '../auth_providers.dart';
import 'providers/auth_controller.dart';

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
  String? _photoUrl;
  String? _selectedAvatar;
  double? _uploadProgress;
  String _uploadStatus = '';
  String _authProvider = 'email';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = GoRouterState.of(context);
      if (state.extra is WorkoutType) {
        setState(() => _workoutPreference = state.extra as WorkoutType);
      }

      final authState = ref.read(authSessionProvider);
      final user = authState.valueOrNull;

      if (user != null) {
        final providerData = user.providerIds;
        final isGoogleSignup = providerData.contains('google.com');
        final isFacebookSignup = providerData.contains('facebook.com');

        setState(() {
          if (isGoogleSignup) {
            _authProvider = 'google';
          } else if (isFacebookSignup) {
            _authProvider = 'facebook';
          }

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

      if (uid == null) throw Exception('User not authenticated');

      String? avatarConfigToSave;
      String? photoUrlToSave;

      if (_authProvider == 'email') {
        avatarConfigToSave = _selectedAvatar;
      } else {
        photoUrlToSave = _photoUrl;
      }

      setState(() => _uploadStatus = 'Creating profile...');

      await ref.read(authControllerProvider).createUserProfile(
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleSubmit,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
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
                Text(
                  'Set Up Your Profile',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "Let's personalize your experience",
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textV2Secondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Email Verification Banner
                Consumer(
                  builder: (context, ref, child) {
                    final authState = ref.watch(authSessionProvider);
                    final user = authState.valueOrNull;

                    if (user != null && !user.emailVerified && _authProvider == 'email') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        child: EmailVerificationBanner(
                          onResendPressed: () async {
                            await ref.read(authControllerProvider).sendEmailVerification();
                            if (context.mounted) {
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
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Photo/Avatar Selection
                if (_authProvider == 'email') ...[
                  AvatarSelector(
                    onAvatarSelected: (avatar) => setState(() => _selectedAvatar = avatar),
                    initialAvatar: _selectedAvatar,
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 130,
                          height: 130,
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accentLime,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceV2,
                              image: _photoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_photoUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _photoUrl == null
                                ? Icon(Icons.person, size: 60, color: AppColors.textV2Secondary)
                                : null,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Profile photo from ${_authProvider == 'google' ? 'Google' : 'Facebook'}',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textV2Secondary,
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
                    if (value == null || value.trim().isEmpty) return 'Please enter your name';
                    if (value.trim().length < 2) return 'Name must be at least 2 characters';
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.xxl),

                Text(
                  'What type of workouts do you prefer?',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textV2Primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildWorkoutChips(),

                const SizedBox(height: AppSpacing.xxl),

                _buildBeginnerToggle(),

                const SizedBox(height: AppSpacing.xl),
                const SizedBox(height: AppSpacing.xxxl),

                // Submit button
                ZyntroButton(
                  title: _isLoading ? '' : 'Continue',
                  fullWidth: true,
                  size: ZyntroButtonSize.lg,
                  loading: _isLoading,
                  rightIcon: _isLoading ? null : const Icon(Icons.arrow_forward_rounded),
                  onPressed: _isLoading ? null : _handleSubmit,
                ),

                if (_isLoading && _uploadStatus.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (_uploadProgress != null && _uploadProgress! < 1.0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: AppColors.surfaceV2Elevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentLime),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _uploadStatus,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textV2Secondary,
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
      style: const TextStyle(color: AppColors.textV2Primary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textV2Secondary),
        labelStyle: TextStyle(color: AppColors.textV2Secondary),
        hintStyle: TextStyle(color: AppColors.textV2Tertiary),
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
              color: isSelected ? AppColors.accentLime : AppColors.surfaceV2Elevated,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              border: Border.all(
                color: isSelected ? AppColors.accentLime : AppColors.surfaceV2Active,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              type.value.toUpperCase(),
              style: AppTextStyles.body.copyWith(
                color: isSelected ? AppColors.backgroundV2 : AppColors.textV2Secondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
        color: AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.surfaceV2Active),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_outlined, color: AppColors.accentLime),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "I'm new to fitness",
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textV2Primary,
                  ),
                ),
                Text(
                  "We'll provide extra guidance and tips",
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textV2Secondary,
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
              if (states.contains(WidgetState.selected)) return AppColors.backgroundV2;
              return null;
            }),
            trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) return AppColors.accentLime;
              return AppColors.surfaceV2Active;
            }),
          ),
        ],
      ),
    );
  }
}
