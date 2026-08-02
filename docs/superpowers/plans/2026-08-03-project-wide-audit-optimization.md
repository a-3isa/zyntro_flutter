# Project-Wide Deep Review, Enhancement & Optimization Plan

**Date:** 2026-08-03
**Branch:** `006-offline-cache-sync`
**Scope:** Whole project — architecture, performance, UI/UX, accessibility, i18n, Firestore cost, security, build/release, tests, repo hygiene.

> **For agentic workers:** This is an *audit-then-remediate* plan, not a feature plan. Phase 0 produces a findings document. Phases 1-7 are remediation waves, each independently shippable and independently reviewable.

---

## Goal

Produce a complete, evidence-backed picture of every weakness in the Zyntro Flutter app, then fix them in priority order — highest user-visible and cost impact first — without regressing the 523 passing tests or the two features just shipped (joint posts, leaderboard scoring).

## Method & Token Strategy

The codebase is 62,935 lines across 171 Dart files. Reading it whole is not affordable and not necessary.

**Rules for every phase:**

1. **Never read a god file end-to-end.** Files over 1,000 lines are read in ≤200-line windows, and only the windows a grep hit points at.
2. **Query the knowledge graph before reading source.** `graphify-out/graph.json` already indexes 5,282 nodes / 7,760 edges / 224 communities. Use `/graphify query "<question>"` to locate the relevant community and file set, *then* grep, *then* read a window.
3. **Grep-first quantification.** Every claim in the findings doc must be backed by a counted grep or a file:line reference. No impressionistic findings.
4. **Obsidian vault** (`C:\Users\user\ObsidianVaults\zyntro_flutter`) is the symbol index — use it to answer "what references X / what does Y import" in one Read instead of a repo-wide grep. It is AST-only, so it answers *structure* questions, never *behavior* questions.
5. **Findings live in files, not in chat.** Each phase appends to `docs/audits/2026-08-03-deep-audit-findings.md`. Nothing large gets pasted into conversation.

---

## Pre-Flight Findings (already established during recon)

These are confirmed, counted, and do not need re-discovery. They seed the phases.

| # | Finding | Evidence | Phase |
|---|---------|----------|-------|
| P1 | ~1.9 MB of unused splash art ships in every build | `pubspec.yaml` declares `- assets/` wholesale; `assets/` holds `splash_option_3.png` (508K), `splash_logo.png` (508K), `splash_human_v3.png` (468K), `splash_z_v4.png` (400K) — only `splash_z_v5.png` is referenced. `app_icon.png` (532K) is build-time-only for `flutter_launcher_icons` yet also ships. | 1 |
| P2 | Zero internationalization | 200 `Text('...')` literals in `lib/`; 0 hits for `AppLocalizations` / `S.of(context)`. No `l10n` config. | 6 |
| P3 | Accessibility is near-absent | 13 `Semantics(` and 13 `tooltip:` across 62,935 lines. | 5 |
| P4 | Eight god files carry the app | `session_room_page.dart` 3750, `profile_page.dart` 3006, `start_session_page.dart` 1805, `recap_page.dart` 1755, `session_service.dart` 1745, `social_page.dart` 1523, `post_card_widget.dart` 1518, `post_detail_page.dart` 1472. | 4 |
| P5 | Provider lifecycle is unmanaged | 98 providers declared, only 4 `autoDispose`. 28 `StreamProvider`s — an un-disposed `StreamProvider` holds a live Firestore listener (and its billing) for the whole app session. | 2 |
| P6 | Firestore reads are largely unbounded | 102 `.get()` call sites vs 28 `.limit(` call sites. | 2 |
| P7 | Theme system is bypassed | 145 raw `Color(0x…)` literals despite a 687-line `app_theme.dart` and a "Design Tokens & Theme System" graph community. | 5 |
| P8 | Crash reporting never wired | `lib/utils/global_error_handler.dart:44` — `// TODO: Report to Crashlytics`. Production failures are unobservable. | 3 |
| P9 | Dead compatibility shim still present | `lib/services/auth_service.dart` (12 lines, 1 remaining reference) — open item from the 2026-03-30 weak-point audit. | 7 |
| P10 | Repo polluted with shell-redirect garbage | Untracked files named `!author.removed)`, `(value`, `,+`, `[]`, `{`, `_isLoading`, `p.id)` etc. in repo root — artifacts of malformed redirects in prior sessions. | 7 |
| P11 | 11 of 26 services have no test file | Untested: `payment_service`, `media_service`, `moderation_service`, `presence_service`, `storage_service`, `matchmaking_service`, `workout_service`, `user_service`, `buddy_service`, `content_filter_service`, `username_service`, `voice_recording_service`, `feed`/`user`/`profile` cache partial. | 7 |
| P12 | Firestore rules are 537 lines with one emulator test file | `test/rules/` contains only `posts_joint.rules.test.mjs`. Everything else is string-contract-tested only — it asserts the rules *text*, not the rules *behavior*. | 3 |
| P13 | Two state paradigms coexist | 343 `setState` calls alongside 178 `ref.watch` calls in a Riverpod app. | 4 |
| P14 | Animation disposal unverified | 89 `AnimationController` vs 62 `void dispose()`. Not automatically a leak (one dispose can free several), but the gap needs per-file verification. | 2 |
| P15 | Long-list rendering risk | 32 `SingleChildScrollView` and 5 non-builder `ListView(` vs 14 `ListView.builder`. A `SingleChildScrollView` + `Column` over a Firestore list builds every child eagerly. | 2 |

