# Feature Specification: Fix Onboarding & Login Flow

**Feature Branch**: `002-fix-onboarding-login`
**Created**: 2026-05-26
**Status**: Draft
**Input**: User description: "fix the flow of onboarding and login for the app"

## Overview

The correct intended flow for this app is:

**App Presentation → Signup / Login → Onboarding profile steps (new users only) → Main**

The current implementation has the onboarding profile steps (name, avatar, goal, training days) appearing *before* account creation, which is the wrong order and causes three compounding problems:

1. The profile data collected during onboarding (name, avatar, goal, training days) is discarded when the user is routed to signup, because there is no account to save it to yet — resulting in a redundant Profile Setup screen asking for the same information again after signup
2. The onboarding steps should run *after* the user authenticates (as a post-signup profile completion step), so the data is saved directly to their new account without any in-session carrying or re-entry
3. Returning users who log in on a new device (or after clearing app data) are incorrectly redirected to the onboarding flow because the "seen onboarding" flag is stored only on the local device — not tied to whether their account profile is actually complete

## Clarifications

### Session 2026-05-26

- Q: Should the existing Profile Setup screen be kept, redesigned, or removed for the incomplete-profile recovery path? → A: Keep the existing Profile Setup screen as-is for the recovery path (User Story 3); this feature changes only routing and data-passing logic, not the Profile Setup screen itself
- Q: When account creation fails after onboarding (e.g., email taken, network error), what does the user experience? → A: User stays on the signup screen with a clear error message; they correct their input and retry without touching onboarding data — no back-navigation to onboarding required
- Q: On the final "Done" step of onboarding, how should the CTA transition to account creation? → A: The onboarding profile steps (name, avatar, goal, training days) should appear AFTER signup and app presentation screens — the flow order is: App Presentation → Signup/Login → Onboarding profile steps (post-auth, new users only) → Main

## User Scenarios & Testing *(mandatory)*

### User Story 1 — New User: First-Time Registration (Priority: P1)

A brand-new user opens the app for the first time. They see app presentation screens, proceed to signup, create their account, then walk through a short post-signup onboarding flow (name, avatar, goal, training days) that saves directly to their new account. They arrive at the main app with a fully populated profile — without ever being asked to enter the same information twice.

**Why this priority**: This is the primary acquisition path. Having the correct flow order (account first, profile customisation second) means onboarding data can be saved immediately to the authenticated account, eliminating data loss entirely.

**Independent Test**: Launch app with no existing account. Complete the full new-user flow: app presentation → signup → onboarding profile steps → main. Verify the user's profile displays the name, avatar color, and fitness goal chosen during the post-signup onboarding — without an intervening Profile Setup screen.

**Acceptance Scenarios**:

1. **Given** a first-time user opens the app, **When** they move through the app presentation screens and tap to sign up, **Then** they see the account creation screen (email + password)
2. **Given** a user successfully creates their account, **When** account confirmation completes, **Then** they are taken to the multi-step onboarding profile steps (name → avatar color → fitness goal → training frequency)
3. **Given** a new user completes all onboarding profile steps, **When** they confirm on the final step, **Then** their profile (name, avatar color, goal, training days) is saved to their account and they land on the main app
4. **Given** registration and onboarding are complete, **When** the user views their profile, **Then** the name, avatar color, and fitness goal collected during post-signup onboarding are displayed correctly — with no redundant Profile Setup screen having been shown

---

### User Story 2 — Returning User: Login on Any Device (Priority: P1)

A user who already has a completed account opens the app — whether on the same device, a new device, or after clearing app data — taps "Already have an account," logs in, and lands directly on the main app. They never see the onboarding flow or the Profile Setup screen.

**Why this priority**: Incorrect redirects for returning users break trust and cause churn. Profile-complete users must always reach the main app on login.

**Independent Test**: Create an account with a complete profile. Simulate a new device (clear app data or reinstall). Log in. Verify the app routes directly to the main screen without showing onboarding or profile setup.

**Acceptance Scenarios**:

1. **Given** an existing user opens the app, **When** they tap "Already have an account," **Then** the login screen is shown
2. **Given** a returning user enters valid credentials, **When** login succeeds, **Then** the app routes to the main screen — not to onboarding or profile setup
3. **Given** a returning user's device is new or app data was cleared, **When** they log in with a completed profile, **Then** the routing decision is based on their account's profile completion state — not any device-local flag

---

### User Story 3 — Returning User with Incomplete Profile (Priority: P2)

A user created an account but abandoned the app before completing profile setup (e.g., quit after signup before saving profile data). On their next session, they log in and are taken to profile completion before accessing the main app.

**Why this priority**: An incomplete profile prevents core features (leaderboard display, session matching) from working correctly. Users must complete their profile before reaching the main experience.

**Independent Test**: Create an account but abort before saving a complete profile. Close and reopen the app. Log in. Verify the app routes to profile completion, not to the main screen.

**Acceptance Scenarios**:

1. **Given** a user with an incomplete profile logs in, **When** login succeeds, **Then** they are shown the profile completion screen
2. **Given** a user on the profile completion screen fills in all required fields, **When** they confirm, **Then** their profile is saved and they are routed to the main app

---

