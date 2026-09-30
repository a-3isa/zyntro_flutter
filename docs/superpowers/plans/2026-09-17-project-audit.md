# Project Audit Plan (Audit-Only)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Companion checklist:** Domain questions, journey IDs, abuse cases, finding templates, and rubrics live in [`docs/audits/2026-09-14-full-audit-prompt.md`](../../audits/2026-09-14-full-audit-prompt.md). This plan is the **execution schedule**; that file is the **evidence checklist**. Do not invent a second checklist — follow §5–§10 of the prompt when a task says "run domain X".

**Goal:** Produce a complete, evidence-backed audit of Zyntro (Flutter client, Firebase backend, native shells, tests, CI, docs) with prioritized findings and an improvement roadmap — without changing product code.

**Architecture:** Read-only investigation with writes limited to `docs/audits/<RUN_DATE>-*` deliverables and gitignored `build/audit-work/**` scratch. Navigate via `graphify` first, then Grep/Glob, then ≤200-line file windows. Fan out domain passes to subagents with narrow scopes; merge and re-verify Critical/High centrally. Remediation is **out of scope** (separate Spec Kit slices after this plan).

**Tech Stack:** Flutter/Dart · Firebase (Auth, Firestore, Storage, Functions, FCM, App Check, Crashlytics) · Riverpod · go_router · PowerShell host · graphify · firebase rules unit tests · GitHub Actions / Codemagic

**RUN_DATE:** Use the calendar date the audit actually starts (`YYYY-MM-DD`). Examples below use `2026-09-17`; replace if the run starts later.

**Branch baseline:** Record the live branch/SHA in Phase 0; do not assume `007-resume-active-session` is current.

---

## Constitution gates (pre-design)

| Gate | Status |
|---|---|
| I. Feature-slice scope | Pass — this plan is one named effort: **project audit**; no product migration slices |
| II. Evidence-first | Pass — every finding requires `path:line` and/or reproducible command evidence |
| III. Security integrity | Pass — security domains A/C/E/F/N/O/U are mandatory; Critical findings block any "release ready" verdict |
| IV. Operational safety | Pass — no deploys, no production Firebase writes, emulators/`demo-*` only |
| V. Independent deliverability | Pass — each task produces a scratch or deliverable artifact that can resume after compaction |

**Post-design:** Unchanged — audit remains read-only; remediation deferred to post-audit Spec Kit slices.

---

## Scope

**In scope**

- `lib/`, `test/`, `integration_test/`, `test/rules/`
- `firebase/`, `functions/`
- `android/`, `ios/` (and note `linux/`/`macos/` hygiene)
- `.github/`, `codemagic.yaml`, `scripts/`
- `docs/`, `specs/`, `.specify/`, store/design assets
- Prior audits for reconciliation only

**Out of scope**

- Editing tracked application/source files
- `flutter pub upgrade`, `dart fix --apply`, format-with-rewrite, `flutter clean`
- Firebase deploy / production console mutation / real push sends
- Opening secret files: `android/key.properties`, release keystore, `google-services.json`, `GoogleService-Info.plist`, real `.env`
- Implementing fixes (see Task 12 handoff only)

**Allowed writes**

| Path | Purpose |
|---|---|
| `docs/audits/<RUN_DATE>-full-audit.md` | Human report |
| `docs/audits/<RUN_DATE>-full-audit-findings.json` | Machine-readable findings |
| `docs/audits/<RUN_DATE>-improvement-roadmap.md` | Phased roadmap + enhancements |
| `build/audit-work/**` | Command logs, per-domain notes, progress |

---

## File map (create / touch)

| File | Responsibility |
|---|---|
| `build/audit-work/progress.md` | One-line checkpoint after every task |
| `build/audit-work/baseline/*.txt` | Tool baseline command outputs |
| `build/audit-work/findings/<domain>.md` | Per-domain draft findings (A–W) |
| `build/audit-work/prior-reconciliation.md` | Prior-audit ID status table |
| `build/audit-work/journeys.md` | J1–J17 traces |
| `build/audit-work/abuse-cases.md` | Abuse cases 1–22 |
| `docs/audits/<RUN_DATE>-full-audit.md` | Final report |
| `docs/audits/<RUN_DATE>-full-audit-findings.json` | Final JSON |
| `docs/audits/<RUN_DATE>-improvement-roadmap.md` | Final roadmap |

