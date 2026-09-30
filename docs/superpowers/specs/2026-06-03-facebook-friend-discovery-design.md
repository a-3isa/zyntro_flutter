# Facebook Friend Discovery — Design Spec
**Date:** 2026-06-03  
**Branch:** 004-database-exercise-picker (to be implemented on a new branch)  
**Status:** Approved

---

## Goal

When a user signs up or connects their Facebook account, they see a "People You May Know" section in the Find tab showing their Facebook friends who have also installed Zyntro. Users who signed in via email or Google can connect Facebook from the Profile Settings screen or from a prompt in the Find tab.

---

## Scope

| In scope | Out of scope |
|---|---|
| Storing `facebookUid` in Firestore on FB sign-in/link | Firebase Auth `linkWithCredential` (sign-in with FB for email accounts) |
| Fetching `me/friends` from Graph API and cross-matching Zyntro users | Push notifications for "friend joined Zyntro" |
| "People You May Know" section in Find tab | Auto-following FB friends |
| "Connect Facebook" in Profile Settings | Cloud Function friend pre-computation |
| "Connect Facebook" banner in Find tab | Importing FB profile photo |
| Disconnect Facebook flow | |

---

## Data Model

### Firestore `users/{uid}` — two new fields

```
facebookUid: String?           // Facebook user ID (from FB SDK access token response)
facebookConnectedAt: Timestamp? // when the user linked their FB account
```

`authProvider` is unchanged — it still reflects the original sign-in method ("email", "google", "facebook").

### UserProfileEntity / UserProfileModel

Add two nullable fields:

```dart
final String? facebookUid;
final DateTime? facebookConnectedAt;
```

`UserProfileModel.fromMap()` and `toMap()` updated to read/write these fields. `copyWith()` updated accordingly.

---

## New Service: `FacebookLinkService`

**File:** `lib/services/facebook_link_service.dart`

Responsibilities:
- Connect Facebook: call FB login SDK, write `facebookUid` + `facebookConnectedAt` to Firestore
- Disconnect Facebook: clear both fields from Firestore
- Fetch Facebook friends on Zyntro: call Graph API `me/friends`, chunk IDs, query Firestore
- Expose connection state (is connected, facebookUid)

### `connectFacebook(String userId) → Result<List<UserProfileEntity>>`

1. Call `FacebookAuth.instance.login(permissions: ['public_profile', 'user_friends'])`
2. On success, extract `userId` from the Facebook `AccessToken` (the Facebook user ID, not the Zyntro UID)
3. Write to Firestore `users/{uid}`: `{ facebookUid: <fb_id>, facebookConnectedAt: now }`
4. Call `fetchFacebookFriendsOnApp(fbToken)` and return results
5. On cancel/error, return appropriate failure

### `disconnectFacebook(String userId) → Result<void>`

1. Call `FacebookAuth.instance.logOut()`
2. Clear `facebookUid` and `facebookConnectedAt` from Firestore `users/{uid}`

### `fetchFacebookFriendsOnApp(AccessToken token) → Result<List<UserProfileEntity>>`

1. Call `FacebookAuth.instance.graph('me/friends')` with the current token
2. Extract list of Facebook user IDs from response `data[].id`
3. If list is empty, return empty list
4. Chunk into groups of 10 (Firestore `whereIn` limit)
5. For each chunk: query `FirebaseFirestore.instance.collection('users').where('facebookUid', whereIn: chunk).get()`
6. Map results to `UserProfileEntity` via `UserProfileModel.fromMap()`
7. Return merged, deduplicated list

### `isFacebookConnected(UserProfileEntity profile) → bool`

Returns `profile.facebookUid != null`.

---

## Auto-Connect on Facebook Sign-In

**File:** `lib/features/auth/data/datasources/auth_remote_data_source.dart`

After `signInWithFacebook()` successfully creates/signs in the Firebase user:
1. Extract the Facebook user ID from the `FacebookAuthProvider` credential result or `FacebookAuth.instance.accessToken`
2. Write `facebookUid` and `facebookConnectedAt` to Firestore `users/{uid}` — same call as `FacebookLinkService.connectFacebook()`, but without the login dialog (token already exists)

This ensures any existing Facebook sign-in users who didn't previously have `facebookUid` stored get it written on their next sign-in automatically.

---

## UI Changes

### 1. Profile Settings — "Connected Accounts" Section

**File:** `lib/features/settings/presentation/settings_page.dart`

