# Clean Architecture Feature Workflow

> **Paused for non-auth features.** See [`ARCHITECTURE_MIGRATION.md`](./ARCHITECTURE_MIGRATION.md) (Z-ARCH-001).
> Auth remains the layered reference; this workflow applies when a feature migration is explicitly revived.

This workflow standardizes how new feature slices are planned and delivered after the auth migration slice.

## 1. Scope the Migration Slice

1. Define a single feature slice and list explicit out-of-scope flows.
2. Confirm the slice can be delivered independently without requiring unrelated feature rewrites.
3. Register the slice lifecycle state as `NOT_STARTED`.

## 2. Create Layer Blueprint

Each feature proposal must declare:

- `presentation` layer responsibilities
- `domain` layer responsibilities
- `data` layer responsibilities
- layer boundary contracts:
  - `PRESENTATION_DOMAIN`
  - `DOMAIN_DATA`

Validate this structure with:

```powershell
powershell -ExecutionPolicy Bypass -File D:/zyntro_flutter/scripts/validate_feature_layers.ps1 -FeatureName <feature>
```

## 3. Implement with Migration Guardrails

1. Preserve user-facing behavior parity during migration.
2. Keep legacy and migrated paths available until cutover requirements are satisfied.
3. Capture regression and security evidence before transitioning to `VALIDATION_COMPLETE`.
4. Enable telemetry baseline and rollback trigger alerts before `CUTOVER_COMPLETE`.

## 4. Cutover Evidence Checklist

Before cutover:

1. Regression validation report is passing.
2. Security regression report has no unresolved critical defects.
3. Cutover readiness report is approved.
4. Telemetry baseline is active with rollback alerts.
5. Rollback path has been tested.

## 5. Post-Cutover Controls

1. Monitor critical regressions for 5 business days.
2. Record unresolved critical counts daily in post-cutover SLA tracking.
3. Transition to `LEGACY_REMOVED` only when post-cutover evidence is complete.

## 6. Follow-On Backlog Rule

If migration uncovers out-of-scope requirements:

1. Create a `MigrationBacklogItem`.
2. Assign `P1`, `P2`, or `P3` priority.
3. Keep the current slice scoped; do not implement non-slice work inside the active auth migration deliverable.
