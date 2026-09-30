# Code quality — Result + Riverpod.select

**Status:** Accepted (incremental)  
**Date:** 2026-09-17  
**Related:** Z-CODE-001

## Decision

Adopt Result and narrow Riverpod watches incrementally — not a big-bang rewrite.

1. **`Result<S, F>`** (`lib/core/common/result.dart`) is required for new domain
   use-cases and preferred for service methods that previously threw for expected
   failures. Example: `FollowService.tryFollowUser`.
2. **`authCurrentUserIdProvider`** uses `authSessionProvider.select` so widgets that
   only need the uid avoid rebuilds on unrelated AsyncValue churn.
3. **Analyzer:** keep `flutter_lints`; enable `unawaited_futures` as a soft gate.
   Full `riverpod_lint` / custom_lint land in a dedicated PR (dev-dep + CI noise).

## Non-goals (this slice)

- Converting all 264 catch sites to Result
- Mandating `.select` on every provider watch
- Enabling riverpod_lint project-wide

## Verification

- Contract: `test/contracts/code_quality_091_test.dart`
- Call sites: feed / social / session room watch `authCurrentUserIdProvider`
