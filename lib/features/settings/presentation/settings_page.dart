import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../app/navigation/app_router.dart';
import '../../../widgets/mvp_feature_wrapper.dart';
import '../../../widgets/premium_effects.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/circuit_breaker_status_widget.dart';
import '../../auth/presentation/providers/auth_controller.dart';

/// Settings page with app preferences and account options.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                BounceAnimation(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const GradientText(
                  text: 'Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  colors: [AppColors.textDark, AppColors.textSecondaryDark],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account section
                  SlideInAnimation.fromBottom(
                    index: 0,
                    child: _buildSection(
                      context: context,
                      title: 'Account',
                      icon: Icons.person_outline,
                      children: [
                        _buildSettingsTile(
                          context,
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          index: 0,
                          onTap: () => context.push(AppRoutes.editProfile),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.lock_outline,
                          title: 'Privacy',
                          index: 1,
                          onTap: () => context.push(AppRoutes.privacySettings),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.block_outlined,
                          title: 'Blocked Users',
                          index: 2,
                          onTap: () => context.push(AppRoutes.blockedUsers),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.notifications_outlined,
                          title: 'Notification Preferences',
                          index: 3,
                          onTap: () =>
                              context.push(AppRoutes.notificationPreferences),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Account Management section
                  SlideInAnimation.fromBottom(
                    index: 1,
                    child: _buildSection(
                      context: context,
                      title: 'Account Management',
                      icon: Icons.manage_accounts_outlined,
                      children: [
                        _buildSettingsTile(
                          context,
                          icon: Icons.key_outlined,
                          title: 'Change Password',
                          index: 0,
                          onTap: () => context.push(AppRoutes.changePassword),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.email_outlined,
                          title: 'Change Email',
                          index: 1,
                          onTap: () => context.push(AppRoutes.changeEmail),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.delete_outline,
                          title: 'Delete Account',
                          index: 2,
                          isDestructive: true,
                          onTap: () => context.push(AppRoutes.deleteAccount),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Security section (Coming Soon)
                  SlideInAnimation.fromBottom(
                    index: 2,
                    child: _buildSection(
                      context: context,
                      title: 'Security',
                      icon: Icons.security_outlined,
                      children: [
                        MVPFeatureWrapper(
                          feature: FeatureFlag.activeSessions,
                          featureName: 'Active Sessions',
                          description:
                              'View and manage your active login sessions.',
                          child: _buildSettingsTile(
                            context,
                            icon: Icons.devices_outlined,
                            title: 'Active Sessions',
                            index: 0,
                            onTap: () {},
                            comingSoon: true,
                          ),
                        ),
                        MVPFeatureWrapper(
                          feature: FeatureFlag.twoFactorAuth,
                          featureName: 'Two-Factor Authentication',
                          description:
                              'Add an extra layer of security to your account.',
                          child: _buildSettingsTile(
                            context,
                            icon: Icons.security_outlined,
                            title: 'Two-Factor Authentication',
                            index: 1,
                            onTap: () {},
                            comingSoon: true,
                          ),
                        ),
                        MVPFeatureWrapper(
                          feature: FeatureFlag.loginHistory,
                          featureName: 'Login History',
                          description: 'View your recent login activity.',
                          child: _buildSettingsTile(
                            context,
                            icon: Icons.history_outlined,
                            title: 'Login History',
                            index: 2,
                            onTap: () {},
                            comingSoon: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // App section
                  SlideInAnimation.fromBottom(
                    index: 3,
                    child: _buildSection(
                      context: context,
                      title: 'App',
                      icon: Icons.apps_outlined,
                      children: [
                        _buildSettingsTile(
                          context,
                          icon: Icons.network_check_outlined,
                          title: 'Network Diagnostics',
                          index: 0,
                          onTap: () => _showNetworkDiagnostics(context),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.dark_mode_outlined,
                          title: 'Appearance',
                          index: 1,
                          onTap: () {},
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.primaryGradient,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Dark',
                              style: TextStyle(
                                fontSize: AppFontSize.xs,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.gavel_outlined,
                          title: 'Community Guidelines',
                          index: 2,
                          onTap: () =>
                              context.push(AppRoutes.communityGuidelines),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.description_outlined,
                          title: 'Terms of Service',
                          index: 3,
                          onTap: () => context.push(AppRoutes.termsOfService),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          index: 4,
                          onTap: () => context.push(AppRoutes.privacyPolicy),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          index: 5,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Sign Out section
                  SlideInAnimation.fromBottom(
                    index: 4,
                    child: _buildSignOutCard(context, ref),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // App Version
                  SlideInAnimation.fromBottom(
                    index: 5,
                    child: Center(
                      child: FadeInAnimation(
                        child: Column(
                          children: [
                            const Text(
                              'Zyntro',
                              style: TextStyle(
                                color: AppColors.textSecondaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Version 1.0.0',
                              style: TextStyle(
                                color: AppColors.textTertiaryDark,
                                fontSize: AppFontSize.xs,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              GradientText(
                text: title,
                style: const TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                ),
                colors: [AppColors.textDark, AppColors.textSecondaryDark],
              ),
            ],
          ),
        ),
        // Settings container
        GlassContainer(
          blur: 10,
          backgroundColor: AppColors.surfaceSecondaryDark.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required int index,
    bool isDestructive = false,
    bool comingSoon = false,
    Widget? trailing,
  }) {
    final color = isDestructive
        ? AppColors.error
        : comingSoon
        ? AppColors.textTertiaryDark
        : AppColors.textDark;

    return SlideInAnimation.fromRight(
      index: index,
      delay: const Duration(milliseconds: 30),
      child: ScaleOnTap(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.error.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDestructive ? AppColors.error : AppColors.primary,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (comingSoon) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Soon',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing:
                trailing ??
                Icon(
                  Icons.chevron_right,
                  color: isDestructive
                      ? AppColors.error
                      : AppColors.textTertiaryDark,
                ),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutCard(BuildContext context, WidgetRef ref) {
    return GlassContainer(
        blur: 10,
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        child: BounceAnimation(
          onTap: () async {
            HapticFeedback.mediumImpact();
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => FadeInAnimation(
                child: AlertDialog(
                  backgroundColor: AppColors.surfaceDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.logout, color: AppColors.error),
                      SizedBox(width: 8),
                      Text(
                        'Sign Out',
                        style: TextStyle(color: AppColors.textDark),
                      ),
                    ],
                  ),
                  content: const Text(
                    'Are you sure you want to sign out?',
                    style: TextStyle(color: AppColors.textSecondaryDark),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    ),
                    BounceAnimation(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (confirmed == true && context.mounted) {
              HapticFeedback.heavyImpact();
              await ref.read(authControllerProvider).signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            }
          },
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, color: AppColors.error, size: 24),
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: AppFontSize.md,
              ),
            ),
            subtitle: Text(
              'Sign out of your account',
              style: TextStyle(
                color: AppColors.error.withValues(alpha: 0.7),
                fontSize: AppFontSize.sm,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.error),
          ),
        ),
    );
  }

  void _showNetworkDiagnostics(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Network Diagnostics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircuitBreakerStatusWidget(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
