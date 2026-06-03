import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';

/// Terms of service page.
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
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
              color: AppColors.surfaceV2,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2Elevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textV2Primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Terms of Service',
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                  ),
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
                    'Terms of Service',
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
                    '1. Acceptance of Terms',
                    'By accessing and using Zyntro ("the App"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.',
                  ),
                  _buildSection(
                    '2. Description of Service',
                    'Zyntro is a fitness app that allows users to track workouts, connect with workout buddies, and share fitness achievements. The App is provided "as is" and we reserve the right to modify or discontinue the service at any time.',
                  ),
                  _buildSection(
                    '3. User Accounts',
                    'You are responsible for maintaining the confidentiality of your account credentials. You agree to provide accurate information and to update it as necessary. You are responsible for all activities that occur under your account.',
                  ),
                  _buildSection(
                    '4. User Conduct',
                    'You agree not to use the App for any unlawful purpose or in any way that violates these Terms. This includes but is not limited to: harassment, spam, sharing of inappropriate content, and violation of others\' privacy or intellectual property rights.',
                  ),
                  _buildSection(
                    '5. Content',
                    'You retain ownership of content you create and share on Zyntro. By posting content, you grant us a non-exclusive, royalty-free license to use, display, and distribute your content within the App.',
                  ),
                  _buildSection(
                    '6. Privacy',
                    'Your use of the App is also governed by our Privacy Policy. Please review our Privacy Policy to understand how we collect, use, and protect your information.',
                  ),
                  _buildSection(
                    '7. Health Disclaimer',
                    'The App provides fitness tracking features but is not a substitute for professional medical advice. Always consult with a healthcare provider before starting any exercise program. You use the App at your own risk.',
                  ),
                  _buildSection(
                    '8. Termination',
                    'We reserve the right to terminate or suspend your account at any time for violations of these Terms or for any other reason at our sole discretion.',
                  ),
                  _buildSection(
                    '9. Limitation of Liability',
                    'To the maximum extent permitted by law, Zyntro shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the App.',
                  ),
                  _buildSection(
                    '10. Changes to Terms',
                    'We may update these Terms from time to time. Continued use of the App after changes constitutes acceptance of the new Terms.',
                  ),
                  _buildSection(
                    '11. Contact',
                    'If you have questions about these Terms, please contact us at support@zyntro.app.',
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
