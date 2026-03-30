# Data Model: Core Flows Clean Architecture Migration (Auth Slice)

**Feature**: `001-clean-architecture-migration`  
**Date**: 2026-03-09

## Entity: MigrationSlice

Represents one governed migration slice for a feature scope.

| Field | Type | Required | Rules |
|-------|------|----------|-------|
| sliceId | String (ID) | Yes | Unique, immutable |
| featureName | String | Yes | Must be `auth` for this slice |
| scopeDescription | String | Yes | Describes in-scope journeys |
| outOfScopeFlows | List<String> | Yes | Must include non-auth flow groups deferred to follow-on slices |
| state | Enum | Yes | One of: `NOT_STARTED`, `IN_PROGRESS`, `VALIDATION_COMPLETE`, `CUTOVER_COMPLETE`, `LEGACY_REMOVED` |
| noDowntimeRequired | Boolean | Yes | Must be `true` |
| rollbackPlanRef | String | Yes | Non-empty reference to tested rollback path |
| securityEvidenceRequired | Boolean | Yes | Must be `true` |
| observabilityBaselineRequired | Boolean | Yes | Must be `true` |
| createdAt | Timestamp | Yes | Immutable creation time |
| updatedAt | Timestamp | Yes | Updated on each mutation |

## Entity: LayerContract

Defines approved responsibilities between adjacent architectural layers.

| Field | Type | Required | Rules |
|-------|------|----------|-------|
| contractId | String (ID) | Yes | Unique |
| sliceId | String (FK) | Yes | Must reference an existing `MigrationSlice` |
| layerBoundary | Enum | Yes | One of: `PRESENTATION_DOMAIN`, `DOMAIN_DATA`, `DATA_DATASOURCE` |
| inboundExpectations | List<String> | Yes | No implementation-only terms |
| outboundGuarantees | List<String> | Yes | Must be testable statements |
| approved | Boolean | Yes | Must be `true` before `VALIDATION_COMPLETE` |

## Entity: ValidationReport

Captures mandatory evidence for progression and cutover.

| Field | Type | Required | Rules |
|-------|------|----------|-------|
| reportId | String (ID) | Yes | Unique |
| sliceId | String (FK) | Yes | Must reference `MigrationSlice` |
| reportType | Enum | Yes | One of: `REGRESSION`, `SECURITY`, `CUTOVER_READINESS`, `POST_CUTOVER` |
| passRatePercent | Number | Yes | 0-100 |
| criticalOpenDefects | Integer | Yes | Must be `0` for `SECURITY` and `CUTOVER_READINESS` acceptance |
| evidenceRefs | List<String> | Yes | Must include at least one evidence reference |
| executedAt | Timestamp | Yes | Required |
| approvedBy | String | Yes | Non-empty reviewer identifier |

## Entity: DomainFailureCategory

Canonical failure classification for user-facing error consistency.

| Field | Type | Required | Rules |
|-------|------|----------|-------|
| failureCode | String | Yes | Unique canonical code |
| categoryName | String | Yes | Stable canonical term |
| userMessage | String | Yes | Must be user-facing and actionable |
| severity | Enum | Yes | One of: `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` |
| rollbackTrigger | Boolean | Yes | `true` if this failure can trigger rollback criteria |

## Entity: TelemetryBaseline

Defines operational signals required before cutover.

| Field | Type | Required | Rules |
|-------|------|----------|-------|
| baselineId | String (ID) | Yes | Unique |
| sliceId | String (FK) | Yes | Must reference `MigrationSlice` |
| successRateMetricName | String | Yes | Non-empty |
| errorRateMetricName | String | Yes | Non-empty |
| rollbackAlertCondition | String | Yes | Non-empty, testable alert expression |
| alertChannels | List<String> | Yes | At least one channel |
| active | Boolean | Yes | Must be `true` before cutover |

## Entity: RollbackEvent

Represents rollback activation triggered by severe regression.

| Field | Type | Required | Rules |
|-------|------|----------|-------|
| rollbackEventId | String (ID) | Yes | Unique |
| sliceId | String (FK) | Yes | Must reference `MigrationSlice` |
| triggerFailureCode | String (FK) | Yes | Must map to `DomainFailureCategory.failureCode` |
| triggeredAt | Timestamp | Yes | Required |
| actionSummary | String | Yes | Required summary of rollback actions |
| resolvedAt | Timestamp | No | Present when rollback incident is closed |

## Entity: MigrationBacklogItem

Tracks deferred non-auth scope as follow-on work.

| Field | Type | Required | Rules |
|-------|------|----------|-------|
| backlogItemId | String (ID) | Yes | Unique |
| sourceSliceId | String (FK) | Yes | Must reference auth `MigrationSlice` |
| targetFeatureName | String | Yes | Must not be `auth` for deferred entries |
| description | String | Yes | Non-empty |
| priority | Enum | Yes | One of: `P1`, `P2`, `P3` |
| status | Enum | Yes | One of: `OPEN`, `SCHEDULED`, `DONE` |

## Relationships

- `MigrationSlice` 1->N `LayerContract`
- `MigrationSlice` 1->N `ValidationReport`
- `MigrationSlice` 1->1 `TelemetryBaseline`
- `MigrationSlice` 1->N `RollbackEvent`
- `MigrationSlice` 1->N `MigrationBacklogItem`
- `DomainFailureCategory` 1->N `RollbackEvent`

## Lifecycle and State Transitions

`MigrationSlice.state` forward transitions:

1. `NOT_STARTED` -> `IN_PROGRESS`
2. `IN_PROGRESS` -> `VALIDATION_COMPLETE`
3. `VALIDATION_COMPLETE` -> `CUTOVER_COMPLETE`
4. `CUTOVER_COMPLETE` -> `LEGACY_REMOVED`

Transition constraints:

- No state skipping is permitted.
- `IN_PROGRESS` -> `VALIDATION_COMPLETE` requires at least one passing `REGRESSION` and one passing `SECURITY` validation report.
- `VALIDATION_COMPLETE` -> `CUTOVER_COMPLETE` requires an active `TelemetryBaseline` and confirmed rollback readiness.
- `CUTOVER_COMPLETE` -> `LEGACY_REMOVED` requires zero unresolved critical defects and post-cutover verification evidence.
- Rollback activation is represented by `RollbackEvent` and does not redefine lifecycle order; any additional remediation is tracked as follow-on work.
