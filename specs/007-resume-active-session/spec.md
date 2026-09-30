# Feature Specification: Resume Active Session on App Re-entry

**Feature Branch**: `007-resume-active-session`
**Created**: 2026-08-05
**Status**: Draft
**Input**: User description: "i want that if the user has an active session and he exsits the app and reentered the app again he directly gets directed to the session again to continue it"

## Clarifications

### Session 2026-08-05

- Q: How long after a session's last recorded activity should it stop triggering an automatic return? → A: 3 hours
- Q: What counts as "activity" for the purpose of that 3-hour clock? → A: Any participant's recorded work or session state change (set logged, turn passed, plan committed, invite accepted)
- Q: Which session stages should trigger the automatic redirect? → A: Live only — a session still being set up lands the member on the home screen instead. *(Refined against the code 2026-08-05: there is no wrap-up stage. A session has exactly two stages, setup and live; a wrapped-up session is a completed one, which the live-only rule already excludes.)*
- Q: How long should dismissing a resumed session suppress the automatic redirect? → A: **Question void.** There is no such thing as dismissing a session. A member cannot leave the session screen without terminating the session, so no "walked away but still live" state exists and no dismissal record is needed.
- Q: What is the concrete trigger this feature must handle? → A: A cold start — the member taps the device home button, swipes the app out of the recent-apps list, then reopens it. Warm returns from the background need no redirect because the app already restores to the session screen.
- Q: In a shared session, what does one member terminating do to the other? → A: Terminating is per-member only. The member who terminates leaves; the session stays live for the remaining participant, who is still resumable.
- Q: What happens to a session nobody ever terminated, once it goes stale? → A: It cannot stay alive. A session ends automatically once 3 hours pass with no recorded activity, or 3 hours pass with no participant present in the session room — whichever comes first. A member returning after that is told what happened to it.
- Q: Direct redirect or a "Finish or discard?" prompt inside the 3-hour window? → A: Both, split on how alive the session is. Direct redirect when the session is genuinely alive — activity within the last 15 minutes, or a partner currently present. Prompt when it is quiet and the room is empty but still inside the window.
- Q: Per-member termination does not exist in the code — build it here, or defer it? → A: Build it. Terminating ends the session for the terminating member only; the remaining participant is notified their partner left and decides whether to finish too or keep going.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Return to a live workout after leaving the app (Priority: P1)

A member is mid-workout in a live session. Between sets they press the device home button and swipe the app out of the recent-apps list — or the phone runs low on memory and the operating system kills the app for them. Either way the app is gone from memory. When they open it again, they land straight back in their live session, at the same point they left it, with everything they already logged still there. They do not pass through the home screen and do not have to hunt for the session.

**Why this priority**: This is the core of the request and the single highest-value slice. Because terminating is the only way out of the session screen, a member whose app was killed mid-workout currently has no path back to that workout at all — reopening drops them on the home screen while the session sits live and unreachable. Shipping only this story already delivers a complete, useful improvement.

**Independent Test**: Start a live session, log at least one set, force-close the app from the recent-apps list, reopen it, and confirm the member arrives on the live session screen with the previously logged work intact — without any other story being implemented.

**Acceptance Scenarios**:

1. **Given** a member is in a live session with logged sets and logged one within the last 15 minutes, **When** they press the device home button, swipe the app out of the recent-apps list, and reopen it, **Then** they are placed on the live session screen showing all previously logged work, with no prompt.
2. **Given** a member is in a live session, **When** they background the app without killing it and return to it, **Then** they are still on the session screen, with no redirect needed.
3. **Given** a member is in a live session, **When** the operating system reclaims the app in the background and they reopen it, **Then** they are taken to the live session screen instead of the app's home screen.
4. **Given** a member is in a live session, **When** they reopen the app after killing it, **Then** no work they had already recorded is lost or duplicated.
5. **Given** a member is in a live session, **When** they reopen the app after killing it, **Then** they are returned to the same point in the session they left (same exercise and set), not to the beginning.

---

### User Story 2 - Return to the correct place in a shared session (Priority: P2)

