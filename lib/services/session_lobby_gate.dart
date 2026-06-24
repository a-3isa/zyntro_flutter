/// Pure decision helpers for the paired-session setup → live gate.
/// Extracted so the go-live rule is unit-testable without Firestore mocking.
library;

/// Host plus any invited users, de-duplicated, host first.
List<String> requiredRoster({
  required String hostId,
  required List<String> invitedUserIds,
}) {
  final roster = <String>[hostId];
  for (final id in invitedUserIds) {
    if (id.isNotEmpty && !roster.contains(id)) roster.add(id);
  }
  return roster;
}

/// True only when every required member has joined, EVERY current participant
/// is ready, and the invite (if any) is neither pending nor declined.
///
/// Two distinct conditions, because the partner can arrive two ways:
///  - friend-invite: the partner is named in `invitedUserIds` (the roster) and
///    must have JOINED before go-live (host cannot start alone).
///  - matchmaking: the partner is added via joinSession and is NOT in the
///    roster — so readiness must be checked over ALL `participants`, not just
///    the roster, or a matchmaking session would go live with only the host
///    ready.
bool shouldGoLive({
  required List<String> requiredRoster,
  required List<String> participants,
  required Map<String, bool> planReadiness,
  required String? invitationStatus,
}) {
  if (invitationStatus == 'pending' || invitationStatus == 'declined') {
    return false;
  }
  if (participants.isEmpty) return false;
  // (1) every invited/required member must have joined.
  for (final member in requiredRoster) {
    if (!participants.contains(member)) return false;
  }
  // (2) every current participant must be ready.
  for (final participant in participants) {
    if (planReadiness[participant] != true) return false;
  }
  return true;
}
