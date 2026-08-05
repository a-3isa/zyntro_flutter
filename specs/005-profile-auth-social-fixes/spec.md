# Feature Specification: Profile, Auth, Navigation & Social Fixes

**Feature Branch**: `005-profile-auth-social-fixes`  
**Created**: 2026-06-10  
**Status**: Draft  
**Input**: User description: "i want the user profile image to be displayed in the circle instead of the letter and around it is the circle which color is changed depending on the user chosen avatar color, also i want the sign screen to be adapt to the mobile size not making the user to scroll to see all the content, also fix that everytime i close the app and reopen it it is signed out and i have to sign in again also fix that if i tap the back button of the mobile the app exsits it suppose to show the prevoius screen, also i want that if any user send a follow request the other user recieves a notification for the request in the notification screen with an option to follow him back if he isnt following him already and if the user account is private there will be another option to accept the follow request, also i cant find the excersises db when i tried to start session now there was no excersies shown"

## Clarifications

### Session 2026-06-10

- Q: When a follow request is sent and the recipient has the app closed, should they receive a push notification to the device lock screen or only an in-app notification? → A: Both — in-app notification screen updated when the app is opened AND a push notification delivered to the device (requires FCM/APNs integration).
- Q: When the app starts and the access token is expired but a refresh token exists, what should happen? → A: Refresh silently in the background; navigate to the home screen if refresh succeeds; redirect to sign-in only if the refresh token itself has expired or been revoked.
- Q: Where is the exercise catalog stored? → A: Firestore — the catalog lives in a cloud Firestore collection; seeding means running a one-time import of exercise documents into that collection.
- Q: When the user taps the follow request push notification on their device, where does the app navigate? → A: The in-app notifications screen is the canonical location for the Follow back/Accept/Decline action buttons; tapping the notification card itself (not an inline action button) navigates directly to the requester's profile page.
- Q: What does the exercise picker currently show when opened? → A: An empty list with no error message — confirming the picker UI loads but the Firestore exercise collection has no seeded documents.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Stay Signed In After App Restart (Priority: P1)

As a returning user, I want the app to remember that I am signed in so that I do not have to enter my credentials every time I close and reopen the app.

**Why this priority**: Every user is affected by this bug on every app launch. It is the highest-friction defect and must be resolved before other improvements are visible.

**Independent Test**: Can be fully tested by signing in, force-closing the app, reopening it, and verifying the user lands on the home screen instead of the sign-in screen.

**Acceptance Scenarios**:

1. **Given** a user has signed in, **When** they close the app completely and reopen it, **Then** the app resumes in the authenticated state without showing the sign-in screen.
2. **Given** a user has signed in, **When** the device is restarted and the app is opened, **Then** the user remains signed in.
3. **Given** a user explicitly signs out, **When** they reopen the app, **Then** the sign-in screen is shown as expected.
4. **Given** a user's session has expired server-side, **When** they reopen the app, **Then** the app redirects to the sign-in screen with a clear "session expired" message.

---

### User Story 2 - Hardware Back Button Navigates Within App (Priority: P2)

As a user on Android, I want the hardware or gesture back button to take me to the previous screen rather than exiting the app so that I can navigate naturally without losing my place.

**Why this priority**: Unexpected app exit on back press is a critical navigation defect. Users lose context and must restart their flow entirely.

**Independent Test**: Can be tested by navigating two or more screens deep, pressing the device back button, and confirming the previous screen appears rather than the app closing.

**Acceptance Scenarios**:

1. **Given** the user has navigated from the home screen to a detail screen, **When** they press the hardware back button, **Then** they return to the home screen instead of the app exiting.
2. **Given** the user is on a screen navigated to from another screen, **When** they press back, **Then** the app shows the previous screen.
3. **Given** the user is on the root/home screen with no previous screen in the stack, **When** they press back, **Then** the app exits or shows a confirmation prompt — not a crash.
4. **Given** the user is inside a modal or bottom sheet, **When** they press back, **Then** the modal or sheet dismisses rather than exiting the app.

---

### User Story 3 - Exercise Database Loads When Starting a Session (Priority: P3)

As a user starting a gym session, I want the exercise selection screen to show a list of available exercises so that I can pick what I want to train.

**Why this priority**: An empty exercise picker makes it impossible to plan any session and blocks meaningful app usage.