**Already healthy — do not "fix":**
- `flutter analyze` → **No issues found.** Keep it that way; every phase re-runs it.
- R8/ProGuard: `isMinifyEnabled = true`, `isShrinkResources = true`, release signing has no debug fallback. Done in a prior pass.
- App Check: correctly routed through `app_runtime_config.dart`, hardened providers in prod.
- `.env*` no longer bundled (only `.env.example` remains) — prior audit item resolved.
- Firestore rules contain no `if true` grants.

---

## Phase Ordering Rationale

Ordered by **(user-visible impact × cost impact) ÷ risk of regression**. Cheap high-certainty wins first so momentum is real; god-file refactors last because they carry the most regression risk and benefit from the test coverage added earlier.

---

## Phase 0: Complete the Audit

**Deliverable:** `docs/audits/2026-08-03-deep-audit-findings.md` — every finding, counted, with file:line evidence and a severity.

Pre-flight covers breadth. Phase 0 adds the depth that greps cannot reach.

- [ ] **0.1 — Firestore read/write cost map.** For each of the 102 `.get()` sites and 28 `StreamProvider`s, record: collection, whether bounded, whether it runs on app start, whether it re-runs on rebuild. Flag every unbounded read of a collection that grows with user activity (`posts`, `notifications`, `workouts`, `sessions`).
- [ ] **0.2 — N+1 query hunt.** Grep for `await` inside `for`/`forEach` inside `lib/services/`. Two candidates already spotted: `exercise_catalog_service.dart:345-346`, `user_service.dart:556-558`. Verify each: is it a per-item Firestore round-trip, and can it become one `whereIn` batch or a `Future.wait`?
- [ ] **0.3 — Cold-start trace.** Read `lib/main.dart` (179 lines, small enough to read whole) plus every provider it eagerly initializes. Record what blocks first frame vs what could be deferred.
- [ ] **0.4 — Rebuild-scope audit.** For each of the 8 god files, locate `ref.watch` calls placed in the top-level `build()` of a large widget. Each one rebuilds the entire subtree on any change. Record the widget, the provider, and the subtree size.
- [ ] **0.5 — UX flow walk.** For the five primary flows (onboarding → auth, start session, live session room, recap → post, feed) record: loading states present?, empty states present?, error states recoverable or dead-end?, back-navigation safe?, destructive actions confirmed?
- [ ] **0.6 — Cloud Functions review.** `functions/index.js` is 826 lines with 5 exported functions, two of which are 15-minute schedulers. Check: idempotency, unbounded query risk in the schedulers, error swallowing, and cost of `every 15 minutes` at current scale.
- [ ] **0.7 — Dependency review.** 40 direct dependencies. Identify unused ones, ones pinned without a floor reason, and ones with known-better replacements. `flutter pub outdated` for the version picture. **Do not upgrade anything in this phase** — record only. (`cloud_firestore: 6.6.0` is pinned deliberately; leave it.)
- [ ] **0.8 — Write the findings doc**, severity-ranked (Critical / High / Medium / Low), each finding with evidence and a proposed fix. Commit it.

**Gate:** Findings doc committed before any Phase 1+ code change.

