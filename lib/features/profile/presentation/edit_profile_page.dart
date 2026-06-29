import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/constants.dart';
import '../../../core/models/models.dart';
import '../../../services/media_service.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/responsive_center.dart';

import '../../auth/auth_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import 'profile_page.dart';

import 'package:cached_network_image/cached_network_image.dart';

final editProfileUserProvider = FutureProvider<User?>((ref) async {
  final authState = ref.watch(authSessionProvider);
  final uid = authState.value?.id;
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

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  String? _photoPath;
  String? _existingPhotoUrl;
  WorkoutType _workoutPreference = WorkoutType.gym;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _hasChanges = false;
  String? _originalDisplayName;
  WorkoutType? _originalWorkoutPreference;
  Color? _selectedAccentColor;
  Color? _originalAccentColor;

  static const List<Color> _accentColors = [
    Color(0xFFC8FF00), // Lime (default)
    Color(0xFF38BDF8), // Sky
    Color(0xFFFF8C00), // Orange
    Color(0xFFA78BFA), // Purple
    Color(0xFF34D399), // Emerald
    Color(0xFF22D3EE), // Cyan
    Color(0xFFFF4D6D), // Pink
    Color(0xFFFBBF24), // Amber
  ];

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
    final hasChanges =
        _displayNameController.text != _originalDisplayName ||
        _workoutPreference != _originalWorkoutPreference ||
        _photoPath != null ||
        _selectedAccentColor != _originalAccentColor;
    setState(() => _hasChanges = hasChanges);
  }

  void _loadFromUser(User user) {
    setState(() {
      _displayNameController.text = user.displayName;
      _workoutPreference = user.workoutPreference;
      _originalDisplayName = user.displayName;
      _originalWorkoutPreference = user.workoutPreference;
      _existingPhotoUrl = user.photoURL;
      final hex = user.avatarConfig?.replaceFirst('#', '').trim();
      if (hex != null && hex.isNotEmpty) {
        final value = int.tryParse(hex, radix: 16);
        if (value != null) {
          _selectedAccentColor = Color(
            hex.length <= 6 ? (0xFF000000 | value) : value,
          );
        }
      }
      _selectedAccentColor ??= AppColors.userAccent;
      _originalAccentColor = _selectedAccentColor;
    });
  }

  void _loadUserData() {
    final userAsync = ref.read(editProfileUserProvider);
    userAsync.whenData((user) {
      if (user != null) _loadFromUser(user);
    });
  }

  String _colorToHex(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    return '${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
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
    final uid = authState.value?.id;
    if (uid == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      String? photoUrl = _existingPhotoUrl;

      if (_photoPath != null) {
        setState(() => _isUploading = true);
        photoUrl = await ref
            .read(mediaServiceProvider)
            .uploadProfilePhoto(filePath: _photoPath!, userId: uid);
        setState(() => _isUploading = false);
      }

      final Map<String, dynamic> updates = {
        'displayName': _displayNameController.text.trim(),
        'workoutPreference': _workoutPreference.value,
        'photoURL': ?photoUrl,
        if (_selectedAccentColor != null &&
            _selectedAccentColor != _originalAccentColor)
          'avatarConfig': _colorToHex(_selectedAccentColor!),
      };

      await ref
          .read(authControllerProvider)
          .updateUserProfile(userId: uid, data: updates);
      if (_selectedAccentColor != null &&
          _selectedAccentColor != _originalAccentColor) {
        AppColors.setAccent(_selectedAccentColor!);
      }
      ref.invalidate(editProfileUserProvider);
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(otherUserProfileProvider(uid));
      ref.invalidate(authUserProfileProvider);

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
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
      backgroundColor: AppColors.backgroundV2,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 8,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticManager.light();
                    context.pop();
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2Elevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textV2Primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Edit Profile',
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Primary,
                    ),
                  ),
                ),
                // Save Button
                _hasChanges
                    ? GestureDetector(
                        onTap: _isLoading ? null : _saveChanges,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceV2Elevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.userAccent),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.userAccent,
                                  ),
                                )
                              : Text(
                                  'Save',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.userAccent,
                                  ),
                                ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Save',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textV2Tertiary,
                          ),
                        ),
                      ),
              ],
            ),
          ),
          Expanded(
            child: userAsync.when(
              data: (user) {
                if (user == null) {
                  return Center(
                    child: Text(
                      'User not found',
                      style: TextStyle(color: AppColors.textV2Secondary),
                    ),
                  );
                }

                // Lazily initialize state if _loadUserData ran before provider resolved.
                if (_originalDisplayName == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _originalDisplayName == null) {
                      _loadFromUser(user);
                    }
                  });
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
                          // Profile photo
                          Column(
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 130,
                                      height: 130,
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.userAccent,
                                      ),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.surfaceV2,
                                        ),
                                        padding: const EdgeInsets.all(3),
                                        child: _isUploading
                                            ? const CircleAvatar(
                                                radius: 57,
                                                backgroundColor:
                                                    AppColors.surfaceV2Elevated,
                                              )
                                            : Hero(
                                                tag: 'avatar_${user.id}',
                                                child: ClipOval(
                                                  child: _buildAvatarContent(
                                                    user,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: _pickImage,
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.userAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            color: AppColors.backgroundV2,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                user.displayName,
                                style: AppTextStyles.h4.copyWith(
                                  color: AppColors.textV2Primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to change photo',
                                style: TextStyle(
                                  fontSize: AppFontSize.sm,
                                  color: AppColors.textV2Secondary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.xxl),

                          // Display name section
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceV2Elevated,
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.lg,
                              ),
                              border: Border.all(
                                color: AppColors.surfaceV2Active,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      color: AppColors.userAccent,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'Display Name',
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textV2Primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_displayNameController.text.length}/30',
                                      style: TextStyle(
                                        fontSize: AppFontSize.xs,
                                        color: AppColors.textV2Tertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextFormField(
                                  controller: _displayNameController,
                                  maxLength: 30,
                                  style: const TextStyle(
                                    color: AppColors.textV2Primary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter your display name',
                                    hintStyle: TextStyle(
                                      color: AppColors.textV2Tertiary,
                                    ),
                                    counterText: '',
                                    filled: true,
                                    fillColor: AppColors.surfaceV2,
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
                                      borderSide: BorderSide(
                                        color: AppColors.userAccent,
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
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                      vertical: AppSpacing.md,
                                    ),
                                    suffixIcon:
                                        _displayNameController.text.length >= 2
                                        ? const Icon(
                                            Icons.check_circle,
                                            color: AppColors.success,
                                          )
                                        : null,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
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

                          const SizedBox(height: AppSpacing.xl),

                          // Accent color section
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceV2Elevated,
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.lg,
                              ),
                              border: Border.all(
                                color: AppColors.surfaceV2Active,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.palette_outlined,
                                      color: AppColors.userAccent,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'Accent Color',
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textV2Primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: _accentColors
                                      .map((c) => _buildColorSwatch(c))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // Workout preference section
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceV2Elevated,
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.lg,
                              ),
                              border: Border.all(
                                color: AppColors.userAccent.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.fitness_center,
                                        color: AppColors.userAccent,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        'Workout Preference',
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textV2Primary,
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

                          const SizedBox(height: AppSpacing.xxl),

                          if (_hasChanges)
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.md,
                                ),
                                border: Border.all(
                                  color: AppColors.info.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppColors.info,
                                    size: 20,
                                  ),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(
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
                        ],
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    SizedBox(width: 130, height: 130),
                    SizedBox(height: AppSpacing.sm),
                    SizedBox(width: 120, height: 14),
                    SizedBox(height: AppSpacing.xxl),
                    SizedBox(height: 120),
                    SizedBox(height: AppSpacing.xl),
                    SizedBox(height: 200),
                  ],
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
                    ElevatedButton(
                      onPressed: () => ref.invalidate(editProfileUserProvider),
                      child: const Text('Retry'),
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

  Widget _buildAvatarContent(User user) {
    if (_photoPath != null) {
      return Image.file(
        File(_photoPath!),
        width: 114,
        height: 114,
        fit: BoxFit.cover,
      );
    }
    final photoUrl = _existingPhotoUrl ?? user.photoURL;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: photoUrl,
        width: 114,
        height: 114,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(color: AppColors.surfaceV2Elevated),
        errorWidget: (_, _, _) => const Icon(Icons.error),
      );
    }
    return Container(
      width: 114,
      height: 114,
      color: AppColors.surfaceV2Elevated,
      child: Center(
        child: Text(
          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
          style: AppTextStyles.display.copyWith(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: AppColors.userAccent,
          ),
        ),
      ),
    );
  }

  Widget _buildColorSwatch(Color color) {
    final current = _selectedAccentColor ?? AppColors.userAccent;
    final isSelected =
        (current.r == color.r && current.g == color.g && current.b == color.b);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedAccentColor = color;
          _checkForChanges();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: isSelected
              ? Border.all(color: AppColors.textV2Primary, width: 2.5)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: AppColors.backgroundV2, size: 20)
            : null,
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

    return GestureDetector(
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
              ? AppColors.userAccent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.userAccent : Colors.transparent,
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
                      ? AppColors.userAccent
                      : AppColors.textV2Tertiary,
                  width: 2,
                ),
                color: isSelected ? AppColors.userAccent : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: AppColors.backgroundV2,
                    )
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
                          ? AppColors.userAccent
                          : AppColors.textV2Primary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textV2Secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
