# Zyntro Improvement Roadmap — 2026-09-17

Companion to `2026-09-17-full-audit.md` and `2026-09-17-full-audit-findings.json`.  
**Grade D · Play/App Store: Not ready.** Fix P0 Criticals before feature work.

RICE fields: reach (users/mo estimate or eng-impact proxy) · impact (0.25–3) · confidence · effortWeeks · score = reach×impact×confidence÷effortWeeks.

---

## Now (0–2 weeks) — release blockers & quick wins

| Priority | IDs | Area | Effort | Notes |
|---|---|---|---|---|
| P0 | **Z-SEC-001**, Z-ENH-044 | backend / rules | M | Align `users` list with profile ACL or public projection; emulator deny |
| P0 | **Z-DATA-001**, Z-ENH-033 | backend | L start | Deny client score writes; stub CF grant; hide leaderboard until live |
| P0 | **Z-RT-001**, Z-DATA-002, Z-ENH-045 | client | S | Unify `derivedMode`; delete session `mode` writes |
| P0 | **Z-IOS-001** | native | S | Release entitlements `production`; keep Debug `development` |
| P0 | Z-REPO-004 (T054), Z-REPO-006 | process | S | Device quickstart; park/clean dirty WT before any merge |
| P0 | Z-REPO-007 | ops | XS | Owner verify expiry function + indexes deployed |
| P1 | Z-AND-001, Z-AND-002 | Android | S | FCM default icon; `res/xml` network/data-extraction |
| P1 | Z-SOC-002 | client | XS | GoRouter moderation guard |
| P1 | Z-NOTIF-001, Z-NOTIF-002 | client/CF | M | Buddy CF types; preference fail-closed |
| P1 | Z-CI-001, Z-CI-004 | CI | S | Single Flutter pin; gate rules deploy |
| P1 | Z-DOC-001, Z-REPO-002 | repo | XS–S | Fix CLAUDE/AGENTS; remove worktree gitlinks |
| P1 | Z-AUTH-001 | auth | S | Uniform email enumeration responses |
| P1 | Z-ENH-017, Z-ENH-042 | product/ops | XS–S | In-app review; forced-update Remote Config |

**Quick wins (<1 day):** derivedMode fix · iOS production APS · Android notif icon · moderation route guard · CI pin · CLAUDE/AGENTS · gitlinks · rules-deploy `needs` · notif preference fail-closed · in-app review.

---

## Next (2–6 weeks) — High integrity, privacy, quality foundation

| Theme | IDs | Slice | Effort |
|---|---|---|---|
| Server scores + streak authority | Z-DATA-001, Z-ENH-033 | `008-server-scores` | L |
| Account deletion + export | Z-FN-003, Z-PRV-002, Z-ENH-034 | `008-deletion-export` | L |
| Push hardening | Z-FN-001/002, Z-ENH-035 | `008-trigger-push` | L |
| Privacy manifests & legal single-source | Z-IOS-003, Z-PRV-001/003 | `008-privacy-inventory` | M |
| Matchmaking + turn integrity | Z-SEC-003, Z-RT-002/003 | `008-match-turn-integrity` | M |
| Auth deep links + verify gate | Z-AUTH-002/007 | `008-auth-gates-deeplinks` | M |
| UGC server filter (EN+AR baseline) | Z-SOC-001, Z-ENH-026 start | `008-moderation-ai` (phase 1 rules) | L |
| Payments decision | Z-PAY-001/002, Z-ENH-021 | `008-iap-entitlements` | L |
| Offline queue scoping | Z-OFF-001/002, Z-DATA-003 | `008-offline-isolation` | M |
| Coverage + functions + storage tests | Z-TEST-001…004, Z-ENH-037 | `008-unified-ci` | M–L |
| iOS Podfile + deploy target + Facebook hide/fix | Z-IOS-002/004/005 | `008-ios-release-hygiene` | M |
| Session perf (rebuild/listeners) | Z-PERF-001/002, Z-ENH-030 start | `008-split-session-room` (phase 1) | L |
| A11y session + text scale | Z-A11Y-002/003, Z-UI-001, Z-ENH-027 | `008-a11y-session` | M |
| SC-002 evidence | Z-REPO-005 | amend or `resume_timing_test` | M |

---

## Later (6–12+ weeks) — architecture & growth (RICE-ranked)

