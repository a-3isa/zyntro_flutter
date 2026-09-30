# Zyntro Full Audit — 2026-09-17

## 0. Metadata

| Field | Value |
|---|---|
| **Run date** | 2026-09-17 |
| **Branch** | `007-resume-active-session` |
| **Commit** | `23408a7b0858e986d77e89f775e89e21a41379b4` (`23408a7`) |
| **Default remote** | `origin/001-clean-architecture-migration` @ `83902a9` |
| **Tooling** | Flutter 3.44.4 (local) / CI pin 3.38.9 · Dart 3.12.2 · Node (functions engines 22) |
| **Host** | Windows 10 — no local iOS/macOS archive |
| **Working tree** | Dirty (~98 files vs HEAD) — findings cite on-disk evidence unless marked HEAD-only |
| **Companion JSON** | `docs/audits/2026-09-17-full-audit-findings.json` |
| **Roadmap** | `docs/audits/2026-09-17-improvement-roadmap.md` |
| **Scratch** | `build/audit-work/**` (not a deliverable) |

**Limitations:** No production Firebase console access; no signed iOS IPA on this host; no live HTTPS push smoke; Deploy of `expireStaleSessions` + indexes owner-unverified; graphify `--update` failed (no LLM key) — used existing graph; §10 DoD gaps listed in §11.

---

## 1. Executive summary

**Overall grade: D** — engineering hygiene improved (analyzer **0**, **1009** Flutter tests pass, **115** rules tests), but **four Confirmed Criticals** and many High release/compliance gaps block store shipping. Branch `007` cutover is **blocked** (T054, SC-002, dirty WT, deploy NV).

| Store | Verdict | Blocking IDs |
|---|---|---|
| **Google Play production** | **Not ready** | `Z-SEC-001`, `Z-DATA-001`, `Z-PRV-001`, `Z-PRV-003`, `Z-AND-001` |
| **App Store** | **Not ready** | `Z-IOS-001`, `Z-IOS-003`, `Z-PRV-001`, `Z-AUTH-004`, `Z-I18N-001` |

**Finding counts (merged unique):** Critical **4** · High **67** · Medium **29** · Low **8** · Info **8** · **Total 116** · Enhancements **45**

### Top 10 risks

1. `Z-SEC-001` — `users` list bypasses private-profile `get` (enumeration / privacy collapse)
2. `Z-DATA-001` — client-writable `workoutScore` / streaks (leaderboard cheating)
3. `Z-RT-001` — `derivedMode` makes cardio+cardio turn-based (core UX fail)
4. `Z-IOS-001` — `aps-environment=development` (prod push broken risk)
5. `Z-FN-003` / `Z-AUTH` deletion gaps — residual PII after account delete
6. `Z-SOC-001` — client-only English UGC filter
7. `Z-PAY-001` / `Z-PAY-002` — mock Stripe + store-policy conflict if activated
8. `Z-I18N-001` — Arabic/localization largely missing
9. `Z-FN-001`/`Z-FN-002` — push spam / App Check depth
10. `Z-REPO-004`–`007` — 007 cutover gates open

### Top 10 quick wins (<1 day each)

1. Fix `Session.derivedMode` (`Z-ENH-045` / `Z-RT-001`) — XS/S  
2. Release iOS entitlements `production` (`Z-IOS-001`) — S  
3. Android FCM default notification icon (`Z-AND-001`) — S  
4. Router guard on moderation queue (`Z-SOC-002`) — XS  
5. Align CI Flutter pin with local/docs (`Z-CI-001`) — S  
6. Repair `CLAUDE.md` / `AGENTS.md` markers (`Z-DOC-001`) — XS  
7. Remove worktree gitlinks (`Z-REPO-002`) — S  
8. Gate `deploy-firebase-rules` on analyze + rules tests (`Z-CI-004`) — S  
9. Fail-closed notification preference read (`Z-NOTIF-002`) — S  
10. In-app review prompt after 3rd buddy session (`Z-ENH-017`) — XS  

### Top 5 enhancements (by RICE)

