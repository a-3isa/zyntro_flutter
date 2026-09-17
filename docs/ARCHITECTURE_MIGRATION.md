# Clean-architecture migration posture

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-ARCH-001

## Decision

The full 9-feature clean-architecture migration is **paused**, not abandoned.

| Feature | Layered (`domain` / `data` / `presentation`) | Status |
| --- | --- | --- |
| `auth` | Yes | Reference implementation — keep enforcing |
| `session`, `feed`, `social`, `profile`, `settings`, `moderation`, `main`, others | Partial / presentation-heavy | **Do not block PRs** on `validate_feature_layers.ps1` until revived |

## Rationale

Finishing a wholesale rewrite of god-file features (session/profile/social) while closing Critical/High product risks is slower and riskier than shipping targeted extractions. Auth remains the template; new code in other features should prefer thin services + presentation without requiring a full domain/data package split on every change.

## Consequences

1. `scripts/validate_feature_layers.ps1` is **advisory** — not a required CI gate.
2. Prefer extracting pure helpers / widgets from god files (see Z-ARCH-002 / Z-PERF-001) over greenfield feature folders.
3. Reviving the campaign requires a new ADR with a sequenced feature order and CI enforcement date.
4. Do not delete `auth` layered packages; they stay the golden path for new auth work.

## Verification

- Contract test asserts this ADR exists and names auth as the only enforced layered feature.