---

## Method (non-negotiable)

1. **Graph first:** `graphify query "…"` / `path` / `explain` to locate; graph is a map, never evidence.
2. **Explicit raw-file reads:** For this plan, reading source files is authorized (same as the companion prompt §2.1).
3. **Evidence standard:** Companion prompt §2.4 — cite `path:line`, search for mitigations before claiming absence, separate repo vs deployed state.
4. **Secrets:** Never print secret values; report names/paths/types only (prompt §2.3).
5. **Windows PowerShell:** No `&&`; use `;` and `if ($?) { … }`. Redirect long output to `build/audit-work/`.
6. **Exclude nested checkouts** from search scope: `.worktrees/`, `.claude/worktrees/`.
7. **God files:** Never read end-to-end; ≤200-line windows at Grep hits only.
8. **Findings in files, not chat.** Chat stays short; reports are complete professional English.

---

### Task 0: Scratch workspace and progress log

**Files:**
- Create: `build/audit-work/progress.md`
- Create: `build/audit-work/findings/` (directory)

- [ ] **Step 1: Create scratch tree**

```powershell
New-Item -ItemType Directory -Force -Path build/audit-work/baseline, build/audit-work/findings | Out-Null
@"
# Audit progress — RUN_DATE TBD
| Task | Status | Notes |
|------|--------|-------|
"@ | Set-Content -Encoding utf8 build/audit-work/progress.md
```

- [ ] **Step 2: Confirm gitignored**

```powershell
git check-ignore -v build/audit-work/progress.md
```

Expected: a matching ignore rule (under `/build/` or equivalent). If not ignored, stop and fix ignore before continuing — do not commit scratch.

- [ ] **Step 3: Append progress line**

Append: `| 0 | done | scratch ready |`

---

### Task 1: Phase 0 — Orientation

**Files:**
- Create: `build/audit-work/orientation.md`
- Modify: `build/audit-work/progress.md`

- [ ] **Step 1: Capture repo identity**

```powershell
git rev-parse HEAD | Set-Content build/audit-work/baseline/head.txt
git status --short | Set-Content build/audit-work/baseline/status.txt
git log --oneline -30 | Set-Content build/audit-work/baseline/log30.txt
git branch -a | Set-Content build/audit-work/baseline/branches.txt
git worktree list | Set-Content build/audit-work/baseline/worktrees.txt
```

- [ ] **Step 2: Refresh knowledge graph**

```powershell
graphify . --update
```

Then read `graphify-out/GRAPH_REPORT.md` (communities, god nodes). Summarize into `build/audit-work/orientation.md` (≤40 lines): branch, SHA, dirty tree summary, top god nodes, active specs.

- [ ] **Step 3: Read orientation docs (full, small files)**

Read: `README.md`, `AGENTS.md`, `CLAUDE.md`, `.specify/memory/constitution.md`, `pubspec.yaml`, `analysis_options.yaml`, `l10n.yaml`, `firebase.json`, `.firebaserc`, `functions/package.json`, `codemagic.yaml`, `.github/workflows/flutter-ci.yml`, `store/play/STORE_LISTING.md`, and the active feature’s `specs/*/spec.md` + `plan.md` on the current branch.

- [ ] **Step 4: Set RUN_DATE**

Write `RUN_DATE=YYYY-MM-DD` into `build/audit-work/orientation.md` and the progress header.

- [ ] **Step 5: Progress**

Append: `| 1 | done | orientation captured |`

---

### Task 2: Phase 0 — Tool baseline

**Files:**
- Create: `build/audit-work/baseline/*.txt` (command outputs)
- Create: `build/audit-work/baseline-summary.md`
- Modify: `build/audit-work/progress.md`

- [ ] **Step 1: Run baseline commands** (companion prompt §4.2)