Two members are working out together. One of them closes the app mid-session. **Neither side is punished for it.** The one who stayed keeps training — the session quietly becomes solo for them, and they are never left staring at a "waiting for your partner" screen while their partner is gone. The one who left comes back to the session in the role and view that is correct *right now*, with everything their partner did in the meantime already reflected.

**Why this priority**: Shared sessions are the app's differentiator, and both failure modes here are severe. Returning to a stale or wrong-role view can make a member log a set out of turn; being made to wait on a partner who closed their app stalls the remaining member's whole workout. It ranks below P1 only because it depends on the same return mechanism and adds correctness on top of it.

**Independent Test**: Run a two-member session, close one member's app, and confirm the other can keep logging sets with no waiting state. Then reopen the first member's app and confirm they land in the view matching the session's current state, with the solo work visible.

**Acceptance Scenarios**:

1. **Given** a member is in a shared session and it becomes their turn while the app is closed, **When** they reopen the app, **Then** they are shown their active turn, not the waiting view.
2. **Given** a member is in a shared session and their partner logged work while the app was closed, **When** they reopen the app, **Then** the partner's progress is visible without a manual refresh.
3. **Given** two members are training in parallel in the same session, **When** one reopens the app, **Then** they are returned to their own side of the session.
4. **Given** a member left the app while the session was still being set up and waiting on their partner, **When** they reopen the app, **Then** they land on the home screen — not the setup step — and the pending session is still reachable from there.
5. **Given** a turn-based session where one member has closed their app, **When** the remaining member finishes their turn, **Then** the turn is not handed to the absent member — the remaining member continues straight into their next set with no waiting screen.
6. **Given** a member is training on while their partner is away, **When** they look at the session, **Then** the partner reads as temporarily away, clearly distinct from a partner who has left for good.
7. **Given** a member logged several sets while their partner was away, **When** the partner reopens the app, **Then** the session returns to shared, normal turn order resumes from where it now stands, and the solo work is visible to the returning member.
8. **Given** one member is training on while the other is away, **When** 3 hours pass from the session's start, **Then** the session has not expired — the solo member's logged work kept it alive.

---

### User Story 3 - Not being dragged into a session that is over (Priority: P3)

A member's session is behind them — they terminated it, or they force-closed the app during a workout yesterday and never came back to it. Reopening the app must not drag them into a workout they have finished with. A session that has been quiet with nobody in it asks before pulling them back in; one that has been dead for hours has already ended, and they are simply told so.

**Why this priority**: This is the safety valve. Because a member can only leave the session screen by terminating, a session abandoned via force-close would otherwise sit live in the data with nobody in it, hijacking every future app launch. It is P3 because P1 and P2 deliver value on their own, but this story must ship before the feature is considered complete.

**Independent Test**: Force-close the app during a live session, wait past 3 hours, reopen, and confirm the session has ended and the member is told why; separately return after 40 minutes and confirm they are asked rather than redirected.

**Acceptance Scenarios**:

1. **Given** a session has had no activity and no one present for more than 3 hours, **When** the member reopens the app, **Then** the session has already ended, they land on the home screen, and they are told it ended because it was left inactive.
2. **Given** a session has been quiet for 40 minutes with nobody in the room but is still inside the 3-hour window, **When** the member reopens the app, **Then** they are not redirected — they are asked whether to continue or discard the session.
3. **Given** that prompt is shown, **When** the member chooses discard, **Then** their participation ends, they stay on the home screen, and any partner still in the session is unaffected.
4. **Given** a member terminated their session, **When** they reopen the app, **Then** they land on the home screen and are never redirected into that session again.
5. **Given** a member is in the session room when their partner terminates, **When** the termination lands, **Then** a dialog tells them their partner left and offers finish-too or carry-on, without ejecting them from the session.
6. **Given** that dialog is showing, **When** the member dismisses it without choosing, **Then** the session continues as if they chose carry on, and their partner's avatar now renders in a "left" style wherever it appears.
7. **Given** the member dismissed the dialog, **When** the screen rebuilds or they return to the session later, **Then** the dialog does not reappear — the avatar's "left" style is what tells them from then on.
8. **Given** a member had the app closed when their partner terminated, **When** they reopen the app, **Then** the notification telling them their partner left is waiting in their notification list.
9. **Given** a member reopens the app several times before reading it, **When** they check their notification list each time, **Then** the same single notification is there — never a stack of duplicates for one departure.
10. **Given** a member never received that notification — phone off, no signal, or they dismissed it, **When** they next open the session, **Then** they are still told their partner left and still get the choice.
11. **Given** a member is offered the choice, **When** they pick carry on, **Then** the session stays live and they finish alone; **When** they pick finish too, **Then** the session completes normally with their work recorded.
12. **Given** a member's session was cancelled or they were removed from it while away, **When** they reopen the app, **Then** they land on the home screen and are told what happened to the session.