**Independent Test**: Can be tested by starting a new gym session, tapping "Add exercise", and confirming exercises appear in the picker.

**Acceptance Scenarios**:

1. **Given** a user opens the exercise picker from the session planning screen, **When** the picker loads, **Then** a list of exercises is displayed — not an empty state.
2. **Given** the exercise picker is open, **When** the user searches by name or muscle group, **Then** matching results appear.
3. **Given** the exercise data fails to load, **When** the picker opens, **Then** a visible error state with a retry option is shown rather than a silent empty list.
4. **Given** the exercises have loaded once during a session, **When** the user opens the picker again in the same session, **Then** the list loads quickly without a full reload.

---

### User Story 4 - Profile Photo Shown in Circle with Avatar Color Ring (Priority: P4)

As a user with a profile photo uploaded, I want to see my photo displayed in the profile circle rather than my initials, and I want the ring around the circle to match my chosen avatar color so that my profile feels personalized.

**Why this priority**: Profile photo display is a standard social-app expectation. The avatar color ring adds visual identity differentiation. Both are polish improvements that are independently deployable.

**Independent Test**: Can be tested by opening the app with a profile photo set, navigating to any screen showing the profile circle, and confirming the photo appears and the ring color matches the chosen avatar color.

**Acceptance Scenarios**:

1. **Given** a user has a profile photo set, **When** any screen shows their profile circle, **Then** their photo is displayed inside the circle instead of their initials.
2. **Given** a user has a profile photo and a chosen avatar color, **When** their profile circle is displayed, **Then** a colored ring matching the avatar color appears around the circle.
3. **Given** a user has no profile photo set, **When** their profile circle is displayed, **Then** their initials are shown as the fallback with the avatar color ring still applied.
4. **Given** another user's profile circle is shown (e.g., search results or session), **When** that user has a profile photo, **Then** their photo is shown; if not, their initials with their avatar color ring are shown.
5. **Given** a user changes their avatar color in settings, **When** they return to any screen showing their profile circle, **Then** the ring color updates to reflect the new choice.

---

### User Story 5 - Sign-in Screen Fits Mobile Viewport Without Scrolling (Priority: P5)

As a user opening the app for the first time on a standard phone, I want all sign-in and sign-up fields and actions to be visible on screen without needing to scroll so that I can complete authentication quickly.

**Why this priority**: Scroll-to-reach-submit is unnecessary friction at the most critical first-impression moment. This is a layout polish fix.

**Independent Test**: Can be tested by opening the sign-in and sign-up screens on a small device (e.g., 375×667pt), confirming all fields and the submit button are visible without scrolling.

**Acceptance Scenarios**:

1. **Given** the user opens the sign-in screen on a small mobile device, **When** the screen renders, **Then** all form fields and the sign-in button are visible without scrolling.
2. **Given** the user opens the sign-up/registration screen, **When** the screen renders on a small device, **Then** all required fields and the submit button are visible without scrolling.
3. **Given** the on-screen keyboard opens on a form field, **When** the keyboard appears, **Then** the focused field and submit action remain visible or scroll into view automatically.
4. **Given** the layout is shown on a large screen, **When** the sign-in screen renders, **Then** content remains centered and readable — not stretched edge-to-edge.

---

### User Story 6 - Receive Follow Request Notification with Follow-Back and Accept Actions (Priority: P6)

As a user who receives a follow request, I want to see a notification in the notifications screen that lets me follow the requester back and, if my account is private, also accept or decline the follow request so that I can manage my connections from one place.

**Why this priority**: Follow request notifications are a key social engagement feature. Without them, users miss connection opportunities entirely.

**Independent Test**: Can be tested by having one account send a follow request to another, then opening the notifications screen on the receiving account and confirming the notification appears with the correct action buttons.

**Acceptance Scenarios**:

