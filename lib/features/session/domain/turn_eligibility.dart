import '../../../core/models/models.dart';
import '../../../services/presence_service.dart';

/// Whether a participant can be handed the turn right now.
///
/// Two ways to be ineligible, and they are not the same thing:
///
/// * **Left** — they terminated. Permanent for this session.
/// * **Away** — their app is closed. Temporary; it reverses the moment they
///   come back.
///
/// Collapsing the two would make a partner who stepped out for a phone call
/// look permanently gone.
bool canHoldTurn({
  required String userId,
  required Session session,
  required Map<String, UserPresence> presence,
  required DateTime now,
}) {
  if (!session.participants.contains(userId)) return false;
  if (session.hasTerminated(userId)) return false;
  return PresenceService.isPresenceLive(presence[userId], now);
}

/// The participant the turn should pass to after [currentUserId], or null when
/// nobody is eligible.
///
/// Skips anyone who cannot hold the turn, so a turn-based session never stalls
/// waiting on a member whose app is closed — the remaining member simply keeps
/// going. Order follows [Session.participants] so turn rotation stays stable.
String? nextTurnHolder({
  required String currentUserId,
  required Session session,
  required Map<String, UserPresence> presence,
  required DateTime now,
}) {
  final participants = session.participants;
  if (participants.isEmpty) return null;

  final startIndex = participants.indexOf(currentUserId);
  // Walk the roster from just after the current holder, wrapping around, so the
  // turn returns to the current member only if nobody else can take it.
  for (var offset = 1; offset <= participants.length; offset++) {
    final candidate =
        participants[(startIndex + offset) % participants.length];
    if (canHoldTurn(
      userId: candidate,
      session: session,
      presence: presence,
      now: now,
    )) {
      return candidate;
    }
  }
  return null;
}

/// Whether [userId] is the only participant still able to act.
///
/// Drives the solo view: the member keeps logging sets at their own pace rather
/// than being shown a waiting screen for a partner who is not there.
bool isEffectivelySolo({
  required String userId,
  required Session session,
  required Map<String, UserPresence> presence,
  required DateTime now,
}) {
  return !session.participants.any(
    (participant) =>
        participant != userId &&
        canHoldTurn(
          userId: participant,
          session: session,
          presence: presence,
          now: now,
        ),
  );
}

/// Smooths the shared ↔ solo transition so a flaky connection does not make the
/// session room oscillate.
///
/// Deliberately asymmetric: going **solo** waits out a grace period, coming
/// back to **shared** is immediate. Being slow to notice a partner left costs
/// nothing — the member carries on either way. Being slow to notice they came
/// back means logging sets as though they were alone while they are standing
/// right there.
class SoloModeDamper {
  /// How long a partner must stay unreachable before the view drops to solo.
  ///
  /// On top of the presence timeout, not instead of it — so a partner has to be
  /// gone for `presenceTimeout + graceBeforeSolo` before anything changes.
  static const graceBeforeSolo = Duration(seconds: 30);

  bool _isSolo = false;
  DateTime? _unreachableSince;

  bool get isSolo => _isSolo;

  /// Feeds the current raw reading in and returns the damped answer.
  ///
  /// [rawSolo] is `isEffectivelySolo` evaluated against live presence.
  bool update({required bool rawSolo, required DateTime now}) {
    if (!rawSolo) {
      // They are back. No grace period on the way in.
      _unreachableSince = null;
      _isSolo = false;
      return _isSolo;
    }

    _unreachableSince ??= now;
    if (now.difference(_unreachableSince!) >= graceBeforeSolo) {
      _isSolo = true;
    }
    return _isSolo;
  }

  /// When the view would next change if nothing else happens, so a caller can
  /// schedule a re-evaluation rather than polling.
  Duration? get timeUntilSolo {
    if (_isSolo || _unreachableSince == null) return null;
    return graceBeforeSolo;
  }
}

/// How a partner should be rendered.
enum ParticipantStanding {
  /// Present and able to take a turn.
  active,

  /// App closed. Temporary — reverses when they return.
  away,

  /// Terminated. Permanent for this session.
  left,
}

/// Classifies [userId] for display.
///
/// [ParticipantStanding.away] and [ParticipantStanding.left] must render
/// differently: one is someone who stepped out, the other is someone who is not
/// coming back.
ParticipantStanding standingOf({
  required String userId,
  required Session session,
  required Map<String, UserPresence> presence,
  required DateTime now,
}) {
  if (session.hasTerminated(userId)) return ParticipantStanding.left;
  if (PresenceService.isPresenceLive(presence[userId], now)) {
    return ParticipantStanding.active;
  }
  return ParticipantStanding.away;
}