---

### Edge Cases

- **Notification or shared-link entry**: The member opens the app by tapping a notification or following a link that points somewhere specific. The explicit destination wins; automatic session return must not override it.
- **Signed out, or session belongs to another account**: The member is not signed in, or signs in as a different account, on relaunch. No automatic return happens until an authenticated member is confirmed to own the session.
- **Onboarding not finished**: A member who has not completed sign-up or onboarding is never pulled into a session ahead of those flows.
- **No connectivity on relaunch**: The member reopens the app with no network. They are still returned to their session using the most recently known state, clearly marked as not-yet-synced, rather than being blocked or bounced home.
- **Session finished while away**: The session was completed while the member was gone. No redirect happens — they land on the home screen, where the recap is reachable.
- **More than one candidate session**: The member is somehow attached to more than one unfinished session. Only one is offered — the one with the most recent activity.
- **Work lost mid-entry**: The member was part-way through entering a set (reps counted but not submitted) when the app was killed. Only recorded, committed work is guaranteed to survive; the partially entered set is not.
- **Repeated force-closing**: The member kills and reopens the app several times in quick succession. Each cold start lands them in the session without flicker, duplicate navigation, or loss of place.
- **Partner terminated while away**: The member force-closed the app; their partner then terminated. On reopening, the member is still returned to the session, sees that their partner has left, and can finish alone.
- **Partner away exactly when the turn would pass**: The remaining member finishes a set at the moment their partner's presence goes stale. The turn must resolve one way or the other, never into a state where nobody holds it.
- **Partner returns mid-set**: The away member reopens the app while the remaining member is part-way through a set. The set in progress completes uninterrupted; turn order resumes at the next handover, not by seizing the current one.
- **Both members away, then one returns**: Nobody is present for a while, then one member reopens inside the 3-hour window. They resume as a solo session and can keep training; the other is still merely away, not gone.
- **Partner flickers between away and present**: A weak connection makes presence lapse and recover repeatedly. The session must not oscillate between solo and shared views on every flicker.
- **Both participants force-closed**: Neither member terminated, and nobody returns. The session ends on its own once 3 hours pass with an empty room, and each member is told what happened on their next cold start.
- **Prompt appears, member ignores it**: The member is asked whether to continue or discard, and does neither — they navigate elsewhere in the app. The session is left untouched and still live, and they are not asked again until their next cold start.
- **Session goes warm while the prompt is showing**: The partner starts logging sets just as the member is being asked. The prompt stays as-is rather than switching to a redirect mid-decision; continuing puts the member into the now-active session.
- **Expiry falls due while the app is closed**: The 3-hour limit passes with the app not running. The session must still be ended, and the member told on their next cold start — expiry cannot depend on the member's app being open to notice it.
- **Return during the recap flow**: The member left the app while writing a post-session recap or shared post. The session is already completed, so it is not resumable and no redirect happens — they land on the home screen and the unfinished recap is not force-reopened.
- **Session goes live while away**: The member left during setup and their partner accepted, moving the session to live, before they returned. The session is now resumable and the member is redirected into it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: On every cold start of the app — including a start that follows the member force-closing the app from the recent-apps list, or the operating system reclaiming it in the background — the system MUST determine whether the signed-in member has a resumable session before showing the default landing screen.
- **FR-001a**: A warm return from the background, where the app was not killed, MUST restore the member to whatever screen they were on with no redirect logic applied.
- **FR-002**: A session MUST be considered resumable only when all of the following hold: it is in the **live** stage; it has not been cancelled; the member is a current participant and has not terminated their own part in it; and it has not expired under FR-007.
- **FR-002a**: A session still being set up MUST NOT trigger an automatic redirect. The member lands on the home screen, from which the pending session remains reachable.
- **FR-002b**: A session that has already been wrapped up MUST NOT trigger an automatic redirect either. A wrapped-up session is one that has been completed — it is not a distinct stage a live session passes through, so FR-002's live-only rule already excludes it. No separate check is required, and none MUST be added.
- **FR-003**: When a resumable session is **warm** — it has recorded activity within the last 15 minutes, or another participant is currently present in the session room — the system MUST take the member directly to it without any tap or confirmation.
- **FR-003a**: When a resumable session is **quiet** — no activity for 15 minutes or more and no other participant present, but still inside the 3-hour window — the system MUST NOT redirect. It MUST instead ask the member whether to continue or discard the session, on the screen they land on.
- **FR-003b**: Choosing to continue MUST place the member in the session exactly as a warm redirect would. Choosing to discard MUST terminate the member's own participation only, under the per-member rule in FR-008, and leave them on the home screen. The prompt MUST be answerable — a member who ignores or closes it MUST NOT be blocked from using the rest of the app, and MUST NOT be asked again until their next cold start.
> **A note on stages.** A session has exactly two live-side stages: **being set up** and **live**. Wrapping up is not a third stage — it is what a session enters once it has been completed, and the recap is a screen the member is taken to, not a state the session sits in. Requirements below say "live only" and mean it literally; nothing needs to test for a wrap-up stage because none exists.

