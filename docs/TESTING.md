# Testing policy

**Status:** Accepted (incremental)  
**Date:** 2026-09-17  
**Related:** Z-TEST-005

## Contract tests (allowed)

Source/string contracts under `test/**` are intentional **audit locks**, not brittle
UI snapshots. Keep them when they assert:

| Category | Example | Keep when… |
| --- | --- | --- |
| Rules / security | `firestore_rules_contract_test` | Asserts deny/allow markers or rule helpers |
| Privacy / CI ownership | `docs/*_contract_test` | Locks ADR decisions |
| Extract / architecture | `*_extract_contract_test` | Prevents god-file regressions |
| Service API shape | `*_service_contract_test` | Locks public method / flag presence |

**Triage rule:** Prefer `contains('stableToken')` over line-number or full-file hashes.
Delete contracts that only duplicate a widget test.

## Goldens

No golden suite yet. First golden candidates (follow-up PR):

1. Brand chrome / splash mark
2. Session room empty/waiting phase (fixed size, no network)

Until then, a11y guideline smoke + theme palette contracts cover visual regression risk
at the token layer.

## Integration tests

| Suite | Path | Gate |
| --- | --- | --- |
| Unit / widget | `test/` | **Required** on every PR (`flutter test`) |
| Integration smoke | `integration_test/smoke_test.dart` | **Manual / workflow_dispatch** — needs device or emulator |
| Auth / Firebase connection | other `integration_test/*` | Device + real/emulator Firebase — not PR-gated |

Do not add Firebase-backed integration suites to the default PR job without an
emulator harness and secrets strategy.

## Verification

- This doc + contract `test/docs/testing_policy_contract_test.dart`
- CI workflow documents the integration job as `workflow_dispatch`-only
