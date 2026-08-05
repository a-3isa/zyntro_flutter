# Quickstart Verification: Profile, Auth, Navigation & Social Fixes

**Feature**: 005-profile-auth-social-fixes  
**Date**: 2026-06-10

Six independent verification paths — one per story. Run each in order of priority.

---

## QS-1: Auth Persistence (P1)

**Precondition**: User account exists and app is installed.

1. Open app → sign in with email/password.
2. Verify you reach the home screen.
3. Force-close the app (swipe away from recents).
4. Reopen the app.
5. **Expected**: Home screen appears without showing sign-in screen.
6. Repeat after waiting 30+ minutes before step 4 — same expected result. *(This step specifically validates FR-002a: silent token refresh. If the app shows sign-in here but not at step 4, the auth cache TTL was the cause — confirm T003 is applied.)*
7. Explicitly sign out via Settings.
8. Reopen app.
9. **Expected**: Sign-in screen shown (correct behavior after explicit sign-out).

**Failure**: If sign-in screen appears after step 4 or 6, auth persistence is broken.

---

## QS-2: Back Button Navigation (P2)

**Precondition**: User is signed in.

1. From the home screen, navigate to any profile or settings screen.
2. Press the hardware back button (or swipe-back gesture on Android).
3. **Expected**: Previous screen shown, NOT app exit.
4. Navigate 3 screens deep (home → notifications → any notification detail).
5. Press back twice.
6. **Expected**: Each press goes one screen back; on the third press from home, the app shows an exit prompt or exits (not a crash).
7. Open a bottom sheet or modal (e.g., exercise picker, any action sheet).
8. Press the hardware back button.
9. **Expected**: Bottom sheet closes; the app remains on the same screen behind it — does NOT exit. *(Validates FR-006: back button dismisses sheets before navigating history.)*

**Failure**: Any back press that exits the app from a non-root screen.

---

## QS-3: Exercise Database Loading (P3)

**Precondition**: User is signed in.

1. Start a new gym session (or go to session setup).
2. Tap "Add exercise".
3. **Expected**: Exercise list appears immediately with multiple exercises visible — not a blank white/grey area.
4. Type "bench" in the search field.
5. **Expected**: "Bench Press" and similar exercises appear in results.
6. Clear the search field.
7. **Expected**: Full exercise list reappears.
8. Turn off network (airplane mode), tap "Add exercise" again.
9. **Expected**: Local exercise list still appears (fallback works offline too).

**Failure**: Blank list, no exercises shown at any step.

---

## QS-4: Profile Photo + Avatar Color Ring (P4)

**Precondition**: User has a profile photo uploaded AND has set an avatar color during onboarding (not default lime).

1. Open the app and navigate to your own profile.
2. **Expected**: Your profile photo is shown inside the circle (not your initials).
3. The ring/border around the circle matches your chosen avatar color (not always lime).
4. Navigate to the social/search tab and view another user's profile circle.
5. **Expected**: Their photo (or initials) shown with their avatar color ring.
6. Go to Settings → Edit Profile → change avatar color.
7. Navigate back to profile.
8. **Expected**: Ring color updated to the new choice.

**Fallback test**: Sign in as a user with no profile photo.
- **Expected**: Initials shown in circle, avatar color ring still present.

**Failure**: Ring stays lime regardless of selected color; photo not shown when it should be.

---

## QS-5: Sign-in Screen Responsiveness (P5)

**Precondition**: Device or emulator at 375×667 px (or iOS SE size, or Android compact size).

1. Open the app to the sign-in screen.
2. **Expected**: Email field, password field, "Forgot password?" link, "Sign in" button, Google/Facebook sign-in, "Don't have an account?" link all visible without any scroll.
3. Tap the email field to open the keyboard.
4. **Expected**: Email field, password field, and "Sign in" button remain visible above the keyboard (field scrolls into view if needed).
5. Repeat steps 1-4 on the sign-up screen.
6. Repeat on a larger device (e.g., 390×844 or tablet).
7. **Expected**: Layout is centered and readable — not stretched.

**Failure**: User must scroll to reach the "Sign in" button with the keyboard closed.

---

## QS-6: Follow Request Notification Actions (P6)

**Precondition**: Two test accounts (Account A = requester, Account B = recipient). Account B has notifications enabled.

**Public account test**:
1. Account A taps "Follow" on Account B's profile (public account).
2. Open Account B's notifications screen.
3. **Expected**: Notification from Account A appears with a "Follow back" button (if B is not already following A).
4. Tap the "Follow back" button.
5. **Expected**: Button changes to "Following" indicator; A now appears in B's following list.

**Private account test**:
1. Set Account B's profile to private in Settings.
2. Account A taps "Follow" on Account B's profile.
3. Open Account B's notifications screen.
4. **Expected**: Notification shows "Follow back" (if not following) AND "Accept" AND "Decline" buttons.
5. Tap "Accept".
6. **Expected**: Notification updates to accepted state; A is added to B's followers.
7. Repeat with "Decline" (new request from a third account).
8. **Expected**: Request rejected; notification dismissed or marked declined.

**Push notification tap test**:
1. With app closed, Account A sends follow request to Account B.
2. Account B receives a device push notification banner.
3. Tap the notification banner.
4. **Expected**: App opens to Account A's profile page (not the follow-requests page).

**Failure**: Missing action buttons; tapping notification goes to wrong screen; buttons visible when they should not be (e.g., Follow-back shown when already following).
