import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Community guidelines page with app rules.
class CommunityGuidelinesPage extends StatelessWidget {
  const CommunityGuidelinesPage({super.key});

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
                  'Community Guidelines',
                  style: GoogleFonts.syne(
                    fontSize: 20,
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
                    'Welcome to Zyntro',
                    style: TextStyle(
                      fontSize: AppFontSize.xxl,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Our community is built on mutual respect, encouragement, and a shared passion for fitness. These guidelines help ensure everyone has a positive experience.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: AppFontSize.md,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  _buildSection(
                    '🤝 Be Respectful',
                    'Treat everyone with kindness and respect. We\'re all on our own fitness journeys, and constructive support goes a long way.',
                  ),
                  _buildSection(
                    '💪 Encourage Others',
                    'Celebrate wins, big and small. A simple "great job" can make someone\'s day. We\'re here to lift each other up.',
                  ),
                  _buildSection(
                    '🚫 No Harassment',
                    'Harassment, bullying, hate speech, or discrimination of any kind will not be tolerated. This includes comments about body type, fitness level, or personal characteristics.',
                  ),
                  _buildSection(
                    '📵 No Spam',
                    'Avoid excessive self-promotion, spam, or repetitive content. Keep the focus on genuine fitness engagement.',
                  ),
                  _buildSection(
                    '🖼️ Appropriate Content',
                    'Only share content that is appropriate for all audiences. Explicit, violent, or illegal content is strictly prohibited.',
                  ),
                  _buildSection(
                    '🔒 Respect Privacy',
                    'Don\'t share personal information about others without their consent. Respect everyone\'s privacy and boundaries.',
                  ),
                  _buildSection(
                    '⚠️ Report Violations',
                    'If you see something that violates these guidelines, please report it. We rely on our community to help keep Zyntro safe.',
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.primaryMuted,
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Consequences',
                          style: TextStyle(
                            fontSize: AppFontSize.lg,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Violations of these guidelines may result in:',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildBulletPoint('Content removal'),
                        _buildBulletPoint('Warning notification'),
                        _buildBulletPoint('Temporary suspension (1-7 days)'),
                        _buildBulletPoint('Permanent account ban'),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Last updated: December 2024',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: AppFontSize.sm,
                    ),
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
              fontSize: AppFontSize.lg,
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

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }
}
