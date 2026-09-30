# Feature Specification: Auth email enumeration hardening

**Branch**: `015-auth-enum-hardening`  
**Input**: Z-AUTH-001

## Requirements

- **FR-001**: Login maps `user-not-found` to the same message as bad password.
- **FR-002**: Signup copy does not say "already exists" bluntly.
- **FR-003**: Password reset treats missing users as success.