Add a new section below the existing settings list titled **"Connected Accounts"**.

**When Facebook is NOT connected:**
```
[ Facebook logo ] Connect Facebook        [ Connect → ]
```
Tapping calls `FacebookLinkService.connectFacebook()`. On success, shows a snackbar: *"Facebook connected! We found X friends on Zyntro."* (or *"Facebook connected."* if 0 friends).

**When Facebook IS connected:**
```
[ Facebook logo ] Facebook               [ Connected ✓ ]
                  Tap to disconnect
```
Tapping shows a confirmation dialog: *"Disconnect Facebook? You won't see Facebook friend suggestions."* → confirm clears the connection.

### 2. Find Tab — "People You May Know" Section

**File:** `lib/features/social/presentation/social_page.dart`

At the top of the Find tab content, before the search bar:

**When `facebookUid == null` (not connected):**
Show a dismissible banner:
```
┌─────────────────────────────────────────────────┐
│ 👥 Find friends from Facebook                   │
│ Connect your account to see who's on Zyntro  [Connect] │
└─────────────────────────────────────────────────┘
```
Banner is dismissed per-session (not persisted). Tapping "Connect" runs the same `FacebookLinkService.connectFacebook()` flow.

**When `facebookUid != null` and friends exist:**
```
People You May Know
─────────────────
[ Avatar | Name | Follow ]
[ Avatar | Name | Follow ]
...
```
Vertical list, max 10 entries, above the search bar. "Follow" button calls the existing `followService.followUser()`. Already-followed users are excluded from this list.

**When `facebookUid != null` and no friends:**
Section is hidden entirely — no empty-state shown (avoids looking broken).

### 3. Riverpod Provider

**File:** `lib/features/social/presentation/providers/` (new file `facebook_friends_provider.dart`)

```dart
final facebookFriendsProvider = FutureProvider.autoDispose<List<UserProfileEntity>>((ref) async {
  // 1. Read current user profile — if facebookUid is null, return empty list immediately
  // 2. Call FacebookLinkService.fetchFacebookFriendsOnApp() with current FB access token
  // 3. Read current user's follows, filter out already-followed UIDs
  // 4. Return remaining list
});
```

Invalidated from the UI layer (settings page and Find tab connect button) after `connectFacebook()` completes successfully, so the Find tab updates automatically without a manual refresh.

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| User cancels Facebook login dialog | Snackbar: "Facebook connection cancelled." No state change. |
| `user_friends` permission not granted | Store `facebookUid` (connection recorded), snackbar: "Friend access wasn't granted — reconnect to see friends." |
| No internet during friend fetch | Silently hide "People You May Know" section; no crash. |
| Firestore `whereIn` returns 0 results | Return empty list; section hidden. |
| Already following a FB friend | Excluded from the "People You May Know" list via follow-state filter. |
| FB token expired during `me/friends` call | Treat as "not connected"; prompt to reconnect. |

---

## Facebook App Review Note

The `user_friends` permission requires Facebook App Review approval for production use. In development mode, it works for app testers and developers. The feature should be built and tested in dev mode; App Review must be submitted before public release.

---

## Files Touched

| File | Change |
|---|---|
| `lib/core/models/models.dart` | Re-export new fields |
| `lib/features/auth/domain/entities/user_profile_entity.dart` | Add `facebookUid`, `facebookConnectedAt` |
| `lib/features/auth/data/models/user_profile_model.dart` | Serialize/deserialize new fields |
| `lib/features/auth/data/datasources/auth_remote_data_source.dart` | Write `facebookUid` after FB sign-in |
| `lib/services/facebook_link_service.dart` | New service (connect, disconnect, fetch friends) |
| `lib/features/social/presentation/social_page.dart` | Add banner + "People You May Know" section to Find tab |
| `lib/features/social/presentation/providers/facebook_friends_provider.dart` | New Riverpod provider |
| `lib/features/settings/presentation/settings_page.dart` | Add "Connected Accounts" section |
| `firebase/firestore.rules` | Allow users to read/write their own `facebookUid` field |

---

## Testing

- Unit test `FacebookLinkService.fetchFacebookFriendsOnApp()` with mocked FB response + mocked Firestore
- Widget test for Find tab: banner shown when not connected, list shown when connected with friends, section hidden when no friends
- Widget test for Settings: "Connect" tile when not connected, "Connected" + disconnect flow when connected
- Contract test: `users` collection read/write with `facebookUid` field respects Firestore rules