- **FR-004**: The system MUST place the member in the live session view that matches their role at the moment of return — taking their turn, waiting on their partner, or their own side of a parallel workout — reflecting the session's state as it stands now rather than as it was when they left.
- **FR-005**: All work recorded before the member left MUST be present on return, with nothing lost, duplicated, or re-counted.
- **FR-006**: Progress made by other participants while the member was away MUST be reflected on return without a manual refresh.
- **FR-007**: A live session MUST end automatically once either of the following elapses, whichever comes first: 3 hours with no recorded activity, or 3 hours with no participant present in the session room. An expired session MUST NOT be resumable, and MUST NOT remain live in the member's data.
- **FR-007a**: Session activity MUST be measured across all participants, not just the returning member. Recorded work by any participant and any change to session state — a set logged, a turn passed, a plan committed, an invite accepted — MUST reset the 3-hour clock. Merely viewing the session without acting MUST NOT reset the activity clock, though it does count as presence.
- **FR-007b**: When a member's first cold start after a session expired lands them in the app, the system MUST tell them what happened to that session — that it ended because it was left inactive — rather than failing silently. The work they recorded before it expired MUST be preserved.
- **FR-008**: Terminating a session MUST apply to the terminating member only. The session MUST remain live for every other participant, who MUST still be resumable under FR-002.
- **FR-008a**: When a member terminates a shared session, the remaining participant MUST be told their partner has left and MUST be given the choice to finish the session too or carry on alone. Neither choice may be made for them.
- **FR-008b**: A member whose session is live is in exactly one of two states: **in the session room**, or **with the app closed**. There is no third state — leaving the session screen requires terminating, at which point the session is no longer theirs. The message MUST therefore be delivered by exactly two routes, one per reachable state. **Route 1 — notification**, for the closed-app state (see FR-008b-i for how it is delivered and stored). **Route 2 — the session itself**, for the in-room state and as the backstop for both: the departure is recorded on the session, so the choice appears whenever the member opens it. Route 1 is for speed; Route 2 is the guarantee.
- **FR-008b-i**: The notification MUST be stored, not fleeting. A member who was outside the app when it fired MUST find it waiting in their in-app notification list when they come back, and it MUST survive app restarts. Missing the moment it arrives MUST NOT mean missing the message.
- **FR-008b-ii**: The stored notification MUST remain until the member has seen it, and MUST be marked read once they have. Only one notification is created per departure, so returning to the app repeatedly MUST NOT stack up duplicates for the same event.
- **FR-008c**: The two routes MUST NOT be able to disagree. The choice MUST be shown based on what the session records, never on whether a notification arrived. A member whose phone was off, who had no signal, or who dismissed the notification MUST still get the choice on their next return to the session.
- **FR-008d**: Acting on the notification MUST NOT be required. Tapping it takes the member to the session; ignoring it costs them nothing. Tapping counts as an explicit launch destination under FR-010, so it MUST suppress any competing resume redirect rather than compete with it.
- **FR-008e**: FR-008a states the rule; this refines it for the in-room case. A member who is in the session room when their partner leaves MUST be shown a dialog telling them so and offering the finish-too or carry-on choice. The dialog MUST be dismissable — dismissing it MUST be equivalent to carrying on, and MUST NOT end the session or force any choice.
- **FR-008f**: After the dialog is dismissed, the departure MUST remain visible: the partner's avatar MUST render in a distinct "left" style everywhere it appears in the session, for the rest of the session. Dismissing the dialog hides the interruption, never the fact.
- **FR-008g**: The dialog MUST appear once per departure. It MUST NOT reappear on screen rebuilds, on returning to the session later, or on any subsequent cold start — the avatar state carries the information from then on.
- **FR-009**: Once a member terminates a session, that session MUST never trigger an automatic return for that member again. A partner terminating MUST NOT disqualify the remaining participant.
- **FR-010**: An explicit destination supplied at launch — a notification tap or an incoming link — MUST take precedence over automatic session return.
- **FR-010a**: Whether the launch carried an explicit destination MUST be established **before** the resume decision is made. The two MUST NOT race: it must be impossible for the app to begin a resume redirect and then be overridden mid-navigation by a notification tap, or vice versa. If the launch intent cannot be determined, the system MUST assume one exists and skip the resume redirect — the safe failure is landing on the intended destination, never a redirect the member did not ask for.
- **FR-011**: Automatic session return MUST NOT occur before authentication and onboarding are complete, and MUST NOT occur for a session the currently signed-in member does not participate in.
- **FR-012**: When the app is reopened without connectivity, the member MUST still be returned to their session using the most recently known state, with any unsynced work clearly marked as pending.
- **FR-013**: If the session was cancelled or the member was removed from it while they were away, the system MUST land them on the default screen and tell them plainly what happened to the session, through the same notice mechanism as FR-007b — one component, one place, three reasons (expired, cancelled, removed). A partner having terminated is NOT such a case — the session is still the member's to finish.
- **FR-014**: When more than one resumable session exists, the system MUST pick the one with the most recent recorded activity and apply FR-003 or FR-003a to it. The member MUST never be asked to choose between sessions; the only prompt this feature may show is the continue-or-discard prompt for a single quiet session.
- **FR-015**: The return MUST be a single navigation with no intermediate screen flash. An automatically resumed session MUST behave exactly like a session the member entered by hand — including the rule that terminating is the only way out of the session screen — so that resuming leaves no residue in the member's navigation history.
- **FR-016**: If the resumable session cannot be loaded (data unavailable or unreadable), the system MUST fall back to the default landing screen rather than showing an error screen or blocking start-up.

