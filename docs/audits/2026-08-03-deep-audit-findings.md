# Zyntro Deep Audit — Findings

**Date:** 2026-08-03
**Branch:** `006-offline-cache-sync` (at `a0a70cd`)
**Scope:** whole project — architecture, performance, Firestore cost, UI/UX, accessibility, i18n, security, build, tests, hygiene
**Plan:** [2026-08-03-project-wide-audit-optimization.md](../superpowers/plans/2026-08-03-project-wide-audit-optimization.md)

Every finding below is backed by a counted grep or a `file:line` reference. Impressions are excluded.

## Baseline

| Metric | Value |
|---|---|
| Dart source | 171 files · 62,935 lines |
| Tests | 84 files · 523 passing |
| `flutter analyze` | **No issues found** |
| Firestore rules | 537 lines · 17 composite indexes |
| Cloud Functions | 826 lines · 5 exports |
| Shipped assets | 3.0 MB |
| Direct dependencies | 40 |

**Already healthy — do not regress:** R8/ProGuard minify + resource shrink enabled with no debug-signing fallback; App Check hardened via `app_runtime_config.dart`; no `if true` grants in Firestore rules; `.env*` no longer bundled; analyzer clean.

---

## Critical

### C1 — Unbounded Firestore reads on collections that grow forever

The dominant cost and latency defect in the app. These queries have no `.limit()` and read **every** matching document, so cost and latency grow linearly with a user's history for as long as they use the app.

| Site | Reads | Growth driver |
|---|---|---|
| `lib/services/workout_service.dart:224` | every workout a user has ever logged | every session |
| `lib/services/workout_service.dart:234` | every workout of one type, ever | every session |
| `lib/services/user_service.dart:203` | every completed session (streak calc) | every session |
| `lib/services/user_service.dart:591` | every completed session, **again**, inside a loop | every session |
| `lib/services/user_service.dart:605` | every cheer event in a session | every cheer |
| `lib/services/session_analytics_service.dart:391` | every `photo_upload_completed` analytics row, ever | every upload |
| `lib/services/session_analytics_service.dart:397` | every `photo_upload_failed` analytics row, ever | every failure |
| `lib/services/session_service.dart:1350` | every `setLogged` event in a session | every set |
| `lib/services/session_service.dart:1371` | every `setLogged` event, again | every set |
| `lib/services/session_service.dart:1395` | every event in a session | every action |
| `lib/services/post_service.dart:861` | every reaction on a post | every like |
| `lib/services/post_service.dart:899` | every reaction on a post, again | every like |
| `lib/services/moderation_service.dart:88` | every report a user filed | every report |
| `lib/services/moderation_service.dart:184` | every pending report, globally | platform-wide |

**Live listeners on unbounded sets** — worse than a one-shot read, because they re-bill on every write to the set:

| Site | Listener over |
|---|---|
| `lib/services/follow_service.dart:349` | all approved followers |
| `lib/services/follow_service.dart:370` | all approved followees |
| `lib/services/presence_service.dart:185` | all presence docs in a session |
| `lib/services/presence_service.dart:155` | all online users |
| `lib/services/post_service.dart:1009` | all comments on a post |
| `lib/services/session_service.dart:1269` | all events in a session |

`post_service.dart:899` (`getPostLikes`) is unbounded while its own sibling `getPostReactions` at `:875` correctly caps at `limit: 100` — the inconsistency is inside one file, twenty lines apart.

`getReactionCounts` (`post_service.dart:857`) reads every reaction document only to count them. The codebase already knows the fix — `follow_service.dart:339` uses `.count()` aggregation, which bills as a single read regardless of set size.

`user_cache_service.dart:192` carries the comment `// This costs reads!` — the cost was noticed and never addressed.

**Fix:** `.limit()` + pagination on every one-shot read; `.count()` aggregation wherever the result is only used for a count; bounded windows on every live listener.

---

### C2 — N+1 Firestore query inside the badge-award loop

`lib/services/user_service.dart:558-612`. The loop iterates `availableBadges` and issues a **full unbounded collection query per badge**:

- `BadgeCriteriaType.buddySessions` (`:588-593`) re-reads *every completed session the user has ever had* — once per badge of that type.
- `BadgeCriteriaType.cheersSent` (`:600-606`) queries session events — once per badge of that type.

`calculateUserStreak` at `:556` has *already* read the same full session history one line earlier. So ending a single workout can re-scan a user's entire session history three or more times.

Compounding: the whole block ends in

```dart
} catch (e) {
  // Silent fail for badge checks
}
```

Any failure — including a quota error caused by this very pattern — is swallowed with no log, no metric, and no user signal.

**Fix:** hoist the session query out of the loop and compute all criteria from one snapshot; replace the silent catch with a logged non-fatal.

---

### C3 — Crash reporting is not wired

`lib/utils/global_error_handler.dart:44` — `// TODO: Report to Crashlytics`, with the implementation commented out beneath it. No Crashlytics, no Sentry, no alternative anywhere in `lib/` or `pubspec.yaml`.

