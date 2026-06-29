import '../models/layer_contract.dart';
import '../models/migration_backlog_item.dart';
import '../models/migration_lifecycle.dart';
import '../models/migration_slice.dart';
import '../models/rollback_event.dart';
import '../models/telemetry_baseline.dart';
import '../models/validation_report.dart';
import 'migration_state_machine.dart';
import 'validation_evidence_service.dart';

class CutoverDecision {
  final bool accepted;
  final String message;
  final MigrationSlice? slice;

  const CutoverDecision({
    required this.accepted,
    required this.message,
    this.slice,
  });
}

class MigrationGovernanceRepository {
  static const String migrationSlicesPath = '/migration-slices';
  static const String migrationBacklogItemsPath = '/migration-backlog-items';

  static String slicePath(String sliceId) => '$migrationSlicesPath/$sliceId';
  static String statePath(String sliceId) => '${slicePath(sliceId)}/state';
  static String validationReportsPath(String sliceId) =>
      '${slicePath(sliceId)}/validation-reports';
  static String telemetryBaselinePath(String sliceId) =>
      '${slicePath(sliceId)}/telemetry-baseline';
  static String cutoverPath(String sliceId) => '${slicePath(sliceId)}/cutover';
  static String rollbackPath(String sliceId) =>
      '${slicePath(sliceId)}/rollback';

  final MigrationStateMachine _stateMachine;
  final ValidationEvidenceService _validationEvidenceService;

  final Map<String, MigrationSlice> _slices = {};
  final Map<String, List<LayerContract>> _contracts = {};
  final Map<String, List<ValidationReport>> _validationReports = {};
  final Map<String, TelemetryBaseline> _telemetryBaselines = {};
  final Map<String, List<RollbackEvent>> _rollbackEvents = {};
  final Map<String, MigrationBacklogItem> _backlogItems = {};

  MigrationGovernanceRepository({
    required this._stateMachine,
    required this._validationEvidenceService,
  });

  Future<MigrationSlice> getOrCreateAuthSlice() async {
    final existing = _slices['auth'];
    if (existing != null) return existing;

    final authSlice = MigrationSlice.authDefault();
    _slices[authSlice.sliceId] = authSlice;
    return authSlice;
  }

  Future<MigrationSlice> createMigrationSlice(MigrationSlice slice) async {
    _slices[slice.sliceId] = slice;
    return slice;
  }

  Future<MigrationSlice?> getMigrationSlice(String sliceId) async {
    return _slices[sliceId];
  }

  Future<List<MigrationSlice>> listMigrationSlices() async {
    return _slices.values.toList(growable: false);
  }

  Future<LayerContract> addLayerContract(LayerContract contract) async {
    final list = _contracts.putIfAbsent(contract.sliceId, () => []);
    list.removeWhere((item) => item.contractId == contract.contractId);
    list.add(contract);
    return contract;
  }

  Future<List<LayerContract>> getLayerContracts(String sliceId) async {
    return List.unmodifiable(_contracts[sliceId] ?? const []);
  }

  Future<ValidationReport> addValidationReport(ValidationReport report) async {
    final list = _validationReports.putIfAbsent(report.sliceId, () => []);
    list.removeWhere((item) => item.reportId == report.reportId);
    list.add(report);
    return report;
  }

  Future<List<ValidationReport>> getValidationReports(String sliceId) async {
    return List.unmodifiable(_validationReports[sliceId] ?? const []);
  }

  Future<TelemetryBaseline> upsertTelemetryBaseline(
    TelemetryBaseline baseline,
  ) async {
    _telemetryBaselines[baseline.sliceId] = baseline;
    return baseline;
  }

  Future<TelemetryBaseline?> getTelemetryBaseline(String sliceId) async {
    return _telemetryBaselines[sliceId];
  }

  Future<RollbackEvent> addRollbackEvent({
    required String sliceId,
    required String triggerFailureCode,
    required String actionSummary,
    DateTime? now,
  }) async {
    final event = RollbackEvent(
      rollbackEventId: _nextId('rb'),
      sliceId: sliceId,
      triggerFailureCode: triggerFailureCode,
      triggeredAt: (now ?? DateTime.now()).toUtc(),
      actionSummary: actionSummary,
    );
    final list = _rollbackEvents.putIfAbsent(sliceId, () => []);
    list.add(event);
    return event;
  }

