import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/app_route_locations.dart';
import '../../../auth/auth_providers.dart';
import '../../../../app/navigation/app_router.dart';
import '../../../../services/session_analytics_service.dart';
import '../../../../services/session_service.dart';
import '../../domain/resume_decision.dart';
import 'resume_session_prompt.dart';

/// Surfaces the two resume outcomes that are **not** navigations.
///
/// A warm session redirects in the router, before the first frame. The other
/// two outcomes have to wait until the member has landed somewhere:
///
/// * a **quiet** session asks whether to continue or discard;
/// * an **expired** one explains what happened to it.
///
/// Both are shown once per app launch. The decision is latched at cold start,
/// so this never re-fires on a rebuild.
///
/// Renders nothing itself — wrap it around the landing screen.
class ResumeDecisionSurface extends ConsumerStatefulWidget {
  final Widget child;

  const ResumeDecisionSurface({super.key, required this.child});

  @override
  ConsumerState<ResumeDecisionSurface> createState() =>
      _ResumeDecisionSurfaceState();
}

class _ResumeDecisionSurfaceState extends ConsumerState<ResumeDecisionSurface> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ResumeDecision>>(resumeDecisionProvider, (_, next) {
      final decision = next.value;
      if (decision == null || _handled) return;
      _handled = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _surface(decision),
      );
    });

    return widget.child;
  }

  Future<void> _surface(ResumeDecision decision) async {
    if (!mounted) return;

    switch (decision) {
      case ResumePrompt(:final sessionId, :final workoutType):
        await _askAboutQuietSession(sessionId, workoutType);
      case ResumeExpiredNotice(:final sessionId):
        _explainExpiry(sessionId);
      case ResumeRedirect():
      case ResumeNone():
        // Redirect is the router's job; none means there is nothing to say.
        break;
    }
  }

  Future<void> _askAboutQuietSession(
    String sessionId,
    String workoutType,
  ) async {
    final analytics = ref.read(sessionAnalyticsServiceProvider);
    unawaitedTrack(
      analytics.trackResumeEvent(
        ResumeSessionAnalyticsEvent.promptShown,
        sessionId: sessionId,
      ),
    );

    final choice = await ResumeSessionPrompt.show(context);

    // Dismissed without answering. The session is left exactly as it was — a
    // member who walked away from the sheet has not asked for it to end.
    if (choice == null) return;

    unawaitedTrack(
      analytics.trackResumeEvent(
        ResumeSessionAnalyticsEvent.promptAnswered,
        sessionId: sessionId,
        extra: {'choice': choice.name},
      ),
    );

    switch (choice) {
      case ResumePromptChoice.resume:
        if (!mounted) return;
        context.push(
          AppRouteLocations.sessionRoom(sessionId, type: workoutType),
        );
      case ResumePromptChoice.discard:
        final userId = ref.read(authSessionProvider).value?.id;
        if (userId == null) return;
        // Ends this member's part only — a partner still in the session keeps
        // training.
        await ref
            .read(sessionServiceProvider)
            .terminateForMember(sessionId, userId);
    }
  }

  void _explainExpiry(String sessionId) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('session_ended_notice'),
        content: const Text(
          'Your last workout ended because it was left inactive. '
          'Everything you logged has been saved.',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

/// Telemetry must never delay or break what it is measuring.
void unawaitedTrack(Future<void> future) {
  future.ignore();
}
