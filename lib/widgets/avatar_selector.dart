import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:avatar_plus/avatar_plus.dart';
import 'dart:math';

import '../core/theme/app_theme.dart';
import 'premium_animations.dart';

/// Avatar selector widget for choosing and customizing profile avatars using AvatarPlus
class AvatarSelector extends StatefulWidget {
  final Function(String) onAvatarSelected;
  final String? initialAvatar;

  const AvatarSelector({
    super.key,
    required this.onAvatarSelected,
    this.initialAvatar,
  });

  @override
  State<AvatarSelector> createState() => _AvatarSelectorState();
}

class _AvatarSelectorState extends State<AvatarSelector> {
  String? _selectedSeed;
  final List<String> _avatarSeeds = [];

  @override
  void initState() {
    super.initState();
    _selectedSeed = widget.initialAvatar;
    _generateRandomSeeds();
  }

  void _generateRandomSeeds() {
    final random = Random();
    _avatarSeeds.clear();

    // Generate 12 random avatar seeds
    for (int i = 0; i < 12; i++) {
      final seed =
          'avatar_${random.nextInt(100000)}_${DateTime.now().millisecondsSinceEpoch}_$i';
      _avatarSeeds.add(seed);
    }

    // Set first as default if no initial avatar
    if (_selectedSeed == null && _avatarSeeds.isNotEmpty) {
      _selectedSeed = _avatarSeeds[0];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onAvatarSelected(_avatarSeeds[0]);
        }
      });
    }
  }

  void _regenerateAvatars() {
    HapticFeedback.mediumImpact();
    setState(() {
      _generateRandomSeeds();
      if (_selectedSeed != null && !_avatarSeeds.contains(_selectedSeed!)) {
        _selectedSeed = _avatarSeeds[0];
        widget.onAvatarSelected(_avatarSeeds[0]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preview section
        Center(
          child: Column(
            children: [
              Text(
                'Your Avatar',
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Large preview
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.backgroundDark,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: _selectedSeed != null
                        ? AvatarPlus(_selectedSeed!, width: 134, height: 134)
                        : Container(
                            color: AppColors.surfaceSecondaryDark,
                            child: const Icon(
                              Icons.person,
                              size: 60,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // Regenerate button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Choose Your Avatar',
              style: TextStyle(
                fontSize: AppFontSize.md,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            ScaleOnTap(
              onTap: _regenerateAvatars,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryDark,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  border: Border.all(
                    color: AppColors.borderDark.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Regenerate',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: AppFontSize.sm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Avatar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemCount: _avatarSeeds.length,
          itemBuilder: (context, index) {
            final seed = _avatarSeeds[index];
            final isSelected = _selectedSeed == seed;

            return ScaleOnTap(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedSeed = seed);
                widget.onAvatarSelected(seed);
              },
              child: AnimatedContainer(
                duration: AppDurations.fast,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.borderDark.withValues(alpha: 0.3),
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: ClipOval(child: AvatarPlus(seed, fit: BoxFit.cover)),
              ),
            );
          },
        ),
      ],
    );
  }
}
