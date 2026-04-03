import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/constants.dart';
import '../../../core/models/models.dart';
import '../../../services/media_service.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/premium_effects.dart';
import '../../../widgets/responsive_center.dart';
import '../../../widgets/avatar_selector.dart';
import '../../auth/auth_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';

import 'package:cached_network_image/cached_network_image.dart';

final editProfileUserProvider = FutureProvider<User?>((ref) async {
  final authState = ref.watch(authSessionProvider);
  final uid = authState.valueOrNull?.id;
  if (uid == null) return null;

  final profile = await ref.read(authControllerProvider).getUserProfile(uid);
  if (profile == null) return null;

  return User(
    id: profile.id,
    displayName: profile.displayName,
    photoURL: profile.photoUrl,
    avatarConfig: profile.avatarConfig,
    isPrivate: profile.isPrivate,
    workoutPreference: profile.workoutPreference,
    beginnerFlag: profile.beginnerFlag,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
});

/// Edit profile page for updating user profile information.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  String? _photoPath; // Local file path for upload
  String? _existingPhotoUrl; // Remote URL
  String? _selectedAvatar; // Selected avatar config
  String? _originalAvatar; // Original avatar config
  bool _isUsingAvatar = false; // Toggle state

  WorkoutType _workoutPreference = WorkoutType.gym;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _hasChanges = false;
  String? _originalDisplayName;
  WorkoutType? _originalWorkoutPreference;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _displayNameController.addListener(_checkForChanges);
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_checkForChanges);
    _displayNameController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    // Determine original mode
    final bool originalIsUsingAvatar =
        _existingPhotoUrl == null && _originalAvatar != null;

    bool isProfileChanged = false;

    if (_isUsingAvatar != originalIsUsingAvatar) {
      isProfileChanged = true;
    } else {
      if (_isUsingAvatar) {
        // Both using avatar - check if avatar config changed
        if (_selectedAvatar != _originalAvatar) isProfileChanged = true;
      } else {
        // Both using photo - check if new photo selected
        if (_photoPath != null) isProfileChanged = true;
      }
    }

    final hasChanges =
        _displayNameController.text != _originalDisplayName ||
        _workoutPreference != _originalWorkoutPreference ||
        isProfileChanged;

    // Always trigger rebuild to update char counter and validation helper
    setState(() => _hasChanges = hasChanges);
  }

  void _loadUserData() {
    final userAsync = ref.read(editProfileUserProvider);
    userAsync.whenData((user) {
      if (user != null) {
        _displayNameController.text = user.displayName;
        _workoutPreference = user.workoutPreference;
        _originalDisplayName = user.displayName;
        _originalWorkoutPreference = user.workoutPreference;

        // Photo/Avatar logic
        _existingPhotoUrl = user.photoURL;
        final avatarConfig = user.avatarConfig;

        if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
          // User has a photo
          _isUsingAvatar = false;
          _selectedAvatar =
              avatarConfig; // Keep track of their avatar if they switch back
        } else if (avatarConfig != null && avatarConfig.isNotEmpty) {
          // User has an avatar
          _isUsingAvatar = true;
          _selectedAvatar = avatarConfig;
        } else {
          // Neither
          _isUsingAvatar = false;
          _selectedAvatar = null;
        }

        _originalAvatar = _selectedAvatar;

        setState(() {});
      }
    });
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _photoPath = image.path;
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
    if (uid == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      String? photoUrl = _existingPhotoUrl;
      String? avatarConfig = _selectedAvatar;

      if (_isUsingAvatar) {
        // If using avatar, clear photo URL to ensure avatar takes precedence
        // But only if we are actually saving an avatar
        if (avatarConfig != null) {
          photoUrl = null; // This will trigger field deletion or update to null
        }
      } else {
        // If using photo, clear avatar config? Not strictly necessary if photoURL takes precedence in UI
        // But cleaner to keep them in sync.
        // Actually, let's keep avatar config as a fallback/history unless explicitly clearing.
        // The implementation plan says: "If Photo is selected: Upload if new, set photoURL. avatarConfig can remain."

        // Upload new photo if selected
        if (_photoPath != null) {
          setState(() => _isUploading = true);
          photoUrl = await ref
              .read(mediaServiceProvider)
              .uploadProfilePhoto(filePath: _photoPath!, userId: uid);
          setState(() => _isUploading = false);
        }
      }

      final Map<String, dynamic> updates = {
        'displayName': _displayNameController.text.trim(),
        'workoutPreference': _workoutPreference.value,
      };

      if (_isUsingAvatar) {
        if (avatarConfig != null) {
          updates['avatarConfig'] = avatarConfig;
          // We need to REMOVE photoURL. Passing null to update might not work depending on repository.
          // AuthService.updateUserProfile uses SetOptions(merge: true).
          // If we pass null, it might be ignored or set to null.
          // However, to be safe and explicit, let's check auth_service.
          updates['photoURL'] = FieldValue.delete();
        }
      } else {
        if (photoUrl != null) {
          updates['photoURL'] = photoUrl;
          // Ideally we might want to unset avatarConfig, but it's optional.
        }
      }

      // Update profile
      await ref
          .read(authControllerProvider)
          .updateUserProfile(userId: uid, data: updates);

      // Invalidate user profile provider to refresh data
      ref.invalidate(editProfileUserProvider);

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Profile updated successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(editProfileUserProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 8,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                BounceAnimation(
                  onTap: () {
                    HapticManager.light();
                    context.pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: GradientText(
                    text: 'Edit Profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    colors: [AppColors.textDark, AppColors.textSecondaryDark],
                  ),
                ),
                // Save Button
                _hasChanges
                    ? GradientBorderAnimation(
                        enabled: true,
                        borderRadius: BorderRadius.circular(12),
                        gradientColors: AppColors.primaryGradient,
                        child: BounceAnimation(
                          onTap: _isLoading ? null : _saveChanges,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        AppColors.primary,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Save',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: null,
                        child: Text(
                          'Save',
                          style: TextStyle(color: AppColors.textTertiaryDark),
                        ),
                      ),
              ],
            ),
          ),
          Expanded(
            child: userAsync.when(
              data: (user) {
                if (user == null) {
                  return const Center(child: Text('User not found'));
                }

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ResponsiveCenter(
                    alignment: Alignment.topCenter,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Photo/Avatar Section
                          Column(
                            children: [
                              // Toggle between Photo and Avatar
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSecondaryDark,
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.full,
                                  ),
                                  border: Border.all(
                                    color: AppColors.borderDark,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildToggleOption(
                                      title: 'Photo',
                                      isSelected: !_isUsingAvatar,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _isUsingAvatar = false;
                                          _checkForChanges();
                                        });
                                      },
                                    ),
                                    _buildToggleOption(
                                      title: 'Avatar',
                                      isSelected: _isUsingAvatar,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _isUsingAvatar = true;
                                          _checkForChanges();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),

                              // Content based on selection
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _isUsingAvatar
                                    ? Column(
                                        key: const ValueKey('avatar'),
                                        children: [
                                          AvatarSelector(
                                            initialAvatar: _selectedAvatar,
                                            onAvatarSelected: (avatar) {
                                              setState(() {
                                                _selectedAvatar = avatar;
                                                _checkForChanges();
                                              });
                                            },
                                          ),
                                        ],
                                      )
                                    : Column(
                                        key: const ValueKey('photo'),
                                        children: [
                                          SlideInAnimation.fromBottom(
                                            index: 0,
                                            child: BounceAnimation(
                                              onTap: _pickImage,
                                              child: Stack(
                                                children: [
                                                  Container(
                                                    width: 130,
                                                    height: 130,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      gradient:
                                                          const LinearGradient(
                                                            colors: AppColors
                                                                .primaryGradient,
                                                            begin: Alignment
                                                                .topLeft,
                                                            end: Alignment
                                                                .bottomRight,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: AppColors
                                                              .primary
                                                              .withValues(
                                                                alpha: 0.22,
                                                              ),
                                                          blurRadius: 24,
                                                          offset: const Offset(
                                                            0,
                                                            10,
                                                          ),
                                                        ),
                                                        const BoxShadow(
                                                          color: Color(
                                                            0x33000000,
                                                          ),
                                                          blurRadius: 18,
                                                          offset: Offset(0, 10),
                                                        ),
                                                      ],
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    child: Container(
                                                      decoration:
                                                          const BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            color: AppColors
                                                                .surfaceDark,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child: _isUploading
                                                          ? ShimmerLoading(
                                                              child: CircleAvatar(
                                                                radius: 57,
                                                                backgroundColor:
                                                                    AppColors
                                                                        .surfaceSecondaryDark,
                                                              ),
                                                            )
                                                          : Hero(
                                                              tag:
                                                                  'avatar_${user.id}',
                                                              child: ClipOval(
                                                                child:
                                                                    (_photoPath !=
                                                                        null)
                                                                    ? Image.file(
                                                                        File(
                                                                          _photoPath!,
                                                                        ),
                                                                        width:
                                                                            114,
                                                                        height:
                                                                            114,
                                                                        fit: BoxFit
                                                                            .cover,
                                                                      )
                                                                    : (_existingPhotoUrl !=
                                                                              null &&
                                                                          _existingPhotoUrl!
                                                                              .isNotEmpty)
                                                                    ? CachedNetworkImage(
                                                                        imageUrl:
                                                                            _existingPhotoUrl!,
                                                                        width:
                                                                            114,
                                                                        height:
                                                                            114,
                                                                        fit: BoxFit
                                                                            .cover,
                                                                        placeholder:
                                                                            (
                                                                              context,
                                                                              url,
                                                                            ) => Container(
                                                                              color: AppColors.surfaceSecondaryDark,
                                                                            ),
                                                                        errorWidget:
                                                                            (
                                                                              context,
                                                                              url,
                                                                              error,
                                                                            ) => const Icon(
                                                                              Icons.error,
                                                                            ),
                                                                      )
                                                                    : Container(
                                                                        width:
                                                                            114,
                                                                        height:
                                                                            114,
                                                                        color: AppColors
                                                                            .surfaceSecondaryDark,
                                                                        child: Center(
                                                                          child: Text(
                                                                            user.displayName.isNotEmpty
                                                                                ? user.displayName[0].toUpperCase()
                                                                                : 'U',
                                                                            style: const TextStyle(
                                                                              fontSize: 40,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: AppColors.primary,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    child: ScaleOnTap(
                                                      onTap: _pickImage,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              10,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          gradient:
                                                              const LinearGradient(
                                                                colors: AppColors
                                                                    .primaryGradient,
                                                              ),
                                                          shape:
                                                              BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: AppColors
                                                                  .primary
                                                                  .withValues(
                                                                    alpha: 0.4,
                                                                  ),
                                                              blurRadius: 8,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    4,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: const Icon(
                                                          Icons.camera_alt,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          FadeInAnimation(
                                            delay: const Duration(
                                              milliseconds: 200,
                                            ),
                                            child: Text(
                                              'Tap to change photo',
                                              style: TextStyle(
                                                fontSize: AppFontSize.sm,
                                                color:
                                                    AppColors.textSecondaryDark,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.xxl),

                          // Display name field with glass container
                          SlideInAnimation.fromBottom(
                            index: 1,
                            child: GlassContainer(
                              blur: 10,
                              backgroundColor: AppColors.surfaceSecondaryDark
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.lg,
                              ),
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      const Text(
                                        'Display Name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: AppFontSize.md,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const Spacer(),
                                      // Character count
                                      AnimatedCounter(
                                        value:
                                            _displayNameController.text.length,
                                        style: TextStyle(
                                          fontSize: AppFontSize.xs,
                                          color: AppColors.textTertiaryDark,
                                        ),
                                        suffix: '/30',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _displayNameController,
                                    maxLength: 30,
                                    style: const TextStyle(
                                      color: AppColors.textDark,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter your display name',
                                      hintStyle: TextStyle(
                                        color: AppColors.textTertiaryDark,
                                      ),
                                      counterText: '',
                                      filled: true,
                                      fillColor: AppColors.surfaceDark
                                          .withValues(alpha: 0.5),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppBorderRadius.md,
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppBorderRadius.md,
                                        ),
                                        borderSide: const BorderSide(
                                          color: AppColors.primary,
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppBorderRadius.md,
                                        ),
                                        borderSide: const BorderSide(
                                          color: AppColors.error,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.lg,
                                            vertical: AppSpacing.md,
                                          ),
                                      suffixIcon:
                                          _displayNameController.text.length >=
                                              2
                                          ? FadeInAnimation(
                                              child: const Icon(
                                                Icons.check_circle,
                                                color: AppColors.success,
                                              ),
                                            )
                                          : null,
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter a display name';
                                      }
                                      if (value.trim().length < 2) {
                                        return 'Display name must be at least 2 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // Workout preference with glass container
                          SlideInAnimation.fromBottom(
                            index: 2,
                            child: GradientBorder(
                              gradientColors: AppColors.primaryGradient,
                              borderWidth: 1,
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.lg,
                              ),
                              child: GlassContainer(
                                blur: 10,
                                backgroundColor: AppColors.surfaceSecondaryDark
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.lg - 1,
                                ),
                                border: Border.all(color: Colors.transparent),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      child: Row(
                                        children: const [
                                          Icon(
                                            Icons.fitness_center,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: AppSpacing.sm),
                                          Text(
                                            'Workout Preference',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: AppFontSize.md,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildWorkoutRadioTile(
                                      title: 'Strength Training',
                                      subtitle:
                                          'Weight lifting, resistance training',
                                      value: WorkoutType.gym,
                                      index: 0,
                                    ),
                                    _buildWorkoutRadioTile(
                                      title: 'Cardio',
                                      subtitle: 'Running, cycling, HIIT',
                                      value: WorkoutType.running,
                                      index: 1,
                                    ),
                                    _buildWorkoutRadioTile(
                                      title: 'Hybrid',
                                      subtitle: 'Mix of strength and cardio',
                                      value: WorkoutType.other,
                                      index: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xxl),

                          // Unsaved changes indicator
                          if (_hasChanges)
                            SlideInAnimation.fromBottom(
                              index: 3,
                              child: PulseAnimation(
                                minScale: 1.0,
                                maxScale: 1.02,
                                duration: const Duration(milliseconds: 1500),
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.info.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.md,
                                    ),
                                    border: Border.all(
                                      color: AppColors.info.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: AppColors.info,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      const Expanded(
                                        child: Text(
                                          'You have unsaved changes',
                                          style: TextStyle(
                                            color: AppColors.info,
                                            fontSize: AppFontSize.sm,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              loading: () => ShimmerLoading(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      ShimmerSkeleton.circle(size: 130),
                      const SizedBox(height: AppSpacing.sm),
                      ShimmerSkeleton.text(width: 120),
                      const SizedBox(height: AppSpacing.xxl),
                      const ShimmerSkeleton(height: 120),
                      const SizedBox(height: AppSpacing.xl),
                      const ShimmerSkeleton(height: 200),
                    ],
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Error: $e'),
                    const SizedBox(height: AppSpacing.md),
                    BounceAnimation(
                      onTap: () => ref.invalidate(editProfileUserProvider),
                      child: ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(editProfileUserProvider),
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutRadioTile({
    required String title,
    required String subtitle,
    required WorkoutType value,
    required int index,
  }) {
    final isSelected = _workoutPreference == value;

    return SlideInAnimation.fromRight(
      index: index,
      delay: const Duration(milliseconds: 30),
      child: ScaleOnTap(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _workoutPreference = value;
            _checkForChanges();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textTertiaryDark,
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textSecondaryDark,
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

  Widget _buildToggleOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondaryDark,
            fontWeight: FontWeight.w600,
            fontSize: AppFontSize.sm,
          ),
        ),
      ),
    );
  }
}