1. `Z-ENH-044` — users list privacy + public search index  
2. `Z-ENH-033` — server-authoritative scores/streaks  
3. `Z-ENH-045` — unify derivedMode / delete persisted mode  
4. `Z-ENH-042` — forced-update gate  
5. `Z-ENH-021` — platform IAP (RevenueCat)  

---

## 2. Scorecard (0–10)

Trend vs 2026-05-02 / 2026-08-03: ↑ improved · → flat · ↓ worse

| Dimension | Score | Trend | One-line rationale |
|---|---:|---|---|
| Security | 3 | → | Critical list leak + integrity counters still client-writable |
| Privacy & compliance | 3 | → | PrivacyInfo empty types; legal drift; Meta deletion URL missing |
| Data & backend integrity | 3 | ↑ | Rules suite strong; scores/mode/expiry cleanup still weak |
| Live-session reliability | 4 | ↑ | 007 resume in-tree; derivedMode Critical; turn races High |
| Auth & account lifecycle | 4 | ↑ | Apple present; deletion incomplete; email verify ungated |
| Social/UGC safety | 3 | → | Client English filter; report flood; moderation UI unguarded |
| Architecture | 3 | → | Clean-arch stalled 1/9; god files remain |
| Code quality | 6 | ↑ | Analyzer 0; format debt 157 files; Result unused |
| UX & design system | 5 | ↑ | Theme tokens dominant; Colors.* / motion gaps |
| Accessibility | 3 | ↑ | Some Semantics; 1.3× clamp; thin coverage |
| i18n/RTL | 2 | → | Login-only ARB; RTL APIs unused |
| Performance | 4 | → | Deferred init good; session rebuild/listener cost High |
| Offline & resilience | 3 | → | Prefs queue; not user-scoped; duplicates SDK queue |
| Notifications | 4 | ↑ | CF push path exists; buddy types broken; Android icon |
| Testing | 5 | ↑ | 1009 pass / 115 rules; coverage 32%; feed/functions gaps |
| CI/CD & release | 3 | → | Dual pipelines; pin skew; deploy ungated |
| Observability & ops | 3 | ↑ | Crashlytics wired unverified; no Performance/forced update |
| Dependencies & platform | 4 | ↑ | npm critical cleared; Flutter pin / deadlines High |
| Documentation & process | 3 | → | Stale agent markers; missing ADRs/runbooks |
| Repository hygiene | 3 | → | Dirty WT; gitlinks; unsupported desktop trees |

---

## 3. Baseline results

| Signal | 2026-09-17 result |
|---|---|
| `flutter analyze` | **0** issues |
| `dart format --set-exit-if-changed` | **157 / 316** would change (not applied) |
| `flutter test --coverage` | **1009** pass · **8** skip · **0** fail · **~32.11%** LH/LF |
| Rules emulator | **115** pass / 0 fail |
| Feature layers script | **1/9** pass (`auth` only) |
| Functions `node --check` | OK |
| `npm audit` functions | **0** Critical/High · **1** moderate (`qs`) |
| Flutter local vs CI | **3.44.4** vs pin **3.38.9** |

Artifacts: `build/audit-work/baseline/*`, summary `build/audit-work/baseline-summary.md`.

---

## 4. Prior-audit reconciliation

Full table: `build/audit-work/prior-reconciliation.md`. JSON `priorAudit` holds machine-readable subset.

| Status | Approx count |
|---|---:|
| Fixed & verified | 32 |
| Fixed, unverified | 18 |
| Partially fixed | 28 |
| Open | 22 |
| Withdrawn | 1 (M5) |
| Superseded | 1 (WP-R-M3) |
| Regressed | 0 |

**§3.10 leads:** 20 confirmed · 3 refuted · mapped into `Z-*` / `REC-*` (see appendix mapping).

**Still-open integrity cluster:** R14/F12/F02 → `Z-PAY-001`; F06 residual → `Z-RT-002`; F14 → `Z-AUTH-007`; F10 → flavors/`Z-CI-003`; F27 → `Z-OFF-001`.

---

## 5. Current-branch readiness (`007-resume-active-session`)

