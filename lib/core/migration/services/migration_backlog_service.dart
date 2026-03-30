import '../models/migration_backlog_item.dart';
import '../models/migration_lifecycle.dart';
import 'migration_governance_repository.dart';

class MigrationBacklogService {
  final MigrationGovernanceRepository _repository;

  const MigrationBacklogService(this._repository);

  Future<MigrationBacklogItem> createDeferredItem({
    required String sourceSliceId,
    required String targetFeatureName,
    required String description,
    BacklogPriority priority = BacklogPriority.p2,
  }) async {
    if (targetFeatureName.trim().toLowerCase() == 'auth') {
      throw ArgumentError(
        'Deferred backlog item must target a non-auth feature.',
      );
    }

    if (description.trim().isEmpty) {
      throw ArgumentError('Deferred backlog item description is required.');
    }

    return _repository.createBacklogItem(
      sourceSliceId: sourceSliceId,
      targetFeatureName: targetFeatureName.trim(),
      description: description.trim(),
      priority: priority,
    );
  }

  Future<List<MigrationBacklogItem>> listOpenItems() async {
    final allItems = await _repository.listBacklogItems();
    return allItems
        .where((item) => item.status != BacklogStatus.done)
        .toList(growable: false);
  }

  Future<MigrationBacklogItem> markScheduled(String backlogItemId) {
    return _repository.updateBacklogItemStatus(
      backlogItemId: backlogItemId,
      status: BacklogStatus.scheduled,
    );
  }

  Future<MigrationBacklogItem> markDone(String backlogItemId) {
    return _repository.updateBacklogItemStatus(
      backlogItemId: backlogItemId,
      status: BacklogStatus.done,
    );
  }
}