```powershell
flutter --version > build/audit-work/baseline/flutter-version.txt 2>&1
flutter doctor -v > build/audit-work/baseline/doctor.txt 2>&1
flutter pub get > build/audit-work/baseline/pub-get.txt 2>&1
git diff --stat -- pubspec.lock | Set-Content build/audit-work/baseline/lock-diff.txt
# If lock-diff is non-empty: restore and note it — do not leave dirty lock
flutter analyze lib test integration_test > build/audit-work/baseline/analyze.txt 2>&1
dart format --output=none --set-exit-if-changed lib test integration_test > build/audit-work/baseline/format.txt 2>&1
flutter test --reporter compact --coverage --coverage-path build/audit-work/baseline/lcov.info > build/audit-work/baseline/test.txt 2>&1
flutter pub outdated > build/audit-work/baseline/pub-outdated.txt 2>&1
flutter pub deps --style=compact > build/audit-work/baseline/pub-deps.txt 2>&1
node --check functions/index.js > build/audit-work/baseline/functions-syntax.txt 2>&1
npm audit --prefix functions > build/audit-work/baseline/npm-audit-functions.txt 2>&1
npm outdated --prefix functions > build/audit-work/baseline/npm-outdated-functions.txt 2>&1
npm audit --prefix test/rules > build/audit-work/baseline/npm-audit-rules.txt 2>&1
npm test --prefix test/rules > build/audit-work/baseline/rules-tests.txt 2>&1
powershell -ExecutionPolicy Bypass -File scripts/validate_feature_layers.ps1 > build/audit-work/baseline/layers.txt 2>&1
```

If a command cannot run (no Java, no firebase-tools, etc.), record **Skipped: &lt;reason&gt;** in the summary — do not invent results.

- [ ] **Step 2: Write `baseline-summary.md`**

Include: analyzer issue counts; failing/skipped tests; overall coverage %; major outdated packages; npm audit Critical/High counts; rules-test pass/fail; layer-validation result; skipped commands.

- [ ] **Step 3: Progress**

Append: `| 2 | done | baseline summarized |`

---

### Task 3: Prior-audit reconciliation

**Files:**
- Create: `build/audit-work/prior-reconciliation.md`
- Modify: `build/audit-work/progress.md`

**Sources (re-verify in code — never trust status text):**

- `docs/project_weak_point_audit.md`
- `docs/audits/2026-05-02-application-audit.md` (F01–F35)
- `docs/audits/2026-05-02-fix-tickets.md` (AUD-001…035)
- `docs/audits/2026-08-03-deep-audit-findings.md` (C/H/M/L/R IDs)
- `docs/audits/2026-05-02-audit-roadmap.md` (phase exit criteria as hints only)

- [ ] **Step 1: Build the master table**

Columns: `Prior ID | Title | Status | Evidence | Regression test? | Notes`

Status enum only: `Fixed & verified` | `Fixed, unverified` | `Partially fixed` | `Open` | `Regressed` | `Withdrawn` | `Superseded`

- [ ] **Step 2: Promote gaps**

Every prior security/integrity item marked fixed **without** a regression guard → draft finding in `build/audit-work/findings/reconciliation.md` (will merge into final IDs later).

- [ ] **Step 3: Resolve companion §3.10 leads**

For each lead in `docs/audits/2026-09-14-full-audit-prompt.md` §3.10: confirm → finding stub ID, or refute → one-line reason in the reconciliation doc.

- [ ] **Step 4: Progress**

Append: `| 3 | done | prior IDs reconciled |`

---

### Task 4: Current-branch readiness

**Files:**
- Create: `build/audit-work/branch-readiness.md`
- Modify: `build/audit-work/progress.md`

- [ ] **Step 1: Diff vs default remote branch**

```powershell
# Adjust default branch name if remote HEAD differs
git remote show origin | Select-String "HEAD branch"
git log --oneline origin/HEAD..HEAD | Set-Content build/audit-work/baseline/branch-commits.txt
git diff --stat origin/HEAD...HEAD | Set-Content build/audit-work/baseline/branch-diffstat.txt
```

- [ ] **Step 2: Spec gates for the active feature**

Read that feature’s `spec.md` / `plan.md` / `tasks.md`. Record: unchecked tasks, evidence gates, kill switches, telemetry, rollback notes, constitution II blockers.

- [ ] **Step 3: Verdict**

Write one of: `merge-ready` | `blocked` with blocker list (finding stubs or task IDs).

- [ ] **Step 4: Progress**

