# Quickstart: Friend Workout Sessions

Use these scenarios as manual and automated acceptance evidence before cutover.

## Prerequisites

- Two test users exist and can sign in on separate devices/emulators.
- The users are mutual follows.
- Neither user has blocked the other.
- A third user exists who is not a mutual follow for negative eligibility checks.
- Session notifications or in-app invite listeners are enabled for the invited user.

## Scenario 1: Bot Friend Gym Session

1. Sign in as a user.
2. Start a paired gym workout and select the bot friend.
3. Confirm the bot is the only partner.
4. Start the session.
5. Observe the bot taking a gym set turn.

Expected evidence:
- Bot partner appears without invitation acceptance.
- Bot gym set shows 7 seconds, 8 reps, and 80 kg.
- The user reaches the bot session within 30 seconds of selecting the bot.

Maps to: SC-001, FR-001 through FR-005.

## Scenario 2: Real Friend Invitation Accepts

1. Sign in as host on device A.
2. Sign in as mutual-follow invited friend on device B.
3. Host selects exactly one friend and sends an invitation.
4. Invited friend receives the in-app pop-up.
5. Invited friend accepts within 30 seconds.

Expected evidence:
- Dialog appears on device B within 5 seconds.
- Both users see the same session and each other as the only participants.
- Invite status becomes accepted.

Maps to: SC-002, FR-006 through FR-010.

## Scenario 3: Invitation Expiry And Eligibility Failures

1. Host sends an invitation to an eligible mutual follow and the invitee does not respond.
2. Wait 30 seconds.
3. Attempt to accept after expiry.
4. Attempt to invite a non-mutual-follow user.
5. Block one direction between host and invitee and attempt another invitation.

Expected evidence:
- Pending invitation expires after 30 seconds.
- Late acceptance is rejected with a clear message.
- Non-mutual and blocked users cannot receive invitations.
- Host can invite again or switch to bot after expiry.

Maps to: FR-006, FR-009, FR-021, FR-023.

## Scenario 4: Same-Gym Plan Review And Personal Modification

1. Host creates a gym plan.
2. Invited friend accepts and chooses gym.
3. Invited friend reviews the host plan.
4. Invited friend changes at least one exercise, set count, weight, rep target, order, or rest preference in their own version.
5. Both users confirm plans and start.

Expected evidence:
- Invited friend sees the host gym plan for review.
- Invited modifications do not change the host plan.
- Both plans are ready before start.
- Matching gym session starts turn-based.

Maps to: SC-003, SC-004, SC-006, FR-011 through FR-016.

## Scenario 5: Mixed Workout-Type Parallel Session

1. Host chooses gym.
2. Invited friend accepts and chooses running, cycling, yoga, HIIT, walking, swimming, sports, or other.
3. Invited friend creates a type-appropriate plan directly.
4. Both users confirm plans and start.
5. Log progress from both sides.

Expected evidence:
- Invited friend does not review the host gym plan.
- Session starts in parallel mode under one shared clock.
- Each participant sees the other's type-specific progress within 3 seconds.
- No gym weights/reps are forced onto the non-gym participant.

Maps to: SC-005, SC-006, FR-017 through FR-019.

## Scenario 6: Disconnection During Active Session

1. Start either a turn-based gym session or mixed parallel session.
2. Disconnect one participant.
3. Continue viewing from the other participant.

Expected evidence:
- Remaining participant sees last known progress and disconnected/reconnecting state.
- Session does not corrupt plans or completion records.

Maps to: FR-021, FR-022.

## Scenario 7: Completion And Personal History

1. Complete a paired session with different participant workout types.
2. Open each user's workout history.

Expected evidence:
- Each real participant gets a completion record for their own workout type, plan, and progress.
- Host history is not overwritten by invited-user changes.
- Bot progress is not saved as a normal user workout history record.

Maps to: SC-007, FR-022.

## Telemetry And Rollback Checks

Review telemetry before cutover:

- Invite creation attempts, eligibility failures, delivery latency, accepted, declined, expired, and cancelled counts.
- Bot session starts and bot simulation failures.
- Plan readiness time and failed session start attempts.
- Progress stream latency and disconnect counts.
- Completion record write failures.

Telemetry implementation review:

- `SessionAnalyticsService` defines paired invite, bot, plan copy/modify/ready, readiness-blocked, mixed-session start, progress latency, disconnect, and completion-write events.
- Typed payload helper coverage is present in `test/services/session_analytics_service_test.dart`.

Rollback trigger examples:

- Invitation dialog delivery drops below SC-002 threshold.
- Unauthorized invitation defects are found.
- Plan isolation fails in any production validation.
- Completion records mix host and invited-user workout data.

Rollback verification:

- `flutter test test/features/session/presentation/start_session_page_test.dart --reporter compact` passed and covers disabling the paired-session flag, hiding bot/friend entry points, and preserving solo session creation.

Automated validation evidence:

- Focused paired-session suite passed: 112 tests passed with `flutter test test/services/session_service_test.dart test/services/follow_service_test.dart test/services/session_analytics_service_test.dart test/services/notification_service_contract_test.dart test/services/session_invite_delivery_contract_test.dart test/firebase/firestore_rules_contract_test.dart test/models/models_test.dart test/features/session/domain/gym_session_plan_test.dart test/features/session/presentation/start_session_page_test.dart test/features/session/presentation/session_invite_acceptance_page_test.dart test/features/session/presentation/gym_session_setup_page_test.dart test/features/session/presentation/session_room_auth_contract_test.dart test/features/session/presentation/widgets/active_turn_screen_test.dart test/features/session/presentation/widgets/rep_counter_screen_test.dart test/features/session/presentation/widgets/waiting_turn_screen_test.dart test/features/session/presentation/widgets/parallel_gym_view_test.dart test/features/session/presentation/widgets/parallel_cardio_view_test.dart test/features/session/presentation/recap_page_test.dart --reporter compact`.
- Full suite passed: 233 tests passed and 8 skipped with `flutter test --reporter compact`.
