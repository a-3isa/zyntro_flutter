# Contract: users list ACL

## Rules surface (`firebase/firestore.rules`)

### `match /users/{userId}`

| Op | Required behavior after this slice |
|----|-----------------------------------|
| `get` | Unchanged: `isAuthenticated() && canReadUserProfile(userId)` |
| `list` | **Must not** be `isAuthenticated()` alone. Must deny strangers listing docs where `resource.data.get('isPrivate', false) == true`, except owner/moderator. |
| `create`/`update`/`delete` | Unchanged privileged denylists (FR-006). |

### Discovery query (client)

`UserService.searchUsers` (and equivalents) MUST:

1. Require auth (existing).
2. Constrain `isPrivate == false`.
3. Keep username prefix bounds + `limit(10)`.
4. Map docs through existing `User.fromFirestore` without assuming private fields appear.

### Emulator probes (required)

| Case | Expect |
|------|--------|
| Mallory `get` private Alice | Denied |
| Mallory query `users` where username prefix matches Alice (private) without/with filters | Denied or empty; **no** Alice doc data |
| Mallory search query with `isPrivate == false` for public Charlie | Allowed; Charlie present |
| Alice `get` self | Allowed |
| Moderator `get` private Alice | Allowed (existing claims helper) |
| Bob approved follower `get` private Alice | Allowed |

## Non-goals

- Server score/streak writes
- Changing `usernames` list to true
- iOS push entitlements
