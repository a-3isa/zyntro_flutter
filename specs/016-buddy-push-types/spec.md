# Feature Specification: Buddy push types

**Branch**: `016-buddy-push-types`  
**Input**: Z-NOTIF-001

## Requirements

- **FR-001**: CF `buildPushPayload` supports `buddy_invite`, `buddy_accepted`, `buddy_session`.
- **FR-002**: CF preference gate honours `buddyInvites`.
- **FR-003**: Client buddy notify methods only call CF (no cross-user inbox writes).