Append: `| 4 | done | branch verdict recorded |`

---

### Task 5: Domain passes — Security & backend (A, C)

**Files:**
- Create: `build/audit-work/findings/A-sec-rules.md`
- Create: `build/audit-work/findings/C-functions.md`
- Modify: `build/audit-work/progress.md`

**Checklist source:** companion prompt §5-A and §5-C.

- [ ] **Step 1: Inventory**

Map every collection/subcollection referenced in `lib/`, `functions/`, `scripts/` to `firebase/firestore.rules` and `firebase/storage.rules`. Note unmatched refs.

- [ ] **Step 2: Rules deep review**

Focus: `/users` privileged fields, session lifecycle, follows/requests, notifications, leaderboard/entitlements, Storage paths. Cite `path:line`. Prefer emulator proofs via existing `test/rules/*.rules.test.mjs` gaps as findings.

- [ ] **Step 3: Functions review**

`functions/index.js`: auth on HTTPS, CORS, idempotency, schedulers’ query bounds, client-callable privilege, App Check / rate limits. No production invoke.

- [ ] **Step 4: Progress**

Append: `| 5 | done | domains A,C drafted |`

---

### Task 6: Domain passes — Data, offline, live session (B, L, D)

**Files:**
- Create: `build/audit-work/findings/B-data.md`
- Create: `build/audit-work/findings/L-offline.md`
- Create: `build/audit-work/findings/D-live-session.md`
- Modify: `build/audit-work/progress.md`

**Checklist source:** companion prompt §5-B, §5-L, §5-D.

- [ ] **Step 1: Data & cost**

Quantify unbounded `.get()` / listeners / missing `.limit(`; N+1 patterns in services; indexes vs queries.

- [ ] **Step 2: Offline**

`lib/utils/offline_manager.dart` and handlers: durability, idempotent replay, conflict behavior, resume-from-cache (spec 007 FR-012).

- [ ] **Step 3: Live session**

Mode derivation (never stored), lobby handshake, presence, turn eligibility, resume decision purity, joint-post consent, invite/matchmaking paths. God-file windows only (`session_room_page`, `session_service`).

- [ ] **Step 4: Progress**

Append: `| 6 | done | domains B,L,D drafted |`

---

### Task 7: Domain passes — Auth, notifications, social/payments (E, M, F)

**Files:**
- Create: `build/audit-work/findings/E-auth.md`
- Create: `build/audit-work/findings/M-notifications.md`
- Create: `build/audit-work/findings/F-social-pay.md`
- Modify: `build/audit-work/progress.md`

**Checklist source:** companion prompt §5-E, §5-M, §5-F.

- [ ] **Step 1: Auth lifecycle**

Signup/login/onboarding/profile, email verify, reauth, delete account completeness, deep-link preservation through auth.

- [ ] **Step 2: Notifications**

FCM token refresh, terminated initial message, preferences, push queue vs client writes, spoofing paths.

- [ ] **Step 3: Social / UGC / payments**

Follows/blocks/reports/moderation, content filter, leaderboard entitlement trust boundary, Stripe path status (blocked vs live).

- [ ] **Step 4: Progress**

Append: `| 7 | done | domains E,M,F drafted |`

---

### Task 8: Domain passes — Architecture, UI, a11y, i18n (G, H, I, J)

**Files:**
- Create: `build/audit-work/findings/G-arch-code.md`
- Create: `build/audit-work/findings/H-ui.md`
- Create: `build/audit-work/findings/I-a11y.md`
- Create: `build/audit-work/findings/J-i18n.md`
- Modify: `build/audit-work/progress.md`

**Checklist source:** companion prompt §5-G…§5-J.

- [ ] **Step 1: Architecture / code quality**

Clean-arch migration progress (auth vs others), god files, Riverpod vs `setState`, import boundaries (`scripts/validate_feature_layers.ps1` result), dead shims.

- [ ] **Step 2: UI / design system**

Theme token bypasses (`Color(0x…)`), brand chrome consistency, empty/loading/error states on primary flows.

- [ ] **Step 3: Accessibility**

Semantics, focus order, contrast risks, reduced-motion, large text / small screen scroll fallbacks.

- [ ] **Step 4: i18n / RTL**

