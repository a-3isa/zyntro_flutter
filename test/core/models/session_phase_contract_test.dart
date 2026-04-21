import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';

void main() {
  test('session supports a setup phase before going live', () {
    final session = Session(
      id: 'session-1',
      type: 'gym',
      title: 'Gym Setup',
      hostId: 'host-1',
      participants: const ['host-1'],
      status: SessionStatus.active,
      phase: SessionPhase.setup,
      participantTypes: const {'host-1': 'gym'},
      createdAt: DateTime(2026),
      startedAt: DateTime(2026),
    );

    expect(session.phase, SessionPhase.setup);
    expect(session.derivedMode, SessionMode.turnBased);
    expect(SessionPhase.fromString('setup'), SessionPhase.setup);
    expect(SessionPhase.fromString('unexpected'), SessionPhase.live);
  });
}