**Verdict: blocked** — see `build/audit-work/branch-readiness.md`.

| Blocker | Finding |
|---|---|
| T054 physical quickstart open | `Z-REPO-004` |
| SC-002 / missing `resume_timing_test.dart` | `Z-REPO-005` |
| Dirty WT ≠ HEAD (~98 files) | `Z-REPO-006` |
| `expireStaleSessions` + indexes deploy NV | `Z-REPO-007` |

In-repo positives: kill-switch readable / client-write deny; resume decision + rollback gate tests; telemetry event definitions; `endedParticipants` rules tests present.

---

## 6. Findings by domain (A–W)

Full templates live in scratch `build/audit-work/findings/*.md`. Below: **merged owning IDs**, severity-sorted. Duplicates collapsed (see appendix DRAFT→final map).

### A — Security / rules

| ID | Sev | Title |
|---|---|---|
| **Z-SEC-001** | Critical | `users` list bypasses private-profile get |
| Z-SEC-002 | High | workouts create forgeable `userId` |
| Z-SEC-003 | High | matchmaking claimer update no field allowlist |
| Z-SEC-004…009 | Med/Low | Storage photo ACL; report flood; engagement counters; create-moderator test gap; env history; dead pushQueue |

**Checked:** privileged entitlement fields denied on update; config kill-switch write false; joint publish server-only (with residual integrity elsewhere).

### B — Data / backend integrity

| ID | Sev | Title |
|---|---|---|
| **Z-DATA-001** | Critical | Client-writable workoutScore / streaks / stats *(owns SEC-002/SOC-001/RT-003)* |
| Z-DATA-002 | High | `mode` still written; derivation APIs disagree |
| Z-DATA-003 | High | No `clearPersistence` on sign-out |
| Z-DATA-004…005 | Med/Low | Expiry orphans; whereIn chunk 10 |

**Checked:** Session Timestamp coercion; Android `allowBackup=false` (`Z-DATA-006` Info).

### C — Cloud Functions

| ID | Sev | Title |
|---|---|---|
| Z-FN-001 | High | Push no rate limit / dedup |
| Z-FN-002 | High | App Check without consume / not `enforceAppCheck` |
| **Z-FN-003** | High | Account cleanup omits sessions/workouts/Storage/joint *(owns AUTH-001/SOC-006)* |
| Z-FN-004…006 | Med/Low | Push smoke missing; joint Storage orphan; CORS |

### D — Live session

| ID | Sev | Title |
|---|---|---|
| **Z-RT-001** | Critical | derivedMode cardio+cardio turn-based |
| Z-RT-002 | High | Non-transactional `switchTurn` / activeUserId |
| Z-RT-003 | High | Matchmaking ignores blocks |
| Z-RT-004 | High | Set submit / offline event ids |
| Z-RT-005…006 | Med | Pause not host-gated; no wakelock |

**Checked:** resume latch/kill switch/voice limits (`Z-RT-007` Info).

### E — Auth

High: `Z-AUTH-001` email enumeration · `Z-AUTH-002` email verify ungated · `Z-AUTH-003` sign-out caches · `Z-AUTH-004` Meta deletion URL · `Z-AUTH-007` deep-link drop. Medium/Low: prefs PII, username policy, password defaults. **Checked:** Apple Sign-In; privileged fields protected.

### F — Social / payments

High: `Z-SOC-001` UGC filter · `Z-SOC-002` moderation route · `Z-PAY-001` mock pay · `Z-PAY-002` Stripe/IAP policy. Medium: blocking gaps, EXIF. **Checked:** post visibility rules; no Stripe secret in client.

### G — Architecture / code

High: `Z-ARCH-001` layers 1/9 · `Z-ARCH-002` god files. Medium: `Z-CODE-001` Result/select/format.

### H — UI

High: `Z-UI-001` reduce-motion ignored *(merged A11Y-004)*. Medium: `Z-UI-002` tokens/onboarding/PopScope.

### I — Accessibility

High: `Z-A11Y-001` thin Semantics · `Z-A11Y-002` rep counter · `Z-A11Y-003` 1.3× clamp · `Z-A11Y-004` live regions. Medium: `Z-A11Y-005` guideline/contrast/transcripts.

