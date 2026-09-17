import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/zyntro_back_button.dart';

/// Renders a canonical markdown legal doc from [assetPath] (Z-PRV-003).
///
/// Docs under `docs/*.md` are the single source of truth and are also listed
/// in `pubspec.yaml` assets so in-app legal screens cannot drift.
class LegalMarkdownPage extends StatelessWidget {
  const LegalMarkdownPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: Column(
        children: [
          Container(
            padding: AppSpacing.headerPadding(context),
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                const ZyntroBackButton(),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<String>(
              future: rootBundle.loadString(assetPath),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Unable to load $title.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SelectableText(
                    snapshot.data!,
                    style: TextStyle(
                      color: AppColors.textV2Primary.withValues(alpha: 0.9),
                      fontSize: AppFontSize.md,
                      height: 1.5,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