`app_en.arb` vs `app_ar.arb` parity, remaining hard-coded `Text('…')`, RTL layout breaks.

- [ ] **Step 5: Progress**

Append: `| 8 | done | domains G–J drafted |`

---

### Task 9: Domain passes — Perf, platforms, quality, ops (K, N–W)

**Files:**
- Create: `build/audit-work/findings/K-perf.md`
- Create: `build/audit-work/findings/N-android.md`
- Create: `build/audit-work/findings/O-ios.md`
- Create: `build/audit-work/findings/P-plat.md`
- Create: `build/audit-work/findings/Q-test.md`
- Create: `build/audit-work/findings/R-ci.md`
- Create: `build/audit-work/findings/S-obs.md`
- Create: `build/audit-work/findings/T-deps.md`
- Create: `build/audit-work/findings/U-privacy.md`
- Create: `build/audit-work/findings/V-docs.md`
- Create: `build/audit-work/findings/W-repo.md`
- Modify: `build/audit-work/progress.md`

**Checklist source:** companion prompt §5-K and §5-N…§5-W.

- [ ] **Step 1: Performance**

Cold start (`lib/main.dart`), listener lifetime / `autoDispose`, list builders vs eager scroll views, asset shipping size, animation disposal sampling.

- [ ] **Step 2: Android / iOS / other platforms**

Manifest permissions, MainActivity package, splash/styles, privacy strings, entitlements (`PrivacyInfo.xcprivacy`, `Runner.entitlements`), push capability — **do not open** secret config files; note presence via `Test-Path` only.

- [ ] **Step 3: Tests / CI / observability / deps**

Coverage holes on services; CI Flutter version vs SDK; ignore_failure; Crashlytics wiring; `npm audit` / `pub outdated` from baseline.

- [ ] **Step 4: Privacy / docs / hygiene**

Legal pages vs actual data flows; agent instruction drift; untracked junk; secret history risk (gitleaks optional).

- [ ] **Step 5: Progress**

Append: `| 9 | done | domains K,N–W drafted |`

---

### Task 10: Journey traces and abuse cases

**Files:**
- Create: `build/audit-work/journeys.md`
- Create: `build/audit-work/abuse-cases.md`
- Modify: `build/audit-work/progress.md`

**Checklist source:** companion prompt §6 (J1–J17) and §7 (cases 1–22).

- [ ] **Step 1: Trace each journey**

For each J#: happy path, failure/empty/offline variants, deep links, back navigation. Link to finding IDs or mark clean.

- [ ] **Step 2: Abuse cases**

For each case: result (`Vulnerable` / `Mitigated` / `Needs verification`) + evidence. Promote Vulnerable → finding stub if not already captured.

- [ ] **Step 3: Progress**

Append: `| 10 | done | journeys + abuse complete |`

---

### Task 11: Verification, merge, deliverables

**Files:**
- Create: `docs/audits/<RUN_DATE>-full-audit.md`
- Create: `docs/audits/<RUN_DATE>-full-audit-findings.json`
- Create: `docs/audits/<RUN_DATE>-improvement-roadmap.md`
- Modify: `build/audit-work/progress.md`

**Formats:** companion prompt §9 (report outline, finding template, JSON shape, rubrics, roadmap outline).

- [ ] **Step 1: Re-verify Critical/High**

Re-open every Critical/High draft; downgrade or drop if not reproducible; merge duplicates (one owning ID).

- [ ] **Step 2: Assign final IDs**

Prefixes: `Z-SEC|DATA|FN|RT|AUTH|SOC|PAY|ARCH|CODE|UI|A11Y|I18N|PERF|OFF|NOTIF|AND|IOS|PLAT|TEST|CI|OBS|DEP|PRV|DOC|REPO-###` and `Z-ENH-###`.

- [ ] **Step 3: Write the three deliverables**

1. Full audit markdown (§9.1 sections 0–11).
2. Findings JSON (§9.3) — must parse:

```powershell
node -e "JSON.parse(require('fs').readFileSync('docs/audits/<RUN_DATE>-full-audit-findings.json','utf8')); console.log('ok')"
```

3. Improvement roadmap (§9.5) with ≥40 RICE-scored enhancements, Now/Next/Later, stop-doing list, proposed `008-…` slices.