### J — i18n / RTL

High: `Z-I18N-001` literals · `Z-I18N-002` RTL · `Z-I18N-003` push English. Medium: numbers/timeago/platform locale.

### K — Performance

High: `Z-PERF-001` rebuild storm · `Z-PERF-002` listener fan-out. Medium: startup/images/obfuscation. Low: 15s heartbeat.

### L — Offline

High: `Z-OFF-001` queue scoping · `Z-OFF-002` duplicate queue. Medium: cap/retries/connectivity.

### M — Notifications

High: `Z-NOTIF-001` buddy broken · `Z-NOTIF-002` preference fail-open · Android icon owned by `Z-AND-001`. Medium: device schema / god service.

### N — Android

High: `Z-AND-001` notif icon · `Z-AND-002` res/xml · `Z-AND-003` signing when no key.props · toolchain owned by `Z-CI-001`. **Checked:** minify/backup/namespace.

### O — iOS

| ID | Sev | Title |
|---|---|---|
| **Z-IOS-001** | Critical | aps-environment development |
| Z-IOS-002…005 | High | Facebook plist; PrivacyInfo empty; no Podfile; deploy target 13 |
| Z-IOS-006 | Med | fetch mode / AppDelegate / ATT |

### P — Other platforms

High: `Z-PLAT-001` tracked linux/macos without support (overlaps `Z-REPO-001`).

### Q — Testing

High: `Z-TEST-001` no coverage gate · `Z-TEST-002` feed/social ~0% · `Z-TEST-003` no functions tests · `Z-TEST-004` no storage emulator. Medium: brittle contracts/goldens/integration. **Checked:** rules suite strength.

### R — CI/CD

High: `Z-CI-001` Flutter pin · `Z-CI-002` dual pipelines · `Z-CI-003` obfuscation/config · `Z-CI-004` ungated rules deploy. Medium: pins/publish/bash/branches.

### S — Observability

High: `Z-OBS-001` no Performance · `Z-OBS-002` dual analytics · `Z-OBS-003` no forced update. Medium: scrub/flags/alerts. **Checked:** Crashlytics debug off; debugPrint silenced.

### T — Dependencies

High: `Z-DEP-001` store deadline calendar · `Z-DEP-002` admin/`qs`. Medium: Dart majors / niches. Toolchain skew owned by `Z-CI-001`.

### U — Privacy

High: `Z-PRV-001` inventory · `Z-PRV-002` consent/export · `Z-PRV-003` legal drift · `Z-PRV-004` EXIF. Medium: deletion NV / presence / FB token.

### V — Documentation

High: `Z-DOC-001` CLAUDE/AGENTS. Medium: Spec Kit / ADRs / CHANGELOG.

### W — Repository / branch

High: `Z-REPO-001` unsupported platforms · `Z-REPO-002` gitlinks · `Z-REPO-004`–`007` cutover/ops. Medium: binaries/codex/format.

---

## 7. Journey traces J1–J17

Source: `build/audit-work/journeys.md`. **Summary: fail 7 · risk 10 · pass 0.**

| J | Name | Verdict | Key findings |
|---|---|---|---|
| J1 | First launch → home | risk | AUTH-*, I18N-001, IOS-002 |
| J2 | Cold start resume + push | risk | IOS-001, NOTIF, RT-013 checked |
| J3 | Start → lobby → live | risk | NOTIF-001, RT-009, DATA-006 |
| J4 | Turn-based + joint post | **fail** | DATA-001, RT-002/003/005 |
| J5 | Parallel gym+cardio | **fail** | **RT-001**, DATA-002 |
| J6 | Matchmaking + invite code | risk | SEC-003, RT-003, JOURNEY-001 |
| J7 | Kill/resume 007 | risk | REPO-004…007, RT-013 |
| J8–J17 | Feed/social/settings/delete/mod/pay/a11y/i18n/offline/notif/tablet | mix fail/risk | See journeys.md |

New gap stub: `Z-JOURNEY-001` invite-code get without rate limit.