#### Continuing while a partner is away

"Away" means a participant's app is closed but they have **not** terminated. It is temporary and
reversible — unlike leaving, which is permanent (FR-008).

- **FR-017**: A turn-based session MUST NOT stall on an absent participant. When it would become an away member's turn, the turn MUST NOT be handed to them; it MUST stay with, or return to, the participant who is present.
- **FR-018**: While every other participant is away, the session MUST run as a solo session for the member who is present. They MUST NOT be shown a waiting screen, a "waiting for your partner" state, or any other block on continuing. They keep logging sets at their own pace.
- **FR-019**: When an away participant returns, the session MUST revert to shared behaviour and normal turn order MUST resume from the session's current state. Work the present member logged while running solo MUST be preserved and visible to the returning member.
- **FR-020**: Away and left MUST be visually distinct. An away partner MUST read as temporarily absent and MUST NOT be shown in the "left" style of FR-008f, which is reserved for a partner who has terminated.
- **FR-021**: A member MUST be considered away only when their absence is established, not on a momentary connection blip. A member in the session room MUST refresh their presence every **60 seconds**, and a member counts as away once their presence has not been refreshed for **90 seconds** — one missed refresh of tolerance.
- **FR-021a**: The shared → solo transition MUST be delayed by a further **30-second** grace period on top of FR-021's timeout. The solo → shared transition MUST take effect immediately with no grace period. The asymmetry is deliberate: being slow to declare a partner away costs nothing, being slow to notice their return is disruptive.
- **FR-022**: Work the present member logs while running solo MUST count as session activity for the purposes of FR-007, so a session with one active member never expires underneath them.

