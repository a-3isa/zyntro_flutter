import '../../../../core/constants/constants.dart';
import '../../../../core/models/models.dart';
import 'session_set_column.dart';

/// Builds one participant set column for the progress row (Z-ARCH-002).
SessionSetColumn buildSessionSetColumn({
  required String userId,
  required String? currentUid,
  required String exerciseName,
  required int plannedSets,
  required List<TimelineEvent> events,
  required Session session,
  required bool isActiveFromProgress,
  required String? displayName,
}) {
  final isSelf = userId == currentUid;
  final isBot = userId == pairedBotFriendId;
  final name = isSelf
      ? 'You'
      : isBot
      ? 'Bot'
      : (displayName?.split(' ').first ?? 'Buddy');
  final active = session.activeUserId == userId || isActiveFromProgress;

  final sets =
      events
          .where(
            (e) =>
                e.type == SessionEventType.setLogged &&
                e.userId == userId &&
                (e.data?['exercise'] as String?) == exerciseName,
          )
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  String rowText(int i) {
    if (i >= sets.length) return '—';
    final d = sets[i].data ?? const {};
    final w = (d['weight'] as num?)?.toStringAsFixed(0) ?? '0';
    final r = (d['reps'] as num?)?.toInt() ?? 0;
    final secs = (d['durationSeconds'] as num?)?.toInt() ?? 0;
    final t = secs >= 60
        ? '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'
        : '${secs}s';
    return '${w}kg × $r · $t';
  }

  return SessionSetColumn(
    name: name,
    active: active,
    plannedSets: plannedSets,
    loggedCount: sets.length,
    rowTexts: [for (var i = 0; i < plannedSets; i++) rowText(i)],
  );
}