| Rank | ID | Title | Category | RICE score | Slice |
|---:|---|---|---|---:|---|
| 1 | Z-ENH-044 | Users list privacy + public search index | 8.9 | ~19000 | `008-users-list-privacy` |
| 2 | Z-ENH-033 | Server-authoritative scores/streaks | 8.9 | ~9000 | `008-server-scores` |
| 3 | Z-ENH-045 | Unify derivedMode / delete mode | 8.1 | ~45600 | `008-mode-derivation` |
| 4 | Z-ENH-042 | Forced-update + incident banner | 8.11 | ~24000 | `008-forced-update` |
| 5 | Z-ENH-017 | In-app review after 3rd buddy session | 8.3 | ~36000 | `008-in-app-review` |
| 6 | Z-ENH-007 | PR celebration overlay | 8.1 | ~19200 | `008-pr-celebration` |
| 7 | Z-ENH-001 | Auto rest timer + partner visibility | 8.1 | ~8533 | `008-rest-timer` |
| 8 | Z-ENH-012 | Invite App/Universal Links | 8.2 | ~7000 | `008-invite-links` |
| 9 | Z-ENH-014 | Streak freeze + XP | 8.3 | ~6300 | `008-streak-xp` |
| 10 | Z-ENH-015 | Weekly recap push | 8.3 | ~6300 | `008-weekly-recap` |
| 11 | Z-ENH-018 | Onboarding lite + bot trial | 8.4 | ~7000 | `008-onboarding-lite` |
| 12 | Z-ENH-021 | RevenueCat / platform IAP | 8.5 | ~3200 | `008-iap-entitlements` |
| 13 | Z-ENH-034 | Deletion + export complete | 8.9 | ~10800 | `008-deletion-export` |
| 14 | Z-ENH-035 | Trigger-based notifications | 8.9 | ~4667 | `008-trigger-push` |
| 15 | Z-ENH-028 | Arabic parity + RTL goldens | 8.7 | ~3000 | `008-ar-parity` |
| 16 | Z-ENH-002 | Wakelock + Live Activity | 8.1 | ~7000 | `008-session-presence-chrome` |
| 17 | Z-ENH-013 | Shareable recap cards | 8.2 | ~9600 | `008-recap-share` |
| 18 | Z-ENH-041 | Perf traces + dashboards | 8.11 | ~8000 | `008-obs-dashboards` |
| 19 | Z-ENH-043 | Remote Config kill switches | 8.11 | ~10667 | `008-remote-kills` |
| 20 | Z-ENH-010 | Scheduled sessions + nudge | 8.2 | ~4900 | `008-scheduled-sessions` |
| 21 | Z-ENH-005 | Exercise demo media | 8.1 | ~4725 | `008-exercise-media` |
| 22 | Z-ENH-011 | Ghost/async races | 8.2 | ~3000 | `008-ghost-sessions` |
| 23 | Z-ENH-027 | Accessible reps + transcripts | 8.7 | ~2400 | `008-a11y-session` |
| 24 | Z-ENH-037 | Unified CI + Dependabot | 8.10 | ~27 | `008-unified-ci` |
| 25 | Z-ENH-030 | Split session_room | 8.8 | ~9 | `008-split-session-room` |
| 26 | Z-ENH-004 | Templates + overload | 8.1 | ~2800 | `008-templates-overload` |
| 27 | Z-ENH-003 | Units / plate / RPE | 8.1 | ~4200 | `008-units-rpe` |
| 28 | Z-ENH-020 | Arabic ASO + landing | 8.4 | ~4667 | `008-aso-ar` |
| 29 | Z-ENH-022 | Duo paywall experiments | 8.5 | ~2400 | `008-duo-paywall` |
| 30 | Z-ENH-026 | Moderation AI + translation | 8.6 | ~2333 | `008-moderation-ai` |
| 31 | Z-ENH-016 | Home widgets | 8.3 | ~2250 | `008-home-widgets` |
| 32 | Z-ENH-029 | High-contrast theme | 8.7 | ~3200 | `008-high-contrast` |
| 33 | Z-ENH-038 | Golden matrix | 8.10 | ~16 | `008-goldens` |
| 34 | Z-ENH-039 | Flavors + seeded emulator | 8.10 | ~8.8 | `008-flavors-emulator` |
| 35 | Z-ENH-036 | Functions TS + tests | 8.9 | ~5.3 | `008-functions-ts` |
| 36 | Z-ENH-032 | Codegen + riverpod_lint | 8.8 | ~16 | `008-codegen-lints` |
| 37 | Z-ENH-031 | Arch finish-or-retire | 8.8 | ~5.3 | `008-arch-decision` |
| 38 | Z-ENH-006 | Health Connect / HealthKit | 8.1 | ~1667 | `008-health-import` |
| 39 | Z-ENH-019 | Referrals | 8.4 | ~2667 | `008-referrals` |
| 40 | Z-ENH-023 | AI plan generation | 8.6 | ~750 | `008-ai-plans` |
| 41 | Z-ENH-024 | AI recap tips | 8.6 | ~2250 | `008-ai-recap` |
| 42 | Z-ENH-025 | NL/voice set logging | 8.6 | ~800 | `008-voice-logging` |
| 43 | Z-ENH-008 | Group sessions >2 | 8.2 | ~800 | `008-group-sessions` |
| 44 | Z-ENH-009 | Spectator/cheer | 8.2 | ~1000 | `008-spectator` |
| 45 | Z-ENH-040 | PR template / CODEOWNERS / ADRs | 8.10 | ~27 | `008-process-docs` |