#### Operability

- **FR-023**: The automatic redirect MUST be switchable off at runtime, without shipping a new build of the app. Turning it off MUST return the app to its pre-feature behaviour for the redirect and the prompt.
- **FR-023a**: Session expiry (FR-007) MUST remain active regardless of that switch. With the redirect off and termination-on-close removed, expiry is the only thing closing sessions; gating it behind the same switch would leak live sessions.
- **FR-024**: Every outcome of the resume decision — redirect, prompt, prompt answer, expiry sweep, partner-left choice, and the FR-016 fallback — MUST be observable in telemetry before the feature is enabled for members.

### Key Entities

- **Session**: A workout in progress, owned by one member and optionally shared with a partner. Carries a stage — **being set up** or **live**, those two only — a status (active, completed, cancelled), a **last-activity time** — the most recent moment any participant recorded work or changed the session's state — and **occupancy**, meaning whether any participant currently has the session room open. Stage, status, and last-activity time decide whether the session is resumable; last-activity time and occupancy together decide whether it is warm (redirect) or quiet (prompt), and when it expires.
- **Participation**: A member's attachment to a session, including their role at the current moment (taking their turn, waiting, or working in parallel), their workout type, and whether they have terminated. Termination is recorded per participant: one member terminating does not change any other participant's attachment, and the session itself stays live as long as at least one participant has not terminated.
- **Recorded work**: Sets, reps, weights, durations, and distances committed during the session. This is what must survive an app restart intact.
- **Resume decision**: The transient judgement made at cold start, with three possible outcomes — redirect straight into the session, ask the member whether to continue or discard, or do nothing and show the home screen. It is derived entirely from session, occupancy, and participation state; no separate dismissal or suppression record exists, because a member cannot leave a live session without terminating it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

Verified before release unless marked otherwise.

- **SC-001**: A member who force-closes and reopens the app during a warm session is returned to it directly, with no prompt, in 100% of attempts — across manual removal from the recent-apps list, operating-system kills, and device restart.
- **SC-002**: The member is on the session screen within 2 seconds of the app becoming usable, on a normal connection, measured from a timestamp captured at app start to the first frame of the session screen and asserted in an automated test.
- **SC-003**: Zero recorded sets are lost or duplicated across an app restart, measured over a full session with at least 10 recorded sets.
- **SC-004**: In shared sessions, the view a returning member lands on matches the session's actual current state in 100% of test runs, including cases where the turn changed while they were away.
- **SC-005**: A member is never redirected into a session they terminated or discarded, or one that was cancelled, expired, completed, or still in setup — 0 false redirects across the abandoned-session test set.
- **SC-006**: A member who terminates their session is never redirected back into it on any subsequent app launch — 0 occurrences across the termination test set.
- **SC-007**: When one member of a shared session terminates, the remaining participant is notified and offered the finish-or-continue choice in 100% of test runs — whether they were in the session room at the time or returning to it later — and can complete the session alone if they choose to.
- **SC-008**: A member whose partner closes their app is never blocked from continuing — 0 waiting states entered on an absent partner, across the turn-based test set — and can log an unbroken run of at least 10 sets while their partner is away.
- **SC-009**: When an away partner returns, the session is shared again and every set logged solo in the meantime is visible to them, in 100% of test runs.
- **SC-010**: Every session left with no activity and nobody present ends within 3 hours — 0 sessions remain live past that point across the expiry test set — and the member is told what happened on their next cold start.
- **SC-011**: Members can resume a session with no network connection and see their pending work clearly marked, in 100% of offline test runs.
- **SC-012**: A launch that carries an explicit destination never triggers a resume redirect — 0 conflicts across the notification-tap and deep-link test set.
- **SC-013**: Turning the runtime switch off returns the app to its pre-feature redirect behaviour without a new build, verified in a rollback rehearsal, while session expiry keeps running.