1. **Given** user A sends a follow request to user B, **When** user B opens the notifications screen, **Then** a follow request notification from user A appears.
2. **Given** the notification is visible and user B is not already following user A, **When** user B views the notification, **Then** a "Follow back" button is shown.
3. **Given** user B's account is private, **When** user A sends a follow request, **Then** the notification includes "Accept" and "Decline" buttons in addition to "Follow back".
4. **Given** user B's account is public, **When** user A sends a follow request, **Then** the follow is automatically applied and the notification shows "Follow back" only — no Accept/Decline needed.
5. **Given** user B taps "Follow back", **When** the action completes, **Then** user B now follows user A and the button is replaced with a "Following" indicator.
6. **Given** user B (private account) taps "Accept", **When** the action completes, **Then** user A is added to user B's followers and the notification updates to reflect acceptance.
7. **Given** user B (private account) taps "Decline", **When** the action completes, **Then** the follow request is rejected and the notification is dismissed or marked declined.
8. **Given** user B is already following user A, **When** the follow request notification appears, **Then** no "Follow back" button is shown — only Accept/Decline (for private accounts) or an acknowledged state.

---

### Edge Cases

- If a user's profile photo URL is broken or fails to load, the app falls back to the user's initials with the avatar color ring intact.
- If a user has no avatar color set, a neutral default color is used for the ring rather than omitting the ring entirely.
- If the exercise database is empty or unavailable, a non-empty error state with a retry button is shown — not a silent blank list.
- If a follow request is withdrawn by the sender before the recipient acts, the notification is removed from the recipient's notifications screen.
- If multiple follow requests arrive in quick succession, each is shown as a separate notification entry rather than collapsed silently.
- If the back button is pressed on a screen with unsaved form input, the app either prompts before discarding or auto-saves draft state.
- If the user opens the sign-in screen with the keyboard already visible (e.g., autofill trigger), all fields must remain reachable without manual scroll.
- If the auth token refresh fails silently at startup, the app should detect the invalid state and redirect to sign-in with a clear message rather than letting the user reach an authenticated screen with stale credentials.

## Requirements *(mandatory)*

### Functional Requirements

**Auth Persistence**

- **FR-001**: The app MUST persist the authenticated session across app close and reopen so that users remain signed in without re-entering credentials.
- **FR-002**: The app MUST silently validate the persisted session on startup; if the access token is valid, it MUST navigate directly to the authenticated home screen without any visible loading step.
- **FR-002a**: If the access token is expired but a refresh token is available, the app MUST attempt a silent token refresh in the background and navigate to the home screen if the refresh succeeds — the user MUST NOT see the sign-in screen in this case.
- **FR-003**: The app MUST redirect to the sign-in screen only when the session is explicitly signed out or when both the access token and refresh token have expired or been revoked. The redirect MUST display a human-readable reason (e.g., "Your session has expired, please sign in again").

**Back Button Navigation**

- **FR-004**: The app MUST intercept the hardware and gesture back button on all navigable screens and navigate to the previous screen in the navigation stack rather than exiting the app.
- **FR-005**: The app MUST exit only when the user presses back on the root screen with no navigation history, and MAY show an exit-confirmation prompt on that action.
- **FR-006**: The back button MUST dismiss modals, bottom sheets, and dialogs before navigating screen history.

**Exercise Database Loading**

- **FR-007**: The app MUST load and display at least the default exercise catalog when the exercise picker is opened from either session planning or session completion.
- **FR-008**: The exercise picker MUST NOT display a silent empty list under any circumstance. If data loads successfully but the collection is empty, it MUST show a distinct "no exercises found" empty state. If data fails to load, it MUST show an error state with a retry action. A blank white/grey screen with no message is not acceptable.
- **FR-009**: The exercise catalog Firestore collection MUST be seeded with at least the minimum catalog (per spec 004) before this feature is considered complete. The current empty list is caused by a missing data seed — confirmed by the picker loading without error but showing zero results. Seeding is a hard prerequisite.

**Profile Photo and Avatar Color Ring**

- **FR-010**: The app MUST display a user's profile photo inside the profile circle wherever that circle appears (profile screen, session participants, search results, notifications).
- **FR-011**: When a profile photo is unavailable or fails to load, the app MUST fall back to displaying the user's initials inside the circle.
- **FR-012**: The app MUST render a colored ring or border around every profile circle using the color associated with that user's chosen avatar color.
- **FR-013**: The ring color MUST update across all visible profile circles when the user changes their avatar color in settings.

**Sign-in Screen Responsiveness**

- **FR-014**: The sign-in and sign-up screens MUST display all form fields and the primary action button within the visible screen area on any device with a screen width of 375pt or greater without requiring scroll.
- **FR-015**: When the on-screen keyboard opens on a focused field, the active field and submit button MUST remain visible or scroll automatically into view.

