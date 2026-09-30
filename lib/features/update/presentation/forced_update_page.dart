import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';

/// Full-screen gate when [minSupportedVersion] exceeds the installed build.
class ForcedUpdatePage extends StatelessWidget {
  const ForcedUpdatePage({super.key});

  static final _androidStore = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.zyntro.app',
  );
  static final _iosStore = Uri.parse(
    'https://apps.apple.com/us/app/zyntro/id0000000000',
  );

  Future<void> _openStore(BuildContext context) async {
    final uri = Theme.of(context).platform == TargetPlatform.iOS
        ? _iosStore
        : _androidStore;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the store')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                size: 72,
                color: AppColors.signal,
              ),
              const SizedBox(height: 24),
              Text(
                'Update required',
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textV2Primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This version of Zyntro is no longer supported. Please update to continue.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textV2Secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _openStore(context),
                  child: const Text('Update now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