**Post-launch outcome metric** — measured after release, not a release gate:

- **SC-014**: The share of sessions that are started but never completed falls by at least 20% within 30 days of release, compared with the 30 days before it. Requires the session-abandonment funnel to be instrumented and a baseline captured before rollout.

## Assumptions

Defaults chosen where the request did not specify. Each can be changed without reshaping the feature.

- **A-001 — Direct redirect for warm sessions, prompt for quiet ones** *(confirmed 2026-08-05)*: A session that is genuinely alive redirects with no confirmation, matching the original request ("directly gets directed"). A session that has gone quiet with an empty room asks first, because dropping someone into a workout that has been idle for an hour reads as being dragged somewhere rather than being helped.
- **A-001a — 15-minute warm threshold**: Chosen to cover a long rest between sets or a stretch of scrolling on the phone, while treating anything longer as an interruption the member may not want resumed silently.
- **A-002 — Both solo and shared sessions**: The behaviour applies to sessions the member runs alone and to sessions shared with a partner.
- **A-003 — Live stage only** *(confirmed 2026-08-05)*: Only live sessions trigger the redirect. Sessions still being set up do not — a member who is only waiting on a partner's answer is not mid-workout, and pulling them into a half-built session on every launch would be intrusive.
- **A-004 — Sessions expire at 3 hours** *(confirmed 2026-08-05)*: 3 hours with no recorded activity, or 3 hours with an empty session room, ends the session outright — it is not merely hidden from the resume logic. This exceeds a normal workout including rest periods, while stopping abandoned sessions from living on indefinitely.
- **A-005 — No dismissal concept** *(corrected 2026-08-05)*: Terminating is the only way out of the session screen, so a member can never be "away from but still in" a live session. There is no dismiss action, no suppression record, and no manual re-entry affordance to design. The quiet-session prompt (FR-003a) and the 3-hour expiry (A-004) together cover what dismissal would otherwise have handled.
- **A-006 — Committed work only**: Only work the member actually submitted is guaranteed to survive. A set part-way through entry when the app died is not restored.
- **A-007 — Wrap-up is excluded, and needs no rule of its own** *(confirmed 2026-08-05; corrected 2026-08-05 against the code)*: The recap is a review step with no time pressure, so it is never forced open. It also is not a session stage — a session that has been wrapped up is simply completed, and FR-002's live-only rule already excludes it. An earlier draft treated wrap-up as a third stage alongside setup and live; there are only those two.
- **A-008 — Occupancy is new state**: Deciding warm-versus-quiet and enforcing the empty-room expiry both need to know whether anyone currently has the session room open. If the app does not already track this, the feature introduces it. It covers presence in a session only — no other tracking of member behaviour is added.
- **A-009 — Expiry is not the member's job**: A session must expire on schedule even when no participant's app is running, so expiry cannot rely on a returning member to trigger it.

## Out of Scope

- Changing the *intent* of terminating a session. Terminating has always been meant to end the session for the terminating member only; this feature implements that intent, along with the partner notification in FR-008a, because the code currently ends the session for everyone.
- Retroactively expiring sessions that are already stale at release time — the 3-hour rule applies going forward.
- Adding any way to leave the session screen other than terminating.
- Cross-device handover (starting a session on a phone and resuming on a tablet).
- Reminding or notifying a member outside the app that they have an unfinished session.
- Restoring partially entered, unsubmitted input.
- Any change to how sessions themselves are conducted, scored, or shared.