Full enhancement objects (member/business value, risks, constitution fit) are sketched below for the top slices; remaining IDs follow the same pattern in JSON.

---

## Proposed Spec Kit slices (`008-…`)

Each slice: prioritized stories · evidence gate · kill switch · rollback.

### `008-mode-derivation` (Now)
- **Stories:** Same-type cardio → parallel UI; gym+gym → turn-based; no persisted `sessions.mode`.
- **Evidence:** Unit matrix + paired cardio device check; grep gate no mode writes.
- **Kill:** N/A (bugfix) · **Rollback:** revert commit.

### `008-users-list-privacy` (Now)
- **Stories:** Private profiles never appear in unfiltered list/query; username search via public index.
- **Evidence:** Emulator private-list deny; search UX still works.
- **Kill:** feature flag search → empty · **Rollback:** rules revert + redeploy.

### `008-server-scores` (Next)
- **Stories:** Client cannot write score/streak; CF grants once per completed session; leaderboard trusted.
- **Evidence:** Rules deny + function idempotency test; staging cheat attempt fails.
- **Kill:** `config/featureFlags.serverScoresEnabled` · **Rollback:** flag off + temporary hide leaderboard.

### `008-deletion-export` (Next)
- **Stories:** Delete removes sessions/workouts/Storage/joint slots; user can export JSON/zip.
- **Evidence:** Staging delete checklist empty; export download.
- **Kill:** export flag · **Rollback:** disable callable; document retention.

### `008-iap-entitlements` (Next)
- **Stories:** Digital goods via Play Billing/StoreKit (e.g. RevenueCat); webhook sets entitlement; delete mock Stripe grant.
- **Evidence:** Sandbox purchase → Admin field; client grant removed.
- **Kill:** Remote Config paywall off · **Rollback:** entitlement revoke script.

### `008-trigger-push` (Next)
- **Stories:** Invites/turns via Firestore triggers; client cannot spam HTTPS push; rate limits.
- **Evidence:** Emulator trigger test; load test burst rejected.
- **Kill:** `pushViaTriggers` flag with legacy HTTPS fallback limited · **Rollback:** flag.

### `008-ar-parity` (Later)
- **Stories:** Core J1–J7 strings in ARB ar; RTL goldens; localized pushes.
- **Evidence:** Parity % gate; golden CI.
- **Kill:** locale forced en · **Rollback:** ARB revert.

### `008-split-session-room` (Later)
- **Stories:** session_room split by phase; rebuild budget met.
- **Evidence:** Line budgets + widget tests; DevTools frame time.
- **Kill:** N/A · **Rollback:** revert splits.

### `008-unified-ci` (Next/Later)
- **Stories:** One pin; rules+functions+coverage required; Dependabot.
- **Evidence:** PR cannot merge red gates.
- **Kill:** N/A · **Rollback:** workflow revert.

