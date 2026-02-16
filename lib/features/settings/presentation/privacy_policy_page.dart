import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/premium_effects.dart';

/// Privacy policy page.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
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
                  text: 'Privacy Policy',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  colors: [AppColors.textDark, AppColors.textSecondaryDark],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: AppFontSize.xxl,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Effective Date: December 2024',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: AppFontSize.sm,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  _buildSection(
                    '1. Information We Collect',
                    'We collect information you provide directly, including:\n'
                        '• Account information (email, display name, profile photo)\n'
                        '• Workout data and fitness activity\n'
                        '• Content you share (posts, comments, photos)\n'
                        '• Communications with other users',
                  ),
                  _buildSection(
                    '2. How We Use Your Information',
                    'We use your information to:\n'
                        '• Provide and improve the App\n'
                        '• Connect you with workout buddies\n'
                        '• Track and display your fitness progress\n'
                        '• Send relevant notifications\n'
                        '• Ensure safety and security',
                  ),
                  _buildSection(
                    '3. Information Sharing',
                    'We share your information:\n'
                        '• With other users as part of the App\'s social features\n'
                        '• With service providers who assist in operating the App\n'
                        '• When required by law or to protect rights and safety\n'
                        '• We do not sell your personal information',
                  ),
                  _buildSection(
                    '4. Data Security',
                    'We implement appropriate security measures to protect your information. However, no method of transmission over the Internet is 100% secure, and we cannot guarantee absolute security.',
                  ),
                  _buildSection(
                    '5. Your Privacy Controls',
                    'You can control your privacy by:\n'
                        '• Setting your account to private\n'
                        '• Managing who can see your activity\n'
                        '• Blocking users you don\'t want to interact with\n'
                        '• Deleting your account and associated data',
                  ),
                  _buildSection(
                    '6. Data Retention',
                    'We retain your information as long as your account is active or as needed to provide services. You can request deletion of your data by contacting us.',
                  ),
                  _buildSection(
                    '7. Children\'s Privacy',
                    'The App is not intended for children under 13. We do not knowingly collect information from children under 13. If we learn we have collected such information, we will delete it.',
                  ),
                  _buildSection(
                    '8. Third-Party Services',
                    'The App may contain links to third-party services. We are not responsible for the privacy practices of these services. We encourage you to review their privacy policies.',
                  ),
                  _buildSection(
                    '9. Changes to This Policy',
                    'We may update this Privacy Policy from time to time. We will notify you of significant changes through the App or by email.',
                  ),
                  _buildSection(
                    '10. Contact Us',
                    'If you have questions about this Privacy Policy, please contact us at privacy@zyntro.app.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: AppFontSize.md,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