---

## Phase 1: Ship-Size & Build (cheapest wins, zero behavior risk)

- [ ] **1.1** Replace the wholesale `- assets/` declaration in `pubspec.yaml` with an explicit file list containing only referenced assets. Verify each candidate is genuinely unreferenced with a repo-wide grep before dropping it.
- [ ] **1.2** Move `app_icon.png` and unused splash variants out of the shipped asset path (keep them in the repo under a non-bundled dir, e.g. `design/`, so `flutter_launcher_icons` and future design work still have them).
- [ ] **1.3** Compress the remaining shipped PNGs (`splash_z_v5.png` 336K, `splash_background.png` 184K). Target: lossless or visually-lossless, ≥40% reduction.
- [ ] **1.4** Measure: `flutter build appbundle --analyze-size` before and after. Record the delta in the findings doc.
- [ ] **1.5** `flutter analyze` + full test suite green. Commit.

**Expected outcome:** ~2 MB smaller download, no behavior change.

---

## Phase 2: Runtime Performance & Firestore Cost

Each item is driven by the Phase 0 findings doc, not by guesswork.

- [ ] **2.1** Add `.limit()` to every unbounded read flagged in 0.1 that targets a growth collection. Where the UI needs more than the limit, add pagination rather than raising the cap.
- [ ] **2.2** Convert eligible providers to `autoDispose` — starting with every `StreamProvider` that backs a single screen. A provider that outlives its screen holds a Firestore listener and bills for it. Keep app-lifetime providers (auth, connectivity, offline manager) non-disposing and document why in a comment.
- [ ] **2.3** Fix the N+1 sites confirmed in 0.2 — batch via `whereIn` (≤30 per batch on the current SDK) or `Future.wait`.
- [ ] **2.4** Narrow rebuild scope for the worst offenders from 0.4: push `ref.watch` down into `Consumer` widgets wrapping only the subtree that depends on it, and add `const` constructors to the static subtrees that fall out.
- [ ] **2.5** Convert the `SingleChildScrollView` + `Column` / non-builder `ListView` sites that render data-driven lists (from 0.1/P15) to `ListView.builder` or slivers. Leave static-content scrollers alone.
- [ ] **2.6** Verify every `AnimationController` from P14 is disposed. Fix any that are not.
- [ ] **2.7** Defer everything from 0.3 that does not block first frame.
- [ ] **2.8** Add a performance regression test to `test/performance/` capturing the frame-build cost of the feed and the session room.
- [ ] **2.9** `flutter analyze` + full suite green. Commit per sub-area, not as one blob.

---

## Phase 3: Observability & Security Hardening

- [ ] **3.1** Wire real crash reporting (`firebase_crashlytics`), replacing the TODO at `global_error_handler.dart:44`. Must record non-fatals too, and must not swallow the error — the current `return false` from `PlatformDispatcher.onError` is correct and stays.
- [ ] **3.2** Confirm no PII (email, display name, message bodies, photo URLs) reaches crash reports. Scrub before recording.
- [ ] **3.3** Expand `test/rules/` from one emulator test file to behavioral allow/deny coverage of the high-risk collections: `users`, `posts`, `sessions`, `buddyPairs`, `notifications`, `leaderboard`. Each needs at least one allow case and one deny case per operation the rules grant. This is the biggest remaining security-verification gap (P12).
- [ ] **3.4** Review the 5 Cloud Functions against 0.6 findings: bound the scheduler queries, confirm idempotency, confirm errors surface rather than silently drop.
- [ ] **3.5** Audit `debugPrint` (227 call sites) for leaked user data in release builds. `debugPrint` is stripped in release only if wrapped in `kDebugMode` — verify, don't assume.
- [ ] **3.6** `flutter analyze` + full suite + emulator rules tests green. Commit.

---

## Phase 4: Architecture — God Files & State Consistency

Highest regression risk. Deliberately after Phase 3, so the new tests catch what the refactor breaks.

