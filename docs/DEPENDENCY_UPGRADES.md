# Dependency upgrade posture

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-DEP-003, Z-DEP-001, Z-DEP-002

## Decision

1. **Do not** mass-upgrade Dart package majors in audit-closure PRs. Upgrade when a
   feature needs an API, when `flutter pub outdated` shows security advisories, or on a
   scheduled quarterly dependency PR.
2. Prefer **minor/patch** bumps inside the existing Flutter pin (`docs/CI.md`).
3. Known hotspots to review on the next dependency PR:
   - `go_router`, `riverpod` / `flutter_riverpod`
   - Firebase plugin majors (keep versions aligned)
   - `image_picker` / `record` / media stack
   - Niche packages with low maintainer activity — replace rather than deep-pin
4. **Dynamic Links** and other deprecated Firebase products: do not reintroduce; use
   existing deep-link / invite-code paths.
5. Functions: keep Node 22; bump `firebase-admin` / `firebase-functions` when Firebase
   release notes require it (see `docs/PLATFORM_DEADLINES.md`).

## Process

1. Run `flutter pub outdated` and `npm outdated` in `functions/`.
2. Open one PR per major family with tests green.
3. Update this doc if a package is removed or replaced.

## Verification

- Contract test asserts this runbook exists and names the Flutter pin + Node 22.
