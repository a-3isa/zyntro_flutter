import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/migration/migration.dart';

void main() {
  late MigrationGovernanceRepository repository;
  late MigrationBacklogService service;

  setUp(() {
    const guard = MigrationTransitionGuard();
    const policy = MigrationEvidencePolicy();
    const stateMachine = MigrationStateMachine(guard);
    const evidenceService = ValidationEvidenceService(policy);

    repository = MigrationGovernanceRepository(
      stateMachine: stateMachine,
      validationEvidenceService: evidenceService,
    );
    service = MigrationBacklogService(repository);
  });

  test('creates deferred non-auth backlog item', () async {
    final item = await service.createDeferredItem(
      sourceSliceId: 'auth',
      targetFeatureName: 'feed',
      description: 'Migrate feed domain/service layer',
      priority: BacklogPriority.p1,
    );

    expect(item.targetFeatureName, 'feed');
    expect(item.status, BacklogStatus.open);
  });

  test('rejects auth as deferred feature target', () async {
    expect(
      () => service.createDeferredItem(
        sourceSliceId: 'auth',
        targetFeatureName: 'auth',
        description: 'This should fail',
      ),
      throwsArgumentError,
    );
  });

  test('updates deferred item status to scheduled and done', () async {
    final item = await service.createDeferredItem(
      sourceSliceId: 'auth',
      targetFeatureName: 'notifications',
      description: 'Migrate notification workflows',
    );

    final scheduled = await service.markScheduled(item.backlogItemId);
    expect(scheduled.status, BacklogStatus.scheduled);

    final done = await service.markDone(item.backlogItemId);
    expect(done.status, BacklogStatus.done);
  });
}
