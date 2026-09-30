# Supported platforms

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-PLAT-001, Z-REPO-001

## Decision

Zyntro ships as a **mobile-only** product:

| Platform | Product support | CI | Store |
| --- | --- | --- | --- |
| Android | Yes | Yes (GitHub Actions / Codemagic) | Google Play |
| iOS | Yes | Yes (Codemagic) | App Store |
| Web | No | No | — |
| Linux | No | No | — |
| macOS | No | No | — |
| Windows | No | No | — |

`linux/` and `macos/` remain in the tree only as Flutter desktop scaffolding. They are **not** product surfaces: no desktop QA, no desktop release, and no claim of desktop support in store listings or marketing.

## Consequences

1. Do not add desktop CI jobs or treat desktop build failures as release blockers.
2. Do not review or ship churn from Flutter-generated desktop plugin registrants.
   Those files are gitignored and regenerated locally if someone runs a desktop target.
3. Agent / contributor PRs that only touch `linux/` or `macos/` generated registrants
   should be declined unless they are explicitly expanding the support matrix.
4. Expanding support to a desktop platform requires a new ADR, CI jobs, and store/product sign-off.

## Verification

- This document is the support matrix referenced by audits.
- Contract test asserts Android + iOS are listed as supported and Linux/macOS as unsupported.