### `008-arch-decision` (Later)
- **Stories:** ADR: finish clean-arch for session+feed **or** retire blueprint and archive migration.
- **Evidence:** layers script policy in CI **or** ADR + deleted runtime migration imports.
- **Kill:** N/A · **Rollback:** ADR amendment.

*(Additional slices for remaining Z-ENH-001…043 listed in JSON `slice` field.)*

---

## Seed ideas (§8) — adopt / adapt / reject

| Seed | Decision | Reason |
|---|---|---|
| Rest timer | **Adopt** | Z-ENH-001; partners already live |
| Wakelock / Live Activity | **Adopt** | Z-ENH-002; RT-006 |
| kg/lb, RPE, supersets | **Adapt** | Units/RPE first (ENH-003); supersets later |
| Templates / overload | **Adopt** | ENH-004 after server scores |
| Exercise demo media | **Adopt** | ENH-005 |
| Hands-free / motion reps | **Reject (now)** | Integrity + a11y debt first; revisit as ENH-025 |
| Health import | **Adapt** | ENH-006 after privacy inventory |
| Group >2 | **Defer** | ENH-008 after mode fix |
| Spectator / voice realtime | **Defer** | ENH-009 |
| Scheduled / ghost / challenges | **Adopt phased** | ENH-010/011 |
| Invite links | **Adopt** | ENH-012; Dynamic Links gone |
| Recap share cards | **Adopt** | ENH-013 |
| Streak freeze / widgets / review | **Adopt** | ENH-014/016/017 |
| Onboarding lite / referral / ASO | **Adopt** | ENH-018–020 |
| RevenueCat Duo | **Adopt** | ENH-021/022; reject Stripe digital |
| AI features | **Adapt** | Server-only, opt-in, capped (ENH-023–026) after App Check depth |
| A11y / AR parity / contrast | **Adopt** | ENH-027–029 |
| God-file split / arch / codegen | **Adopt** | ENH-030–032 |
| Backend scores/delete/push/TS | **Adopt** | ENH-033–036 |
| Unified CI / goldens / flavors / process | **Adopt** | ENH-037–040 |
| Obs traces / forced update / kills | **Adopt** | ENH-041–043 |

---

## Stop doing / delete

1. **Client writes** to `workoutScore` / streaks / PR integrity fields (move server).  
2. **Persisting `sessions.mode`** — derive only.  
3. **Mock Stripe PaymentIntent + `grantGlobalLeaderboardAccess`** client path.  
4. **Client inbox writes** for buddy notification types.  
5. **Shipping Facebook Login** on iOS without plist + Meta deletion URL (hide or finish).  
6. **Tracking unsupported `linux/`/`macos/`** as product surfaces without CI.  
7. **Committed `.claude/worktrees` gitlinks** (160000).  
8. **Asserting `allow list: if isAuthenticated()`** on `users` in contract tests as “correct.”  
9. **Dual conflicting Flutter pins** (document one).  
10. **Deploying Firestore rules** without emulator job.  
11. **Dead `pushQueue`/`pushTokens` rules** — remove or document external consumer.  
12. **Runtime `lib/core/migration/**`** once cutover decided — archive.  
13. **Client catalog seed UI** in release builds (Admin/Functions only).  
14. **Format-rewriting the whole tree** as a drive-by during feature PRs — dedicated hygiene PR only.  
15. **Treating dirty WT as mergeable “current”** for 007.

---

## Metrics to track

| Metric | Why |
|---|---|
| Crash-free sessions % | Release quality |
| Session completion rate | Core loop |
| Invite acceptance rate | Buddy funnel |
| Resume success rate (007) | FR/SC health |
| p95 time-to-live-room | Join latency |
| Firestore cost / DAU | DATA-006 / listeners |
| Test coverage (global + session/auth/feed) | Quality floors |
| Analyzer issues | Keep at 0 |
| Arabic string parity % | I18N-001 |
| A11y guideline pass rate | A11Y campaign |
| Push delivery success / opt-out rate | NOTIF health |
| Rules+functions CI green on main | Safe backend |

---

## Constitution fit (summary)

All `008-*` slices should include: prioritized user stories, **evidence gate** (test or device artifact), **kill switch** where behavior is risky, and **rollback** (flag or revert). Do not merge 007 until T054 + SC-002 policy + deploy verification clear (`Z-REPO-004/005/007`).

---

*45 enhancements in JSON. Re-score RICE after first production metrics land.*
