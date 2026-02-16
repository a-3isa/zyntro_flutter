import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Daily quote widget matching React Native DailyQuote component.
class DailyQuote extends StatelessWidget {
  const DailyQuote({super.key});

  // Sample quotes - in a real app, these would come from a service
  static const List<Map<String, String>> _quotes = [
    {
      'quote': 'The only bad workout is the one that didn\'t happen.',
      'author': 'Unknown',
    },
    {
      'quote': 'Success is what comes after you stop making excuses.',
      'author': 'Luis Galarza',
    },
    {
      'quote':
          'Your body can stand almost anything. It\'s your mind that you have to convince.',
      'author': 'Unknown',
    },
    {
      'quote':
          'The pain you feel today will be the strength you feel tomorrow.',
      'author': 'Arnold Schwarzenegger',
    },
    {
      'quote':
          'Fitness is not about being better than someone else. It\'s about being better than you used to be.',
      'author': 'Khloe Kardashian',
    },
  ];

  Map<String, String> _getTodaysQuote() {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year))
        .inDays;
    return _quotes[dayOfYear % _quotes.length];
  }

  @override
  Widget build(BuildContext context) {
    final quote = _getTodaysQuote();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💪', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Daily Motivation',
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '"${quote['quote']}"',
            style: const TextStyle(
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '— ${quote['author']}',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
