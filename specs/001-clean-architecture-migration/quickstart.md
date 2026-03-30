# Quickstart: Auth Clean Architecture Migration Slice

**Feature**: `001-clean-architecture-migration`  
**Plan**: [plan.md](D:/zyntro_flutter/specs/001-clean-architecture-migration/plan.md)  
**Spec**: [spec.md](D:/zyntro_flutter/specs/001-clean-architecture-migration/spec.md)

## 1. Prerequisites

- Flutter SDK and Dart SDK installed.
- Access to Firebase environments used by this project.
- Ability to run `dart analyze` and `flutter test`.
- Branch checked out: `001-clean-architecture-migration`.

## 2. Review Planning Artifacts

1. Read `D:/zyntro_flutter/specs/001-clean-architecture-migration/research.md`.
2. Review data entities and state transitions in `D:/zyntro_flutter/specs/001-clean-architecture-migration/data-model.md`.
3. Review migration governance contract in:
   `D:/zyntro_flutter/specs/001-clean-architecture-migration/contracts/auth-migration-governance.openapi.yaml`.

## 3. Implement Auth Slice Changes

1. Keep scope to auth-related flows only.
2. Ensure layer boundaries remain explicit:
   - Presentation uses use cases/contracts only.
   - Domain contains business rules and failure categories.
   - Data layer handles external persistence and data mapping.
3. Keep legacy path available until validation and cutover criteria are complete.

## 4. Execute Validation Evidence

Run from `D:/zyntro_flutter`:

```powershell
dart analyze lib
flutter test test/features/auth
flutter test test/services
```

Record evidence for:

- Regression test outcomes (target >=95% pass for defined auth journeys).
- Security regression checks (no unresolved critical security defects).
- Telemetry and alert readiness for rollback triggers.
- No planned downtime cutover readiness and tested rollback path.

## 5. Auth Slice Cutover Checklist (Updated)

- [ ] Migration slice state moved to `IN_PROGRESS`
- [ ] Regression report attached (`REGRESSION`, pass rate >= 95%)
- [ ] Security report attached (`SECURITY`, critical open defects = 0)
- [ ] Cutover readiness report attached (`CUTOVER_READINESS`, approved)
- [ ] Telemetry baseline active with rollback alerts configured
- [ ] Rollback path tested and reference recorded
- [ ] Cutover request approved with no planned downtime
- [ ] Post-cutover report attached (`POST_CUTOVER`)
- [ ] No unresolved critical defects after 5 business days
- [ ] State moved to `LEGACY_REMOVED`

## 6. Lifecycle Progression Checklist

Move the migration slice through:

1. `NOT_STARTED` -> `IN_PROGRESS`
2. `IN_PROGRESS` -> `VALIDATION_COMPLETE` after regression/security evidence is complete
3. `VALIDATION_COMPLETE` -> `CUTOVER_COMPLETE` after telemetry and rollback readiness are confirmed
4. `CUTOVER_COMPLETE` -> `LEGACY_REMOVED` after post-cutover verification

Do not skip lifecycle states.

## 7. Cutover and Rollback Expectations

- Execute auth cutover with zero planned downtime.
- If severe regressions occur, trigger rollback immediately and capture rollback event evidence.
- Track any deferred non-auth work as follow-on backlog items.

## 8. Validation Execution Log (2026-03-11)

Executed commands and outcomes:

1. `dart analyze lib/core/migration lib/features/auth/auth_providers.dart lib/features/auth/presentation/providers/auth_controller.dart lib/features/auth/presentation/login_page.dart lib/features/auth/presentation/signup_page.dart lib/features/auth/presentation/forgot_password_page.dart lib/features/auth/presentation/widgets/auth_error_surface.dart lib/app/navigation/app_router.dart test/core/migration test/features/auth/presentation/auth_error_surface_test.dart integration_test/auth_migration_flow_test.dart integration_test/auth_security_regression_test.dart`  
   Result: PASS (no analyzer issues).
2. `flutter test test/core/migration`  
   Result: PASS (25 tests passed).
3. `flutter test test/features/auth/presentation/auth_error_surface_test.dart`  
   Result: PASS (2 tests passed).
4. `flutter test test/features/auth/domain/authentication_usecase_test.dart test/features/auth/data/auth_repository_impl_test.dart`  
   Result: PASS (12 tests passed).
5. `flutter test integration_test/auth_migration_flow_test.dart integration_test/auth_security_regression_test.dart`  
   Result: BLOCKED in this environment (`No supported devices connected`), requires connected Android/iOS test device.
6. `powershell -ExecutionPolicy Bypass -File D:/zyntro_flutter/scripts/validate_feature_layers.ps1 -FeaturePath D:/zyntro_flutter/lib/features -FeatureName auth`  
   Result: PASS (`auth` contains `presentation`, `domain`, and `data` layers).

## 9. Completion Criteria

This slice is complete when:

- Auth migration reaches `LEGACY_REMOVED`.
- Security, regression, and operational evidence is recorded.
- No unresolved critical defects remain.
- Follow-on non-auth migration backlog is documented.