  Future<List<RollbackEvent>> getRollbackEvents(String sliceId) async {
    return List.unmodifiable(_rollbackEvents[sliceId] ?? const []);
  }

  Future<bool> hasOpenRollbackEvent(String sliceId) async {
    final events = _rollbackEvents[sliceId] ?? const [];
    return events.any((event) => event.resolvedAt == null);
  }

  Future<MigrationSlice> transitionSliceState({
    required String sliceId,
    required MigrationState toState,
    required String reason,
    int unresolvedCriticalDefects = 0,
    DateTime? now,
  }) async {
    final existing =
        _slices[sliceId] ?? (sliceId == 'auth' ? await getOrCreateAuthSlice() : null);

    if (existing == null) {
      throw StateError('Migration slice not found: $sliceId');
    }

    final reports = await getValidationReports(sliceId);
    final telemetryBaseline = await getTelemetryBaseline(sliceId);
    final assessment = _validationEvidenceService.assess(
      reports: reports,
      telemetryBaselineActive: telemetryBaseline?.active ?? false,
      rollbackReadinessConfirmed: reports.any(
        (report) =>
            report.reportType == ValidationReportType.cutoverReadiness &&
            report.passes(),
      ),
      unresolvedCriticalDefects: unresolvedCriticalDefects,
    );

    final transitioned = _stateMachine.transition(
      slice: existing,
      toState: toState,
      reason: reason,
      prerequisites: assessment.toTransitionPrerequisites(),
      now: now,
    );

    _slices[sliceId] = transitioned;
    return transitioned;
  }

  Future<CutoverDecision> requestCutover({
    required String sliceId,
    required String requestedBy,
    required String changeReference,
    DateTime? now,
  }) async {
    final slice =
        _slices[sliceId] ?? (sliceId == 'auth' ? await getOrCreateAuthSlice() : null);

    if (slice == null) {
      return const CutoverDecision(
        accepted: false,
        message: 'Slice not found for cutover.',
      );
    }

    if (await hasOpenRollbackEvent(sliceId)) {
      return const CutoverDecision(
        accepted: false,
        message: 'Cutover blocked while rollback incident is active.',
      );
    }

    if (slice.state != MigrationState.validationComplete) {
      return CutoverDecision(
        accepted: false,
        message:
            'Slice must be in VALIDATION_COMPLETE before cutover. Current: ${slice.state.wireValue}.',
        slice: slice,
      );
    }

    try {
      final updatedSlice = await transitionSliceState(
        sliceId: sliceId,
        toState: MigrationState.cutoverComplete,
        reason: 'Cutover approved by $requestedBy ($changeReference)',
        now: now,
      );

      return CutoverDecision(
        accepted: true,
        message: 'Cutover accepted.',
        slice: updatedSlice,
      );
    } on StateError catch (error) {
      return CutoverDecision(
        accepted: false,
        message: error.message.toString(),
        slice: slice,
      );
    }
  }

  Future<MigrationBacklogItem> createBacklogItem({
    required String sourceSliceId,
    required String targetFeatureName,
    required String description,
    required BacklogPriority priority,
  }) async {
    final item = MigrationBacklogItem(
      backlogItemId: _nextId('backlog'),
      sourceSliceId: sourceSliceId,
      targetFeatureName: targetFeatureName,
      description: description,
      priority: priority,
      status: BacklogStatus.open,
    );

    _backlogItems[item.backlogItemId] = item;
    return item;
  }

  Future<MigrationBacklogItem> updateBacklogItemStatus({
    required String backlogItemId,
    required BacklogStatus status,
  }) async {
    final existing = _backlogItems[backlogItemId];
    if (existing == null) {
      throw StateError('Backlog item not found: $backlogItemId');
    }

    final updated = existing.copyWith(status: status);
    _backlogItems[backlogItemId] = updated;
    return updated;
  }

  Future<List<MigrationBacklogItem>> listBacklogItems() async {
    return _backlogItems.values.toList(growable: false);
  }

  Future<void> clear() async {
    _slices.clear();
    _contracts.clear();
    _validationReports.clear();
    _telemetryBaselines.clear();
    _rollbackEvents.clear();
    _backlogItems.clear();
  }

  String _nextId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-$now';
  }
}
