# Feature Specification: Match & turn integrity

**Branch**: `012-match-turn-integrity`  
**Input**: Z-RT-002, Z-RT-003, Z-SEC-003

## Requirements

- **FR-001**: `switchTurn` updates `activeUserId` inside a Firestore transaction; only succeeds when caller is still `activeUserId`.
- **FR-002**: Matchmaking skips partners the caller has blocked; claim updates require `isNotBlockedPair`.
- **FR-003**: Matchmaking queue claimer updates use a field allowlist.
