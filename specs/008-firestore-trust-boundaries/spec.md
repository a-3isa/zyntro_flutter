# Feature Specification: Firestore trust boundaries (users list privacy)

**Feature Branch**: `008-firestore-trust-boundaries`  
**Created**: 2026-09-17  
**Status**: Draft  
**Input**: Align Firestore `users` list/search with private-profile ACL; public projection where needed; emulator tests denying private enumeration (**Z-SEC-001**, **Z-ENH-044**).

**Audit source**: `docs/audits/2026-09-17-full-audit.md` / findings JSON (`Z-SEC-001`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Private profiles stay private under queries (Priority: P1)

As a member with a private account, I need my profile document fields that `get` would deny to also be unavailable via any list/query so strangers cannot enumerate or scrape me.

**Why this priority**: Confirmed Critical privacy collapse — `allow get` uses `canReadUserProfile` while `allow list: if isAuthenticated()` lets any signed-in client query the collection.

**Independent Test**: Emulator rules test: private Alice is denied on `get`; Mallory’s `users` collection query / username-prefix style list also excludes Alice (or fails the query) with no private fields returned.

**Acceptance Scenarios**:

1. **Given** Alice’s user doc has `isPrivate == true` and Mallory is authenticated but not an approved follower, **When** Mallory attempts `get` on Alice’s user doc, **Then** the read is denied.
2. **Given** the same setup, **When** Mallory runs a list/query against `users` that would previously return Alice, **Then** Alice’s private doc is not readable (query denied or result set excludes Alice with no privileged/private fields leaked).
3. **Given** Bob is an approved follower of private Alice, **When** Bob `get`s or lists in a way the product needs for that relationship, **Then** Bob can read Alice’s allowed profile fields.

---

### User Story 2 - Discovery still works for public members (Priority: P1)

As a member searching for workout buddies, I can still find **public** profiles by username/search without breaking social discovery.

**Why this priority**: Closing list must not brick onboarding/social search for public accounts.

**Independent Test**: Emulator + client contract: public Charlie appears in the app’s search/list path; private Alice does not.

**Acceptance Scenarios**:

1. **Given** Charlie has a public profile (`isPrivate != true`), **When** Mallory searches/lists via the supported discovery API, **Then** Charlie’s public projection (or readable user fields) is returned.
2. **Given** private Alice, **When** Mallory uses the same discovery API, **Then** Alice is omitted.

---

### User Story 3 - Owner and moderator retain access (Priority: P2)

As the account owner or a moderator, I can still read my own (or moderated) user documents for settings and safety tooling.

**Why this priority**: ACL must remain complete for first-party and moderation flows.

**Independent Test**: Emulator: owner `get`/`list` of own doc succeeds; moderator `get` of private Alice succeeds per existing moderator claims helper.

**Acceptance Scenarios**:

1. **Given** Alice is signed in, **When** she reads her own user document, **Then** access is allowed.
2. **Given** a moderator principal, **When** they `get` a private user doc, **Then** access remains allowed per existing `isModerator()` rules.

---

### Edge Cases

- User flips `isPrivate` from false → true: in-flight clients must not keep listing them as public after rules evaluate the new value.
- Missing `isPrivate` field: treat consistently with `isPublicProfile` (today: not `true` ⇒ public).
- Username claim docs (`usernames/{username}`) must not become a backdoor to private profile payloads.
- Queries that cannot be expressed under tightened list rules must move to a **public projection** collection/index rather than widening `users` list again.
- Approved-follower relationship revoked: subsequent list/get for the ex-follower is denied.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Firestore rules for `users/{userId}` MUST apply the same authorization intent to `list` as to `get` with respect to private profiles (no authenticated-blanket list).
- **FR-002**: Private profiles MUST NOT be enumerable by non-owner, non-moderator, non-approved-follower clients via collection queries.
- **FR-003**: Public-profile discovery used by the app (username search / buddy find) MUST continue to return public members through a rules-safe path (tightened `users` queries and/or a dedicated public projection collection).
- **FR-004**: Client search code (`UserService` and any callers) MUST use only the approved discovery path after the rules change (no reliance on open `users` list).
- **FR-005**: Emulator rules tests MUST cover: private `get` deny, private list/query deny or exclusion, public discovery allow, owner allow, approved-follower allow.
- **FR-006**: Privileged user fields (scores, entitlements, moderator flags, etc.) remain subject to existing create/update denylists — this slice does not re-open client writes to those fields.
- **FR-007**: Deploy path for this slice MUST run rules emulator tests before releasing rules to production (CI gate or documented predeploy checklist).

### Key Entities

- **User profile (`users/{userId}`)**: Canonical member document; privacy via `isPrivate` and follower approval.
- **Public projection (optional new)**: Minimal searchable fields for public discovery if full `users` list cannot be safely queried.
- **Username claim (`usernames/{username}`)**: Maps username → uid without exposing private profile payloads.
- **Follow relationship**: Approved follower status gates private profile reads.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Emulator suite includes at least one failing-before / passing-after test proving private Alice cannot be read via list/query by Mallory.
- **SC-002**: Existing public username/buddy search flows still return public profiles in automated tests (no regression of public discovery).
- **SC-003**: Audit finding **Z-SEC-001** can be marked Fixed & verified with regression guard cited.
- **SC-004**: Abuse case “enumerate members / scrape private profiles” from the 2026-09-17 audit moves from Vulnerable to Mitigated for the `users` collection list vector.
- **SC-005**: Rules deploy to `zynrto` only after SC-001–SC-002 evidence is green.

## Assumptions

- Scope is **users list/search privacy** (Z-SEC-001 / Z-ENH-044). Server-authoritative scores (`Z-DATA-001` / `008-server-scores`) and session mode (`008-mode-derivation`) are **out of scope**.
- `isPublicProfile` / `canReadUserProfile` / `isApprovedFollowerOf` helpers remain the ACL source of truth unless a documented replacement is introduced in-plan.
- Production project is `zynrto`; local rules may already partially differ — this slice completes and proves the list/get parity.
- iOS `aps-environment` stays development per owner decision (unrelated to this slice).

## Constitution fit

- **I Slice discipline**: Single named domain — Firestore users list trust boundary.
- **II Evidence-first**: Emulator regression required before cutover (SC-001–SC-005).
- **III Security**: Critical privacy defect; no release of this slice with open Z-SEC-001.
- **IV Reversibility**: Prior rules revision retained in git; kill switch = redeploy previous rules file if discovery breaks.
- **V Independent deliverability**: Ships without waiting on score/server or mode-derivation slices.
