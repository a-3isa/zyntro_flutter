# T054 device gate — owner runbook (Z-REPO-004)

**Status:** Waiting on physical handset  
**Spec:** `specs/007-resume-active-session/quickstart.md` § Verify it works  
**Task:** `specs/007-resume-active-session/tasks.md` T054

## Why this cannot be automated

Force-close from the OS recent-apps list is the core resume case. Emulators and
widget/integration tests do not faithfully reproduce swipe-kill behavior
(`detached` is often skipped). Automated coverage already exists for the
decision table and rules; this gate is the **manual pre-cutover pass**.

## Pre-flight (any machine)

```bash
flutter analyze
flutter test
# optional: rules + functions suites from docs/CI.md
```

Confirm `expireStaleSessions` (or current expiry function) is deployed to the
Firebase project used for the handset build.

## Device matrix (minimum)

| Device | OS | Build |
| --- | --- | --- |
| 1× Android physical | API 33+ | debug/profile APK signed for that package |
| 1× iOS physical (if shipping iOS) | latest shipping iOS | TestFlight or Xcode run |

Two authenticated test accounts (A host, B invitee) for paired paths.

## Scenario checklist

Copy into the evidence note and tick on-device:

- [ ] **US1** Start gym → log set → home → swipe kill → reopen → back in session, set intact, no prompt
- [ ] **US2** A+B turn-based → B swipe-kill → A continues without waiting on B → B avatar "away" → B reopen restores shared turn order
- [ ] **US3 quiet** Log set → swipe-kill → wait 15+ min (or backdate `lastActivityAt`) → reopen → continue/discard prompt on home
- [ ] **US3 expiry** Swipe-kill → expire session (`expiresAt` past + scheduled function) → reopen shows expiry notice; sets retained
- [ ] **Partner left** A terminates → B in-room dialog (finish/carry-on) → dismiss keeps session; A shows "left"
- [ ] **Partner left offline** A terminates while B closed → B reopen sees single notification / in-room choice from `endedParticipants` (no stack)

## Evidence packet (attach to close T054)

Create `docs/evidence/t054-YYYY-MM-DD.md` (or a private ticket) with:

1. Device model + OS build  
2. App version / git SHA tested  
3. Firebase project id  
4. Pass/fail per scenario above (screenshot or screen recording optional)  
5. Tester name + date  

Then:

1. Check the box for **T054** in `specs/007-resume-active-session/tasks.md`  
2. Set audit finding `Z-REPO-004` → `closed` with `closed_in` pointing at the evidence file  
3. Unblock 007 cutover only after this packet lands

## Agent / CI note

Do **not** mark Z-REPO-004 closed from an agent session without the evidence
packet. Dispatch-only `integration-smoke` (Z-TEST-005) is complementary, not a
substitute for T054.