- [ ] **Step 4: Secret scan of deliverables**

Search deliverables for key/token patterns; redact if any.

- [ ] **Step 5: Definition of Done checklist**

Execute companion prompt §10 checkboxes against the three files.

- [ ] **Step 6: Git hygiene check**

```powershell
git status --short
```

Expected: only new `docs/audits/<RUN_DATE>-*` files (plus any pre-existing untracked docs the owner already had). **No** tracked source changes. Do **not** commit unless the owner asks.

- [ ] **Step 7: Progress**

Append: `| 11 | done | deliverables written |`

---

### Task 12: Handoff only (no code changes)

**Files:**
- Create: `build/audit-work/remediation-handoff.md` (optional scratch)
- Modify: `build/audit-work/progress.md`

- [ ] **Step 1: List P0 / P1 only**

From the JSON: P0 = Critical, or High+Confirmed on journeys J1–J7; P1 = other High.

- [ ] **Step 2: Propose Spec Kit slice names**

Example shape: `008-firestore-trust-boundaries`, `009-session-room-split`, … — one sentence each, constitution-fit, **do not** create `specs/` folders in this plan.

- [ ] **Step 3: Chat summary (≤25 lines)**

Links to the three deliverables; overall grade; Play/App Store verdicts; top 5 blockers; top 5 quick wins; owner decisions needed.

- [ ] **Step 4: Progress**

Append: `| 12 | done | audit complete — remediation deferred |`

---

## Subagent fan-out (optional, recommended)

When dispatching parallel workers, use these groups (one output file each under `build/audit-work/findings/`):

| Group | Domains | Output |
|---|---|---|
| 1 | A, C | `A-sec-rules.md`, `C-functions.md` |
| 2 | B, L | `B-data.md`, `L-offline.md` |
| 3 | D | `D-live-session.md` |
| 4 | E, M | `E-auth.md`, `M-notifications.md` |
| 5 | F | `F-social-pay.md` |
| 6 | G | `G-arch-code.md` |
| 7 | H, I, J | `H-ui.md`, `I-a11y.md`, `J-i18n.md` |
| 8 | K | `K-perf.md` |
| 9 | N, O, P, U | `N-android.md`, `O-ios.md`, `P-plat.md`, `U-privacy.md` |
| 10 | Q, R, S, T | `Q-test.md`, `R-ci.md`, `S-obs.md`, `T-deps.md` |
| 11 | V, W | `V-docs.md`, `W-repo.md` |

Orchestrator keeps Tasks 0–4, 10–12 and merges Task 11. Each subagent gets: this plan’s Method section + companion prompt §§2 + matching §5 domain only + “write findings only under your output files”.

---

## Variants (later runs)

| Variant | How |
|---|---|
| **Focused re-run** | Execute Tasks 0–2 lightly, then only selected domain tasks; append addendum + update JSON |
| **Delta audit** | `git diff <commit>..HEAD` as primary scope; re-verify all open JSON findings |
| **Fix planning** | New plan after Task 12 — Spec Kit `/speckit-specify` for P0 slices; never mix into audit |

---

## Relationship to prior artifacts

| Artifact | Role relative to this plan |
|---|---|
| `docs/audits/2026-09-14-full-audit-prompt.md` | Detailed checklists (source of truth for questions) |
| `docs/superpowers/plans/2026-08-03-project-wide-audit-optimization.md` | Older **audit + remediate** plan — superseded for scheduling; reuse Phase-0 ideas only |
| `docs/audits/2026-05-02-*`, `2026-08-03-deep-audit-findings.md` | Inputs to Task 3 reconciliation |
| This file | **Current** audit-only execution plan |

---

## Self-review (plan author)

1. **Spec coverage:** Companion prompt phases 0 → domains A–W → journeys → abuse → enhancements → DoD are all mapped to Tasks 1–11.
2. **Placeholders:** No TBD steps; RUN_DATE is an execution-time substitution, not an unfinished section.
3. **Separation:** Remediation explicitly deferred to Task 12 handoff / future Spec Kit slices.
4. **Constitution:** Gates documented pre/post; Critical security findings must block release-ready language in the report.