- [ ] **4.1** For each of the 8 god files (P4), map its responsibilities before touching it. Split only along responsibility seams the map reveals — never "split at line 1500 because it's halfway".
- [ ] **4.2** `session_room_page.dart` (3750) first — it is the app's most complex screen and the one most recently modified. Extract per-mode views, per-phase widgets, and the controller logic into separate files under `lib/features/session/presentation/widgets/` and `.../controllers/`, following the existing `active_turn_screen.dart` / `waiting_turn_screen.dart` precedent already in the tree.
- [ ] **4.3** `profile_page.dart` (3006) second — same treatment.
- [ ] **4.4** Resolve the dual-paradigm problem (P13) *within the files being split only*. Local ephemeral UI state legitimately stays `setState`; anything that is shared, derived from Firestore, or read by more than one widget moves to Riverpod. Do not do a repo-wide `setState` purge — that is a rewrite, not an optimization.
- [ ] **4.5** After each split: `flutter analyze` + full suite green, then commit. One file per commit — never batch two god-file splits into one commit.

---

## Phase 5: UI/UX & Design System

- [ ] **5.1** Replace the 145 raw `Color(0x…)` literals (P7) with theme tokens from `app_theme.dart`. Where a literal has no token, add the token — do not invent a one-off.
- [ ] **5.2** Accessibility pass (P3): semantic labels on every icon-only button, image, and progress indicator; `tooltip:` on every `IconButton`; verified minimum 48×48 tap targets; contrast check against WCAG AA on the dark theme.
- [ ] **5.3** Address every gap from the 0.5 UX flow walk — missing loading states, missing empty states, dead-end errors, unconfirmed destructive actions.
- [ ] **5.4** Respect `MediaQuery.textScaler` — verify layouts survive 200% text scale. Only 14 `MediaQuery.of` call sites exist, which suggests scaling was never considered.
- [ ] **5.5** Widget tests for each new empty/error/loading state. Commit per area.

---

## Phase 6: Internationalization Foundation

P2 is a genuine finding but a large mechanical change. Scoped as *foundation only* — full translation is a product decision, not an optimization.

- [ ] **6.1** Set up `flutter_localizations` + `gen_l10n` with an `app_en.arb` baseline.
- [ ] **6.2** Extract strings from the auth/onboarding flow only, as the proving ground.
- [ ] **6.3** Document the extraction pattern in `docs/` so the remaining screens can follow incrementally.
- [ ] **6.4** Do **not** extract all 200 literals in this plan. Note the remaining scope in the findings doc as follow-up work.

**Open question for the user before this phase starts:** is a second language actually planned? If not, Phase 6 drops to "document the pattern, defer the work."

---

## Phase 7: Hygiene & Coverage

- [ ] **7.1** Delete the garbage untracked files in the repo root (P10). Verify each is genuinely a shell artifact — `git status --short` shows ~20 of them with names like `(value`, `,+`, `!author.removed)`. **Confirm the list with the user before deleting**, since they are untracked and unrecoverable.
- [ ] **7.2** Delete `lib/services/auth_service.dart` (P9) and its one remaining reference.
- [ ] **7.3** Add test files for the highest-risk untested services from P11, in this order: `user_service` (badges/streaks — has known N+1), `buddy_service` (pairing transactions), `matchmaking_service`, `moderation_service`, `payment_service`.
- [ ] **7.4** Add `.gitignore` entries that would have prevented P10.
- [ ] **7.5** Final `flutter analyze` + full suite. Commit.

---

## Global Constraints

- `flutter analyze` must report **No issues found** at the end of every phase. It is clean today; a phase that dirties it is not done.
- The full test suite (523 tests as of `2e1d664`) must stay green. New tests add to that count; no test is deleted to make a phase pass.
- `cloud_firestore` stays pinned at `6.6.0`. No dependency upgrades in this plan — Phase 0.7 records them, a separate plan performs them.
- No changes to the two just-shipped features' behavior (joint posts, leaderboard scoring) unless a finding proves a defect. Their scoring invariant — absolute weight must not affect relative score — is non-negotiable and its tests must keep passing.
- Every phase commits incrementally. No phase lands as a single mega-commit.
- Work continues on `006-offline-cache-sync`. Branch integration is the user's call, unchanged.

## Out of Scope

- Dependency version upgrades (recorded in 0.7, performed separately).
- Full i18n string extraction beyond the Phase 6 proving ground.
- A repo-wide `setState` → Riverpod migration.
- New features of any kind.
- The pending AAB release build — that follows this plan, it is not part of it.

## Execution

Phases run in order. Phase 0 gates everything. Each phase is independently committable and independently reviewable; the user can stop after any phase with the project in a better and coherent state than before.
