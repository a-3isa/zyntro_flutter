# Theme tokens & leave protection

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-UI-002

## Decision

1. New UI must use `AppColors` / `AppTheme` tokens — avoid raw `Colors.*` and hex
   literals outside `app_theme.dart`.
2. Live session room uses `PopScope(canPop: false)` so system back confirms via the
   existing end-session dialog instead of silently leaving a partner mid-workout.
3. Onboarding length / friction reductions are product-scoped follow-ups — do not
   rewrite onboarding in audit-closure stacks.

## Verification

- Session room source contains `PopScope` + `Z-UI-002`.
- Theme contract tests continue to own palette invariants.