---

## 8. Abuse-case results 1–22

Source: `build/audit-work/abuse-cases.md`. **Vulnerable 5 · Partially allowed 10 · Mitigated 6 · Needs verification 1.**

| # | Result | Owning finding(s) |
|---|---|---|
| 1 Moderator self-grant | Mitigated (create test gap) | Z-SEC-008 |
| 2 Premium self-grant | Mitigated (feature broken) | Z-PAY-001 |
| 3 Inflate score | **Vulnerable** | **Z-DATA-001** |
| 4 Session lifecycle forge | Partially allowed | Z-RT-002 |
| 5 Foreign presence/plan | Mitigated (+ workouts forge) | Z-SEC-002 |
| 6 Private follow/posts | Partially allowed | **Z-SEC-001** |
| 7 Foreign notifications | Mitigated / CF spam | Z-FN-001 |
| 8 Push unauth/rate | Partially allowed | Z-FN-001/002 |
| 9 Reaction tallies | Partially allowed | Z-SEC-006 |
| 10 Username claim | Mitigated / policy | AUTH-007 draft |
| 11 Enumerate members | **Vulnerable** | **Z-SEC-001**, Z-AUTH-001 |
| 12 Invite codes | Partially allowed | Z-JOURNEY-001 |
| 13 Matchmaking/blocks | **Vulnerable** | Z-SEC-003, Z-RT-003 |
| 14 Storage ACL | Partially allowed | Z-SEC-004 |
| 15 Joint without consent | Mitigated | Z-FN-005 residual |
| 16 Catalog write | Mitigated / review flood | SEC-010 pattern |
| 17 Flood cost | **Vulnerable** | Z-SEC-005, Z-FN-001 |
| 18 Config flags | Mitigated | — |
| 19–22 | See abuse-cases.md | PRV/OBS/TEST |

---

## 9. Appendices

### 9.A DRAFT → final ID mapping (major merges)

| Draft / prior | Final owner |
|---|---|
| DRAFT-SEC-001, DRAFT-SOC-007 | **Z-SEC-001** |
| DRAFT-DATA-001, DRAFT-SEC-002, DRAFT-SOC-001, DRAFT-RT-003, REC-14 | **Z-DATA-001** |
| DRAFT-RT-001 | **Z-RT-001** |
| DRAFT-DATA-002 | **Z-DATA-002** (related to RT-001) |
| DRAFT-IOS-001 | **Z-IOS-001** |
| DRAFT-AUTH-001, DRAFT-FN-003, DRAFT-SOC-006, REC-13 | **Z-FN-003** |
| DRAFT-NOTIF-003, DRAFT-AND-004 | **Z-AND-001** |
| DRAFT-UI-002, DRAFT-A11Y-004 | **Z-UI-001** |
| DRAFT-UI-003, DRAFT-A11Y-003 | **Z-A11Y-003** |
| DRAFT-CI-001, DRAFT-AND-001, DRAFT-DEP-001 | **Z-CI-001** |
| DRAFT-SOC-003, DRAFT-ARCH-003 | **Z-SOC-002** |
| DRAFT-DOC-001 | **Z-PRV-003** |
| DRAFT-PERF-003, DRAFT-OBS-001 | **Z-OBS-001** |

Complete map: JSON `draftToFinal`.

### 9.B Collections × rules × functions × tests (summary)

| Area | Rules | Functions | Tests |
|---|---|---|---|
| users / stats | list Critical gap; counters writable | cleanup partial | social emulator strong on entitlements |
| sessions / plans / events / presence | participant updates; mode residual | expireStaleSessions | session_resume suite |
| posts / joint | dual-consent server publish | publish/expire/cleanup | posts_joint suite |
| notifications | owner create | deliverNotificationPush | contract + social |
| storage | ACL + size | cleanup gaps | **contract only** |
| matchmaking | claim allowlist gap | — | create tests only |

### 9.C Notification catalog (gaps)

Buddy family **broken** (`Z-NOTIF-001`). Preference fail-open (`Z-NOTIF-002`). Joint/streak keys incomplete. Locale missing on devices (`Z-I18N-003`).

