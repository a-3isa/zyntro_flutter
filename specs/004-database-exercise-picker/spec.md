# Feature Specification: Database Exercise Picker

**Feature Branch**: `004-database-exercise-picker`  
**Created**: 2026-05-30  
**Status**: Draft  
**Input**: User description: "i want the app if the usr tap add excersice to send him to add excersises screen and he choose from thier the exceresise and the number of sets, i want all the excersies to be in db and the user just search for the excersise and choose it, i want this to be implemnted in both stages either when the user is choosing his excersies in the start of the session or if he is adding an excersise at the end of the session"

## Clarifications

### Session 2026-05-30

- Q: When a user adds an exercise at the session completion or late-add stage, should the chosen set count be treated as completed work or added to the plan for normal set logging? -> A: Added to the plan only; the user must still log each set.
- Q: What should happen when no database exercise matches the user's search? -> A: Let users create a custom exercise immediately; search must be case-insensitive and tolerate likely name mistakes.
- Q: Where should custom exercises be saved after creation? -> A: Save custom exercises to the user's personal exercise list immediately and submit them for shared database review.
- Q: What set count range should the picker allow? -> A: Users can choose 1 to 20 sets.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose Planned Exercises From Database (Priority: P1)

As a user planning a gym session, I want tapping "Add exercise" to open a dedicated exercise selection screen where I can search the exercise database, choose an exercise, set the number of planned sets, and add it to my session plan.

**Why this priority**: This replaces free-text planning with a consistent exercise database, which is the main requested change and the first point where workout plans are created.

**Independent Test**: Can be fully tested by starting a gym session plan, tapping "Add exercise", searching for a known exercise, selecting it, choosing set count, and confirming that the selected exercise appears in the planned workout with the chosen sets.

**Acceptance Scenarios**:

1. **Given** a user is creating a gym session plan, **When** they tap "Add exercise", **Then** the app opens an exercise selection screen instead of showing a free-text add field.
2. **Given** the exercise selection screen is open, **When** the user searches for an exercise that exists in the exercise database, **Then** matching exercises are shown with enough detail to distinguish similar exercises.
3. **Given** the user selects an exercise from search results, **When** they choose the number of sets and confirm, **Then** the exercise is added to the session plan with that set count.
4. **Given** the user returns to the session plan after adding an exercise, **When** they review the plan, **Then** the selected exercise remains editable for set count and removable before the session starts.

---

### User Story 2 - Add Exercises At Session End From Database (Priority: P2)

As a user who reaches the end or completion stage of a session, I want tapping "Add exercise" to open the same database-backed selection flow so I can add a missed or extra exercise with its set count to the session plan before logging those sets and finishing.

**Why this priority**: Users often add extra work after the original plan; using the same database-backed flow prevents inconsistent custom names and keeps completed session records structured.

**Independent Test**: Can be fully tested by entering the session completion/add-more-exercise stage, tapping "Add exercise", selecting a database exercise, choosing sets, confirming that the exercise is added to the current session plan, and verifying the user must still log each selected set before those sets count as completed.

**Acceptance Scenarios**:

1. **Given** a user is at the session completion stage with an active gym session, **When** they tap "Add exercise", **Then** the app opens the database-backed exercise selection screen.
2. **Given** the user selects an exercise and set count from that screen, **When** they confirm, **Then** the exercise is added to the session's exercise list as a planned remaining exercise.
3. **Given** a late-added exercise is added before session finish, **When** the user logs the selected sets and finishes the session, **Then** the final session summary includes only the sets the user actually logged.

---

### User Story 3 - Search Reliable Exercise Database (Priority: P3)

As a user choosing exercises, I want search results to come from the shared exercise database so exercise names, categories, and metadata are consistent across planning and late-session additions.

**Why this priority**: The picker is only valuable if the exercise source is complete, searchable, and consistent wherever exercise selection appears.

**Independent Test**: Can be tested by searching the same exercise from both the start-session flow and the session-end add flow and verifying that both surfaces show the same database-backed result and metadata.

**Acceptance Scenarios**:

1. **Given** the exercise database contains a known exercise, **When** the user searches by full or partial exercise name, **Then** that exercise appears in results.
2. **Given** the same search is performed in start-session planning and session-end adding, **When** results are displayed, **Then** the matching exercises and displayed details are consistent.
3. **Given** no database exercise matches the user's search, **When** results are empty, **Then** the app shows a clear empty state with an option to create a custom exercise immediately.

### Edge Cases