### User Story 4 — Post-Signup Onboarding Saves Directly to Profile (Priority: P1)

After creating their account, a new user completes the onboarding profile steps (name, avatar color, fitness goal, training days per week). Because they are already authenticated, each confirmed step saves directly to their account — no in-session data carrying is needed and no separate Profile Setup screen is shown.

**Why this priority**: Moving onboarding after signup eliminates the data-loss problem. The user is already authenticated when the onboarding steps run, so data is persisted directly to their profile.

**Independent Test**: Complete signup, then complete the post-signup onboarding steps (name, avatar color, goal, training days). Without seeing a Profile Setup screen, verify the profile page reflects all four values.

**Acceptance Scenarios**:

1. **Given** a user just created their account, **When** they complete the post-signup onboarding step entering name "Alex," avatar color lime, goal "Build Strength," and 4 training days, **Then** their profile is saved with those four values upon confirmation
2. **Given** the onboarding steps are complete, **When** the app routes the user to the main screen, **Then** no Profile Setup screen is shown and the profile is already complete

---

### Edge Cases

- What if a user quits the app during the post-signup onboarding steps (after account creation but before completing profile)? → They have an incomplete profile; on their next login the app routes them to profile completion (User Story 3 / FR-006)
- What if account creation fails (e.g., email already in use, network error)? → User stays on the signup screen with a clear error message and retries; no onboarding data is at risk since onboarding runs post-signup
- What if a logged-in user's profile completion check fails due to a network error? → The app should default to routing the user to the main screen rather than blocking them in a redirect loop
- What if a new user uses a social sign-in provider (Google, etc.) that supplies their name? → The provider-supplied name can serve as the initial value; any data the user entered during onboarding takes precedence
- What if the user navigates back during onboarding and changes previously entered data? → The most recent values entered before account creation are the ones saved to the profile

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: New users MUST see app presentation screens before reaching the signup/login screen; the multi-step onboarding profile steps (name, avatar, goal, training days) MUST appear AFTER account creation, not before
- **FR-002**: After a new user creates their account, the app MUST present the onboarding profile steps (name, avatar color, fitness goal, training frequency) and save each confirmed step directly to the authenticated user's profile
- **FR-003**: After completing the post-signup onboarding steps, the app MUST NOT show the Profile Setup screen; the user goes directly to the main app. The existing Profile Setup screen is retained unchanged for the incomplete-profile recovery path (FR-006) only
- **FR-004**: Profile completion status MUST be determined by whether the user's account contains the required profile fields — this determination must be consistent across all devices and sessions for the same account
- **FR-005**: A returning user with a complete profile MUST always be routed to the main app after login — regardless of whether device-local onboarding flags are set
- **FR-006**: A returning user with an incomplete profile MUST be routed to profile completion after login, regardless of device
- **FR-007**: The app presentation/welcome screen MUST provide two clearly distinct paths: one for new users ("Get Started" → signup → post-signup onboarding → main) and one for returning users ("Already have an account" → login → main)
- **FR-008**: If account creation fails (e.g., email already in use, network error), the user MUST remain on the signup screen with a clear, actionable error message and be able to correct their input and retry
- **FR-009**: The routing logic MUST NOT rely solely on device-local storage to determine whether a logged-in user needs onboarding or profile setup

### Key Entities

- **UserAccount**: An authenticated identity — attributes: unique ID, email, authentication provider (email/password, Google, etc.), creation timestamp
- **UserProfile**: Profile data associated with an account — required attributes: display name, avatar color, fitness goal, training frequency (days/week); has a `complete` status when all four required fields are present
- **OnboardingSession**: The in-progress state of the post-signup profile setup steps — attributes: name, avatar color, goal, training frequency; the user is already authenticated when this runs, so data is saved directly to the UserProfile on confirmation of each step

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can complete the full journey from the welcome screen to the main app (with a fully populated profile) in under 3 minutes
- **SC-002**: 100% of returning users with complete profiles are routed directly to the main app on login — zero incorrect redirects to onboarding or profile setup
- **SC-003**: 100% of onboarding data (name, avatar color, goal, training frequency) entered by a new user appears correctly in their profile after account creation — no re-entry required
- **SC-004**: Returning users with incomplete profiles are correctly routed to profile completion on login regardless of which device they use
- **SC-005**: Zero newly created accounts (following the onboarding path) result in an empty or incomplete profile state after registration completes

## Assumptions

- "Profile complete" is defined as: display name, avatar color, fitness goal, and training frequency all present on the account
- The check for profile completeness is based on account-level data (not device-local storage); the app already has a mechanism to check profile completion from the account — this spec requires that routing decisions rely on that account-level check exclusively, not on any device-local flag
- The onboarding profile steps UI (name, avatar color, goal, training days), copy, and visual design are not changing — only their position in the flow (post-signup instead of pre-signup) and their integration with the router
- Social sign-in (Google, etc.) users have their own profile population path and are out of scope for the onboarding step changes; they are still subject to the correct routing rules (FR-004, FR-005, FR-006)
- "App presentation screens" that appear before the signup/login choice are either the existing welcome/splash screen or additional introductory screens; their specific design is out of scope for this feature — the requirement is only that they appear before signup and that they route new users to signup and returning users to login