### 9.D Routes × guards

Auth redirects present; **moderation unguarded** (`Z-SOC-002`); deep-link `from` dropped (`Z-AUTH-007`); resume latch present.

### 9.E God-file split plan (seed)

1. `session_room_page.dart` → lobby / turn / parallel / presence / overlays  
2. `notification_service.dart` → transport / catalog / navigation  
3. `session_service.dart` → lifecycle / turns / scoring (move scoring server)  
4. `onboarding_page.dart` → steps widgets  

### 9.F Dependency snapshot

See baseline `pub-outdated.txt` / `npm-outdated-functions.txt`. Notable: go_router 17→18, cached_network_image 3→4, sign_in_with_apple 7→8, firebase-admin 13→14, `qs` moderate.

### 9.G Platform deadline calendar (verify on ship)

Track Apple SDK / Xcode requirements, Play target API / 16 KB page size, CocoaPods trunk read-only plan (~2026-12) — `Z-DEP-001`, `Z-IOS-004`, `Z-AND` 16KB NV.

### 9.H Personal-data inventory (sketch)

Auth identifiers, profile PII, presence, session events, voice notes, photos, FCM tokens, analytics/Crashlytics, Facebook token on Android — align PrivacyInfo + Play Data safety (`Z-PRV-001`).

---

## 10. Open questions for the owner

1. Confirm **deployed** `expireStaleSessions` + composite indexes (prod/staging).  
2. Keep or remove **Facebook Login** until Meta deletion URL + iOS plist exist?  
3. **Leaderboard:** hide until server scores, or ship as “unofficial”?  
4. **Clean-arch:** finish migration or formally retire and archive `lib/core/migration/**`?  
5. **Stripe vs IAP:** abandon Stripe digital path for RevenueCat/Play Billing/StoreKit?  
6. **Supported platforms:** drop `linux/`/`macos/` from product scope?  
7. **History `.env`:** rotate Firebase API-key restrictions / Stripe publishable; rewrite history?  
8. Schedule **T054** device day for 007 cutover?  
9. Target Flutter pin: stay on **3.38.9** CI or move to **3.44.x**?  
10. Arabic as **launch requirement** or post-MVP?

---

## 11. Unverified items & DoD gaps

### Unverified (exact steps)

| Item | How to verify |
|---|---|
| Prod push + App Check | Staging HTTPS call with ID token + App Check; device receipt |
| Crashlytics upload | Force release crash; confirm console |
| APNs production | TestFlight build entitlements = production; receive invite |
| 16 KB page size | Bundle analyzer / Play pre-launch on arm64-16kb |
| Plugin iOS min version | `pod install` on Codemagic; check deployment target warnings |
| EXIF strip | GPS-tagged fixture upload → download → exiftool |
| Account deletion completeness | Delete test user; enumerate sessions/workouts/Storage/joint |
| GHA enabled | `gh run list` in org with Actions on |
| SC-002 ≤2s | Instrument resume wall-clock on device or add timing test |

### §10 DoD checklist

| Criterion | Status |
|---|---|
| Domains A–W covered | **Met** (findings or checked notes) |
| Critical/High re-verified | **Met** for Criticals; Highs evidence-backed; some Probable/NV labeled |
| Prior IDs reconciled | **Met** (prior-reconciliation.md + JSON) |
| §3.10 leads resolved | **Met** |
| Journeys J1–J17 + abuse 1–22 | **Met** |
| ≥40 enhancements + roadmap | **Met** (45) |
| Counts match JSON; JSON parses | **Met** |
| No secrets in outputs | **Met** (names/paths only; secret-scan below) |
| git status only deliverables | **Partial** — pre-existing dirty WT remains; audit must not modify product code (unchanged by this task) |
| Limitations listed | **Met** |

**Unmet / partial:** clean `git status` cannot be satisfied while unrelated WIP exists; iOS binary verification impossible on Windows host; production console items remain NV.

---

*End of report. Machine-readable detail: `2026-09-17-full-audit-findings.json`. Roadmap: `2026-09-17-improvement-roadmap.md`.*