- If the exercise database cannot be loaded, the app shows a non-blocking error state with a retry option and does not add free-text exercises by accident.
- If the user searches with different capitalization, spacing, partial words, or a likely exercise-name typo, matching should still work where reasonable.
- If multiple exercises have similar names, the selection screen shows category or equipment details to help the user pick the correct one.
- If the user cancels the selection screen, the existing session plan or completion state remains unchanged.
- If the user chooses fewer than 1 set or more than 20 sets, the app prevents confirmation and keeps the user on the selection screen.
- If the user adds the same exercise more than once, the app allows it as a separate planned entry unless the user removes it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST replace the start-session free-text exercise add field with a dedicated exercise selection screen launched by tapping "Add exercise".
- **FR-002**: The app MUST launch the same exercise selection experience when the user taps "Add exercise" from the session completion or late-add stage.
- **FR-003**: The exercise selection screen MUST allow users to search exercises from the shared exercise database by exercise name.
- **FR-003a**: Exercise search MUST be case-insensitive and MUST normalize whitespace between words before matching; prefix matching MUST work for search terms of two or more characters; the search SHOULD tolerate common exercise-name misspellings up to Levenshtein edit-distance 2 for search terms of five or more characters.
- **FR-004**: Search results MUST display the exercise name and at least one distinguishing detail such as primary muscle group, category, or equipment.
- **FR-005**: Users MUST be able to select an exercise from search results and choose a planned set count before adding it.
- **FR-005a**: The planned set count selector MUST allow values from 1 to 20 inclusive and MUST reject values outside that range.
- **FR-006**: The app MUST add the selected exercise to the relevant session plan or late-session exercise list with the exact set count chosen by the user.
- **FR-006a**: Late-session selected exercises MUST be added as planned remaining work and MUST NOT count as completed sets until the user logs those sets.
- **FR-007**: Exercises selected from the database MUST retain a stable database exercise identity in the session plan and final session record.
- **FR-008**: The start-session planning flow and session-end add flow MUST use the same exercise source and present consistent results for the same search query.
- **FR-009**: The app MUST prevent accidental creation of arbitrary free-text exercises before the user explicitly chooses the custom exercise option.
- **FR-010**: The app MUST provide a clear empty state when no database exercises match the search and MUST allow the user to create a custom exercise from that state.
- **FR-010a**: Custom exercises MUST become searchable for the creating user immediately after creation.
- **FR-010b**: Custom exercises MUST be submitted for review before they can become available in the shared exercise database.
- **FR-011**: The app MUST preserve existing plan editing capabilities after an exercise is added, including set count changes, removal, and ordering where already supported.
- **FR-012**: The app MUST preserve existing paired-session plan behavior: each participant's selected exercises remain attached to that participant's own plan.
- **FR-013**: The app MUST include a curated exercise database before the feature is considered ready. The minimum catalog MUST contain at least 40 named exercises spanning at least 6 primary muscle-group or movement categories (compound push, compound pull, legs, shoulders, arms/isolation, and core). Catalog readiness is verified as part of Phase 6 quickstart validation (T054 and T051).
- **FR-014**: The app MUST handle unavailable or failed exercise loading with a visible retry path and without corrupting the current plan.

### Key Entities *(include if feature involves data)*

- **Exercise Database Entry**: A selectable exercise available to all users. Key information includes stable identity, display name, category or muscle group, equipment or distinguishing details, and search visibility.
- **Personal Exercise Entry**: A user-created exercise available to the creating user immediately. Key information includes user ownership, display name, chosen metadata if available, review status, and creation time.
- **Exercise Review Submission**: A custom exercise candidate awaiting review for possible inclusion in the shared exercise database. Key information includes submitted name, submitting user, review status, and relationship to the personal exercise entry.
- **Selected Exercise**: A user's chosen exercise for a session. For database exercises, it includes a reference to the database entry, display name snapshot, chosen set count, order within the plan, and source indicating that it came from the database. For custom exercises, it includes the user-entered name, chosen set count, order within the plan, and source indicating that it is custom.
- **Session Exercise Plan**: The ordered collection of selected exercises and set counts that a user builds before or during a session.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 95% of users can add a database exercise to a start-session plan in under 20 seconds after tapping "Add exercise".
- **SC-002**: 95% of searches for known exercise names, regardless of capitalization, return visible matching results in under 1 second under normal app conditions.
- **SC-003**: The same known exercise search produces consistent result names and distinguishing details in both start-session planning and session-end adding.
- **SC-004**: Users can add a late-session exercise, log its selected sets, and finish the session without losing existing planned or logged exercises.
- **SC-005**: Database-selected session plan entries store a database exercise identity, and custom entries are clearly marked as custom.
- **SC-005a**: After creating a custom exercise, the creating user can find and reuse it in a later exercise search without waiting for shared review.
- **SC-006**: In usability testing or QA runs, users can correctly add an exercise with a non-default set count in both flows without needing free-text entry.
- **SC-007**: Users cannot confirm an exercise with fewer than 1 set or more than 20 sets in either add-exercise flow.

## Assumptions

- This feature applies to gym exercise selection because the requested flows concern exercises and sets.
- The exercise database is a shared app-level catalog available to all users, not a per-user personal exercise list.
- Custom exercise creation is allowed only from the no-results state or explicit custom exercise action, not by silently accepting any search text.
- Existing non-gym session flows remain unchanged unless they already expose exercise-and-set planning.

## Terminology

The following spec terms map to implementation names used in plan.md and tasks.md:

| Spec Term | Implementation Name |
|-----------|---------------------|
| Exercise selection screen | `GymExercisePickerSheet` (bottom sheet widget) |
| Session completion / late-add stage | Session room / session-room late add |
| Exercise Database Entry | `ExerciseCatalogEntry` |
| Personal Exercise Entry | `PersonalExerciseEntry` |
| Exercise Review Submission | `ExerciseReviewSubmission` |