Production failures are currently invisible. Every other finding in this document is a hypothesis that cannot be confirmed against real user impact until this is fixed. The prior audit (2026-03-30) listed this as a residual risk; it is still open.

The existing `return false` from `PlatformDispatcher.instance.onError` is correct and must stay — errors are rethrown rather than swallowed.

---

## High

### H1 — Firestore rules are 537 lines with essentially no behavioral test coverage

`test/rules/` contains exactly one emulator test file: `posts_joint.rules.test.mjs`. Everything else is covered by `test/firebase/firestore_rules_contract_test.dart`, which asserts the *text* of the rules file, not its *behavior*. A rule can be rewritten to grant strictly more access and still pass a string-contract test.

Uncovered, security-relevant collections: `users`, `sessions`, `buddyPairs`, `notifications`, `leaderboard`, `follows`, `blocks`, `reports`.

Flagged as "Cleanup" in the 2026-03-30 audit; it is the largest remaining security-verification gap and belongs at High.

### H2 — 98 providers, 4 `autoDispose`; 28 of them are `StreamProvider`s

A non-disposing `StreamProvider` keeps its Firestore listener alive for the entire app session, billing for every write to the watched set, long after the screen that needed it is gone.

Worst concentration — `lib/features/profile/presentation/profile_page.dart:838-842` watches **five** `StreamProvider`s in a single `build()`:

```dart
final streakAsync    = ref.watch(userStreakProvider(targetUserId));
final sessionsAsync  = ref.watch(userSessionsProvider(targetUserId));
final followersAsync = ref.watch(followersCountProvider(targetUserId));
final followingAsync = ref.watch(followingCountProvider(targetUserId));
final postsAsync     = ref.watch(userPostsProvider(targetUserId));
```

All five are `.family` providers keyed by user id, so **visiting N profiles leaves 5N live listeners running**. Two of them (`followersCountProvider`, `followingCountProvider`) are backed by the unbounded listeners in C1.

`session_room_page.dart:2881-2885` watches three providers at the top of a 3,750-line widget's `build()` — any one Firestore event rebuilds the entire screen.

**Fix:** `autoDispose` on every screen-scoped provider; keep app-lifetime providers (auth, connectivity, offline manager) non-disposing with a comment stating why. Push `ref.watch` down into `Consumer`s wrapping only the dependent subtree.

### H3 — Cold start blocks first frame on three deferrable initializations

`lib/main.dart:28-101` awaits eight things before `runApp()`. Three of them do not gate the first frame:

- `:76` `notificationServiceProvider.init()`
- `:83` `storageServiceProvider.init()`
- `:90` `registerOfflineHandlers(container)`

They run **serially**, each in its own `try`/`await`. Firebase init, `.env` load, App Check activation and `SharedPreferences` legitimately precede `runApp()`; these three do not.

**Fix:** move all three after `runApp()`, or run them concurrently via `Future.wait` — the user sees UI while they complete.

### H4 — Eight god files concentrate the app's complexity

| File | Lines |
|---|---|
| `lib/features/session/presentation/session_room_page.dart` | 3,750 |
| `lib/features/profile/presentation/profile_page.dart` | 3,006 |
| `lib/features/session/presentation/start_session_page.dart` | 1,805 |
| `lib/features/session/presentation/recap_page.dart` | 1,755 |
| `lib/services/session_service.dart` | 1,745 |
| `lib/features/social/presentation/social_page.dart` | 1,523 |
| `lib/widgets/post_card_widget.dart` | 1,518 |
| `lib/features/feed/presentation/post_detail_page.dart` | 1,472 |

Together, 8 of 171 files hold 25% of the codebase. These are also the files where the last three features landed, so they are actively growing. `session_room_page.dart` alone exceeds what can be held in context for reliable editing.

The tree already has the right precedent — `active_turn_screen.dart` (711) and `waiting_turn_screen.dart` were extracted from the session flow. The pattern exists; it just was not continued.

### H5 — Accessibility is effectively absent

13 `Semantics(` and 13 `tooltip:` across 62,935 lines. Icon-only buttons, avatars, progress rings, and chart widgets carry no semantic labels, so a screen-reader user gets unlabeled tap targets.

Only 14 `MediaQuery.of(context)` call sites exist in the whole app, which strongly suggests `textScaler` was never considered — layouts are unverified at large text sizes, an accessibility setting with real adoption.

---

## Medium

### M1 — ~1.9 MB of unused art ships in every build

`pubspec.yaml` declares assets with a wholesale `- assets/` glob, so the entire directory ships:

| File | Size | Referenced? |
|---|---|---|
| `app_icon.png` | 532K | build-time only (`flutter_launcher_icons`) |
| `splash_option_3.png` | 508K | no |
| `splash_logo.png` | 508K | no |
| `splash_human_v3.png` | 468K | no |
| `splash_z_v4.png` | 400K | no (superseded by v5) |
| `splash_z_v5.png` | 336K | **yes** |
| `splash_background.png` | 184K | **yes** |