**Follow Request Notifications**

- **FR-016**: The app MUST deliver a follow request notification via two channels: (1) a device push notification (banner/badge) delivered even when the app is closed, and (2) a notification entry in the recipient's in-app notifications screen.
- **FR-017**: Each follow request notification MUST display the requesting user's name, profile circle, and a "Follow back" button if the recipient is not already following the requester.
- **FR-018**: If the recipient's account is private, the notification MUST additionally display an "Accept" button and a "Decline" button.
- **FR-019**: If the recipient's account is public, incoming follows apply immediately; the notification is informational and shows only the "Follow back" option.
- **FR-019a**: Tapping the follow request push notification card (the notification body, not an inline action button) MUST deep-link the user directly to the requester's profile page inside the app.
- **FR-020**: The app MUST update the notification entry after the user takes any action (Follow back, Accept, Decline), replacing action buttons with an appropriate state indicator.
- **FR-021**: If the requester withdraws their follow request before the recipient acts, the app MUST remove or mark as withdrawn the corresponding notification entry.

### Key Entities *(include if feature involves data)*

- **Persisted Session**: A record stored securely on the device containing the user's authenticated identity and token. Allows the app to resume authentication without re-login. Key attributes: user identity, token, expiry timestamp.
- **Profile Circle**: A visual component showing either a user's profile photo or their initials inside a colored ring. Appears wherever user identity is displayed in the app.
- **Avatar Color**: A color value chosen by the user during onboarding or profile settings. Used exclusively as the ring color on the profile circle.
- **Follow Request**: An action by user A requesting to follow user B. States: pending, accepted, declined, withdrawn. For public accounts, follows auto-accept on send.
- **Follow Request Notification**: An entry in the notifications screen generated when a follow request is received. Contains sender identity, request state, and available actions (Follow back, Accept, Decline).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of users who were signed in before closing the app remain signed in when they reopen it, without re-entering credentials (excluding explicit sign-out and true session expiry).
- **SC-002**: 100% of app screens handle the hardware back button by navigating to the previous screen rather than exiting the app, except on the root screen.
- **SC-003**: The exercise picker displays at least one exercise entry within 2 seconds of opening on a standard mobile network connection.
- **SC-004**: Profile circles across all app screens show the user's photo (or initials fallback) with the avatar color ring wherever a profile circle is rendered.
- **SC-005**: The sign-in and sign-up screens require zero scroll to see all fields and the primary CTA on devices with screens of 375×667 logical pixels or larger.
- **SC-006**: Follow request push notifications are delivered to the recipient's device within 5 seconds of the request being sent under normal network conditions, whether the app is open or closed. The in-app notifications screen reflects the request immediately when the app is active.
- **SC-007**: Follow-back, Accept, and Decline actions complete and update the notification UI within 2 seconds of being tapped.
- **SC-008**: Users can receive a follow request, act on it (follow back or accept), and see the updated notification state without leaving the notifications screen.

## Assumptions

- Auth persistence uses a secure on-device token store; the mechanism already exists in the project's auth layer and only needs to be enabled or correctly connected.
- The hardware back button fix applies primarily to Android; iOS swipe-back gestures are assumed to be working correctly already.
- The exercise catalog seeding (FR-009) refers to populating the shared database with the minimum catalog described in spec `004-database-exercise-picker`.
- Profile photos are already uploadable; this feature only changes how existing photos are rendered inside the circle widget.
- Avatar color is already stored per user as part of the onboarding or profile setup flow; this feature reads that value and applies it as the ring color.
- Follow requests already exist as a data concept; this feature adds notification delivery and action UI for receiving them.
- The notifications screen already exists in the app; this feature adds a new follow-request notification type to it.
- For public accounts, incoming follows apply immediately and no explicit accept flow is needed; the notification is informational only.

## Terminology

| Spec Term | Implementation Notes |
|-----------|----------------------|
| Profile circle | The circular avatar widget used across the app |
| Avatar color ring | The colored border rendered around the profile circle |
| Follow request notification | A new notification type added to the existing notifications screen |
| Persisted session | The on-device auth token that survives app restart |
| Root screen | The first screen with no navigation history (back press exits app from here) |
