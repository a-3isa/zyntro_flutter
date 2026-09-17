# Feature Specification: In-app review after 3rd buddy session

**Branch**: `013-in-app-review`  
**Input**: Z-ENH-017

## Requirements

- **FR-001**: After each completed real-friend buddy session, increment a local counter.
- **FR-002**: On the 3rd such completion, request the platform in-app review if available.
- **FR-003**: Never prompt again after a successful request attempt.
- **FR-004**: Bot / solo sessions do not count.