Roughly 1.9 MB of the 3.0 MB asset payload is dead weight in every download.

### M2 — Design system is bypassed in 145 places

145 raw `Color(0x…)` literals despite a 687-line `lib/core/theme/app_theme.dart` and a dedicated "Design Tokens & Theme System" module. Every literal is a place a future theme change silently fails to reach.

### M3 — Two state paradigms coexist

343 `setState` calls alongside 178 `ref.watch` calls in a Riverpod app with 98 providers. Some `setState` use is legitimate (local ephemeral UI state); the risk is state that is *also* in a provider being mutated locally, which produces stale reads that are hard to trace. Needs per-site classification, not a blanket migration.

### M4 — Async UI states are unevenly handled

63 async providers (28 `StreamProvider` + 35 `FutureProvider`) but only 26 `.when(` call sites and 23 `error:` handlers. Only 6 files reference any empty-state widget. Loading is well covered (143 indicators); **empty and error states are not**.

### M5 — Long lists render eagerly

32 `SingleChildScrollView` and 5 non-builder `ListView(` versus 14 `ListView.builder`. Where a `SingleChildScrollView` + `Column` renders a Firestore-backed list, every child is built and laid out up front regardless of viewport — the classic source of scroll jank on the feed and profile screens. Each site needs classification: static content is fine, data-driven content is not.

### M6 — `expireStaleJointPostDrafts` processes serially

`functions/index.js:782-806`. The query is correctly bounded at `.limit(400)`, but the body then `await`s per document *and* per confirmed author inside nested loops. At the 400-document cap that is 400+ sequential round-trips in one invocation, which risks the function timeout and delays expiry past the 15-minute schedule.

The sibling `expireStalePairedInvites` (`:671`) does this correctly with a single batched commit.

**Both schedulers are otherwise well built** — bounded, status-guarded (idempotent), and they log their counts.

### M7 — 11 of 26 services have no test file

Untested: `payment_service`, `media_service`, `moderation_service`, `presence_service`, `storage_service`, `matchmaking_service`, `workout_service`, `user_service`, `buddy_service`, `content_filter_service`, `username_service`, `voice_recording_service`.

`user_service` (C2's N+1 lives there), `buddy_service` (pairing transactions), and `payment_service` are the highest-risk gaps.

### M8 — Zero internationalization

200 `Text('…')` literals; zero hits for `AppLocalizations` or `S.of(context)`; no `l10n` configuration. Not a defect today if English-only is intentional, but every screen shipped without the pattern raises the eventual cost.

---

## Low

### L1 — Dead compatibility shim still present
`lib/services/auth_service.dart` — 12 lines, 1 remaining reference. Open item from the 2026-03-30 audit.

### L2 — Repo root polluted with shell-redirect artifacts
~20 untracked files with names like `(value`, `,+`, `!author.removed)`, `[]`, `_isLoading`, `p.id)` — malformed redirects from prior sessions. `.gitignore` would not have caught them because the names are arbitrary.

### L3 — `debugPrint` usage unverified for release
227 call sites. `debugPrint` is not automatically stripped in release builds; only `kDebugMode`-guarded calls are. Needs a check for user data (emails, display names, tokens) reaching release logs.

### L4 — Animation disposal unverified
89 `AnimationController` versus 62 `void dispose()`. Not necessarily a leak — one `dispose()` can free several controllers — but the gap warrants per-file verification.

### L5 — `exerciseCatalog` fetched unbounded
`exercise_catalog_service.dart:290` reads the full active catalog. Bounded in practice by catalog size, but it is a good caching candidate rather than a repeated network read.

---

## Explicitly Not Findings

- **`.doc(id).get()` sites.** 102 `.get()` calls exist, but the large majority are single-document reads, which are correctly bounded. Only the collection queries listed in C1 are defects.
- **`whereIn: chunk` queries.** `follow_service.dart:255`, `user_cache_service.dart:118`, `leaderboard_service.dart:85`, `facebook_link_service.dart:179` all chunk correctly and are bounded by design.
- **Dependency versions.** 40 direct dependencies recorded; no upgrade is proposed here. `cloud_firestore` is pinned at `6.6.0` deliberately. Upgrades belong in their own plan with their own regression pass.
- **Comment-related dead code.** `post_service.dart` comment APIs are `@Deprecated` with an explicit "disabled for MVP" note — intentional, not rot.

---

## Priority Order

1. **C3** — crash reporting, because it makes everything else measurable.
2. **C1 + C2** — unbounded reads and the N+1, the direct cost and latency defects.
3. **M1** — asset bloat, a zero-risk 1.9 MB win.
4. **H2 + H3** — provider lifecycle and cold start.
5. **H1** — behavioral rules tests.
6. **H5 + M2 + M4** — accessibility, design tokens, empty/error states.
7. **H4 + M3** — god-file splits, once the tests above exist to catch regressions.
8. **M6, M7, L1-L5** — hardening and hygiene.
9. **M8** — i18n foundation, pending the user's answer on whether a second language is planned.
