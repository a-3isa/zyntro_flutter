# CI ownership (source of truth)

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-CI-002

## Decision

| Concern | Owner | Config |
| --- | --- | --- |
| Required quality gates (analyze, unit/widget tests, coverage floor, Cloud Functions tests, Firestore/Storage rules tests) | **GitHub Actions** | `.github/workflows/flutter-ci.yml` |
| Signed store artifacts (Play / App Store) + store publishing | **Codemagic** | `codemagic.yaml` |
| Flutter SDK pin for gates | **GitHub Actions** (`3.44.4`) | Must stay in sync with Codemagic `environment.flutter` |

Codemagic may still run `flutter analyze` / `flutter test` before signing, but those runs are **not** the merge gate. PR / main quality is owned by GitHub Actions. Do not add new gate types only to Codemagic.

## Required GitHub Action checks

Document these as the required status checks for `main` (enable in repo branch protection when Actions history is available):

1. `analyze`
2. `functions-test`
3. `rules-test`

Release jobs (`build-android`, `build-ios`, `deploy-firebase-rules`) are post-gate and may be path/branch filtered.

## Drift rules

1. Changing the Flutter pin requires updating **both** `flutter-ci.yml` and `codemagic.yaml` in the same PR.
2. Changing coverage floor, rules, or functions test commands requires updating **GitHub Actions** first; Codemagic should not invent divergent gate scripts.
3. Signing secrets and store credentials live only in Codemagic / GitHub secrets — never in the repo.

## Verification

- Contract test asserts this ownership split and the shared Flutter pin.
