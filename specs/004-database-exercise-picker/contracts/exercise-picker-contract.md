# Contract: Exercise Picker

This contract describes user-visible and service-level behavior for the database exercise picker. It is intentionally implementation-neutral enough to validate UI, service, and persistence behavior.

## Search Exercises

**Input**
- `userId`: current authenticated user.
- `query`: user-entered search text.

**Output**
- Ordered list of exercise results from:
  - active shared catalog entries;
  - the user's personal custom exercises.

**Rules**
- Search is case-insensitive.
- Search tolerates partial names, spacing differences, and common misspellings where reasonable.
- Each result includes:
  - stable id;
  - source (`catalog` or `custom`);
  - display name;
  - at least one distinguishing detail when available, such as muscle group or equipment.
- Results from another user's personal custom exercises are not visible.
- If loading fails, the picker shows a retry state and does not mutate the current plan.

## Select Exercise With Sets

**Input**
- `exerciseResult`: selected search result.
- `plannedSets`: integer from 1 to 20 inclusive.
- `target`: start-session plan, setup plan, invite setup plan, or late-session plan.

**Output**
- A selected exercise added to the target user's plan.

**Rules**
- Values below 1 or above 20 are rejected before confirmation.
- Catalog selections retain shared database identity.
- Custom selections retain personal custom identity and are marked as custom.
- Existing plan editing behavior remains available after insertion.
- Late-session selections are added as planned remaining work and are not counted as completed until logged.

## Create Custom Exercise

**Input**
- `userId`: current authenticated user.
- `name`: user-entered exercise name.
- Optional metadata: muscle group/category and equipment.

**Output**
- Personal custom exercise available to the creating user.
- Review submission for possible shared catalog inclusion.

**Rules**
- Custom creation must be an explicit action from an empty/custom state.
- The created custom exercise appears in future searches for the creator immediately.
- The custom exercise does not appear in the shared catalog until reviewed/approved.
- Review submission starts in a pending state.

## Start-Session Flow Contract

**Given** a user is planning a gym session  
**When** they tap "Add exercise"  
**Then** the database exercise picker opens and free-text inline add is not used.

**Given** the user confirms a database or custom result with 1-20 sets  
**Then** the selected exercise is appended to the plan and can still be reordered, removed, or have set count edited before start.

## Late-Session Flow Contract

**Given** a user is at a session completion or late-add stage  
**When** they tap "Add exercise"  
**Then** the same picker opens.

**Given** the user confirms a result with 1-20 sets  
**Then** the exercise is added to the active session plan as remaining work, and the user must log each set before the final summary counts it as completed.

## Access Contract

- All authenticated users can read active shared catalog entries.
- Users can create, read, update, and search only their own personal custom exercises.
- Users can create review submissions for their own custom exercises.
- Only moderators or trusted review processes can approve, reject, merge, or publish review submissions into the shared catalog.
