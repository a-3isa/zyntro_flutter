# Platform & dependency deadlines

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-DEP-001, Z-DEP-002, Z-IOS-005, Z-CI-001

## Purpose

Track store/SDK cutovers so releases are not blocked by missed target bumps.

## Calendar (review quarterly)

| Item | Current posture | Watch / action |
| --- | --- | --- |
| Android `targetSdk` / Play policy | Follow Flutter / AGP defaults in `android/` | Bump before Play rejection windows; verify after Flutter upgrades |
| iOS deployment target | Raised for plugin floors (see Podfile / Xcode project) | Keep ≥ plugin minimums; re-check after `pod update` |
| CocoaPods / Xcode | Podfile committed; CI Mac builds | Align local & Codemagic Xcode versions |
| Flutter pin | See `docs/CI.md` (GHA + Codemagic) | Keep pins equal; avoid silent drift |
| Node Functions runtime | Node 22 | Stay on supported Firebase Functions runtime |
| `firebase-admin` / `qs` | Keep majors current; `npm audit` clean of known moderate+ | Z-DEP-002 — upgrade in Functions PRs when advisories land |
| Privacy Manifest / ATT | `PrivacyInfo.xcprivacy` present | Re-audit when adding SDKs that collect data |

## Process

1. Before each store submit: skim this table and `docs/CI.md`.
2. After Flutter upgrades: re-run Android/iOS release builds and note targetSdk / iOS
   deployment target in the PR.
3. After Functions dependency bumps: run `npm test` / contract suite and deploy a canary
   function if risk is non-trivial.

## Verification

- This runbook exists and is linked from audit closure notes for Z-DEP-001.
- CI Flutter pin documented in `docs/CI.md`.
