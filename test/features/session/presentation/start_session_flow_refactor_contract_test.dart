import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('start-session creation flow is split into focused helpers', () {
    final source = File(
      'lib/features/session/presentation/start_session_page.dart',
    ).readAsStringSync();

    expect(source, contains('Future<bool> _resolveActiveSessionConflict'));
    expect(source, contains('List<PlannedExercise> _currentPlannedExercises'));
    expect(source, contains('GymSessionPlan _buildHostGymPlan'));
    expect(source, contains('Future<String> _createSelectedSession'));
    expect(source, contains('Future<void> _saveGymPlanBestEffort'));
    expect(source, contains('void _openCreatedSession'));

    expect('Active Session Found'.allMatches(source), hasLength(1));
    expect('GymSessionPlan('.allMatches(source), hasLength(1));
  });
}
