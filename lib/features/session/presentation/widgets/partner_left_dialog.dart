import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Tells a member their partner has left, and lets them decide what that means
/// for their own workout.
///
/// The decision is theirs alone. Terminating is per-member, so a partner
/// walking out must never end this member's session for them — it only offers
/// the option.
///
/// Dismissing is equivalent to carrying on: it hides the interruption, never
/// the fact. The partner's avatar keeps rendering in its "left" state
/// afterwards, so the information survives the dialog being closed.
class PartnerLeftDialog extends StatelessWidget {
  final String partnerName;

  /// End this member's part too.
  final VoidCallback onFinishToo;

  /// Keep training alone.
  final VoidCallback onCarryOn;

  const PartnerLeftDialog({
    super.key,
    required this.partnerName,
    required this.onFinishToo,
    required this.onCarryOn,
  });

  /// Shows the dialog and reports the choice.
  ///
  /// Returns [PartnerLeftChoice.carryOn] when dismissed without choosing —
  /// dismissal must never be read as "end my session".
  static Future<PartnerLeftChoice> show(
    BuildContext context, {
    required String partnerName,
  }) async {
    final choice = await showDialog<PartnerLeftChoice>(
      context: context,
      builder: (dialogContext) => PartnerLeftDialog(
        partnerName: partnerName,
        onFinishToo: () =>
            Navigator.of(dialogContext).pop(PartnerLeftChoice.finishToo),
        onCarryOn: () =>
            Navigator.of(dialogContext).pop(PartnerLeftChoice.carryOn),
      ),
    );
    return choice ?? PartnerLeftChoice.carryOn;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '$partnerName left the session',
        key: const Key('partner_left_title'),
      ),
      content: Text(
        'You can keep going on your own, or finish here. '
        'Everything you have logged is saved either way.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textV2Secondary,
        ),
      ),
      actions: [
        TextButton(
          key: const Key('partner_left_finish_too'),
          onPressed: onFinishToo,
          child: const Text('Finish too'),
        ),
        FilledButton(
          key: const Key('partner_left_carry_on'),
          onPressed: onCarryOn,
          child: const Text('Keep going'),
        ),
      ],
    );
  }
}

/// What the remaining member chose after their partner left.
enum PartnerLeftChoice {
  /// End their own part as well.
  finishToo,

  /// Keep training alone. Also what dismissal means.
  carryOn,
}

/// Remembers which departures have already been announced.
///
/// The session document is streamed, so `endedParticipants` re-emits on every
/// snapshot — without this the dialog would re-raise on every rebuild, and
/// again every time the member reopened the session. Keyed on the leaver so two
/// partners leaving separately each get their own announcement.
///
/// Deliberately in-memory and per-screen: once the member has been told, the
/// avatar's "left" state carries the information from then on.
class AnnouncedDepartures {
  final Set<String> _announced = {};

  /// Returns the leavers in [endedParticipants] not yet announced, and marks
  /// them announced.
  List<String> takeUnannounced(Iterable<String> endedParticipants) {
    final fresh =
        endedParticipants.where((id) => !_announced.contains(id)).toList();
    _announced.addAll(fresh);
    return fresh;
  }

  /// Marks departures as already known without announcing them.
  ///
  /// Used when a member opens a session where a partner had already left: the
  /// avatar shows it, so a dialog about something that happened while they were
  /// away would be noise.
  void markSeen(Iterable<String> endedParticipants) {
    _announced.addAll(endedParticipants);
  }

  bool hasAnnounced(String userId) => _announced.contains(userId);
}
