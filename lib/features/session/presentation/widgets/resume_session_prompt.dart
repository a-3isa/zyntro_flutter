import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Asks whether to go back into a session that has gone quiet.
///
/// A session with recent work, or a partner still in the room, redirects
/// straight in — no prompt. This is for the other case: nobody has touched it
/// for a while and the room is empty, but it has not expired yet. Dropping
/// someone into a workout that has been idle for an hour reads as being dragged
/// somewhere rather than being helped, so we ask.
///
/// Deliberately dismissible in every direction. A member who ignores it is not
/// blocked from anything, and the session is left exactly as it was.
class ResumeSessionPrompt extends StatelessWidget {
  /// Go back into the session.
  final VoidCallback onContinue;

  /// End this member's own part in it. Never their partner's.
  final VoidCallback onDiscard;

  /// Neither — leave the session untouched and get on with something else.
  final VoidCallback onDismiss;

  const ResumeSessionPrompt({
    super.key,
    required this.onContinue,
    required this.onDiscard,
    required this.onDismiss,
  });

  /// Shows the prompt as a bottom sheet.
  ///
  /// Returns the choice made, or null if the member dismissed it without
  /// choosing — which is not a decision and must leave the session alone.
  static Future<ResumePromptChoice?> show(BuildContext context) {
    return showModalBottomSheet<ResumePromptChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ResumeSessionPrompt(
        onContinue: () =>
            Navigator.of(sheetContext).pop(ResumePromptChoice.resume),
        onDiscard: () =>
            Navigator.of(sheetContext).pop(ResumePromptChoice.discard),
        onDismiss: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You left a workout running',
              key: const Key('resume_prompt_title'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing has been logged for a while. Pick up where you left off, '
              'or finish it here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textV2Secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('resume_prompt_continue'),
              onPressed: onContinue,
              child: const Text('Continue workout'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('resume_prompt_discard'),
              onPressed: onDiscard,
              child: const Text('Finish it'),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const Key('resume_prompt_dismiss'),
              onPressed: onDismiss,
              child: Text(
                'Not now',
                style: TextStyle(color: AppColors.textV2Secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the member chose.
enum ResumePromptChoice {
  /// Go back in.
  resume,

  /// End their own part in it. Under the per-member rule, a partner still in
  /// the session is unaffected.
  discard,
}
