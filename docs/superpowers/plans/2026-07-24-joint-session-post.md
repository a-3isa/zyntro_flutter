# Joint Session Post Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let two humans who trained a paired session publish it as **one co-authored post** that appears on both profiles, with side-by-side photos, each author's own caption, both session activities, and mutual (both-tap-Post) consent.

**Architecture:** A single `posts/{id}` document gains a co-author shape (`authorIds`, `authors.{uid}` sub-blocks, `status`). The recap screen becomes a side-by-side composer over a **draft** post; each author writes their slot (photo + caption + public/private) and taps Post. A Cloud Function flips the draft to **published** only when both `confirmed` are true, and a scheduled function expires stale drafts (24h) and offers the confirmed author a solo repost. Profiles/feed query posts by `authorIds array-contains uid` filtered to `status == published` and the caller's slot not `removed`. Solo posts keep working unchanged — they simply carry `authorIds: [author]`, `status: 'published'`, and no `authors` map.

**Tech Stack:** Flutter, Riverpod, Cloud Firestore, Firebase Cloud Functions (2nd gen, Node 22), FCM, existing `PostService` / `MediaService` / `NotificationService`.

## Global Constraints

- Solo (single-human, bot, or matchmaking-solo) sessions keep today's behavior exactly: one post, visibility follows profile type. Only **two-human paired sessions** create a joint draft.
- Visibility rule: each author picks public/private in the composer; **if either picks private, the published post is private.**
- Consent: post publishes **only when both authors' `confirmed == true`.** Enforced server-side (a client must never be able to publish a joint post alone).
- Missing photo → that author's slot renders their **profile picture** at display time (no photo is uploaded, the slot just falls back).
- Draft expiry: **24h**. On expiry the author(s) who confirmed are offered a normal solo post.
- Delete: each author removes **only their own slot** (`authors.{uid}.removed = true`). The post stays while ≥1 non-removed author remains; when all are removed a CF deletes the doc.
- Firestore transactions: all reads before all writes.
- Rules changes must be mirrored in `test/firebase/firestore_rules_contract_test.dart`.
- Caveman mode is a chat-style preference only; code, comments, commits, and this plan are written normally.

---

## File Structure

**Data / domain**
- `lib/core/models/models.dart` — extend `Post` with `authorIds`, `status`, `coAuthored`, `authors` (`Map<String, PostAuthorSlot>`); add `PostAuthorSlot` model. Solo fields stay.
- `lib/features/session/domain/joint_post_draft.dart` (create) — pure helpers: `bool bothConfirmed(...)`, `String resolveJointVisibility(...)`, `List<String> activeAuthorIds(...)`.

**Service**
- `lib/services/post_service.dart` — add `createJointDraft`, `setAuthorSlot`, `confirmJointPost`, `removeAuthorSlot`, `watchJointDraft`; change author queries to `authorIds array-contains` + `status == 'published'` + slot-not-removed; write `authorIds`/`status` on the existing solo `createPost`.
- `lib/services/notification_service.dart` — add `jointPostInvite` send.

**Cloud Functions**
- `functions/index.js` — `publishJointPostWhenBothConfirm` (onDocumentUpdated), `expireStaleJointPostDrafts` (onSchedule 15 min), `cleanupFullyRemovedJointPosts` (onDocumentUpdated).

**Rules**
- `firebase/firestore.rules` — rewrite `match /posts/{postId}` for co-author create/update/delete + draft/publish gating.
- `firebase/firestore.indexes.json` — composite index `authorIds array-contains + createdAt desc` and `authorIds + status + createdAt`.

**UI**
- `lib/features/session/presentation/recap_page.dart` — branch: paired-human session → joint composer; else unchanged.
- `lib/features/session/presentation/widgets/joint_post_composer.dart` (create) — side-by-side two-slot composer.
- `lib/widgets/post_card_widget.dart` — co-authored rendering (stacked avatars, "A with B", two photos, both captions, both activities).

**Tests**
- `test/features/session/domain/joint_post_draft_test.dart`
- `test/services/post_service_joint_test.dart`
- `test/features/session/presentation/widgets/joint_post_composer_test.dart`
- `test/widgets/post_card_joint_test.dart`
- `test/firebase/firestore_rules_contract_test.dart` (extend)

---

## Task 1: Domain model — PostAuthorSlot + Post co-author fields

**Files:**
- Modify: `lib/core/models/models.dart` (the `Post` class, ~649-703)
- Test: `test/core/models/post_coauthor_test.dart` (create)

**Interfaces:**
- Produces:
  - `class PostAuthorSlot { final String userId; final String? caption; final String? photoUrl; final bool confirmed; final bool removed; final SessionSummary summary; final String visibility; PostAuthorSlot.fromMap(Map); Map<String,dynamic> toMap(); }`
  - `Post` gains: `final List<String> authorIds; final String status; final bool coAuthored; final Map<String, PostAuthorSlot> authors;` (all parsed in `fromFirestore`, defaulting so existing solo docs still parse: `authorIds` defaults to `[authorId]`, `status` to `'published'`, `coAuthored` to `false`, `authors` to `{}`).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/models/post_coauthor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/models/models.dart';

void main() {
  test('legacy solo post doc parses with defaults', () {
    final p = Post.fromMap('p1', {
      'authorId': 'ahmed', 'sessionId': 's1', 'visibility': 'public',
      'title': 'Leg day', 'type': 'strength', 'summary': {}, 'likesCount': 0,
      'commentsCount': 0,
    });
    expect(p.authorIds, ['ahmed']);
    expect(p.status, 'published');
    expect(p.coAuthored, false);
    expect(p.authors, isEmpty);
  });

  test('co-authored draft doc parses author slots', () {
    final p = Post.fromMap('p2', {
      'authorIds': ['ahmed', 'mohamed'], 'coAuthored': true, 'status': 'draft',
      'sessionId': 's1', 'visibility': 'public', 'title': 'Push day',
      'type': 'strength', 'summary': {}, 'likesCount': 0, 'commentsCount': 0,
      'authors': {
        'ahmed':  {'userId':'ahmed','caption':'PR!','photoUrl':null,'confirmed':true,'removed':false,'visibility':'public','summary':{}},
        'mohamed':{'userId':'mohamed','caption':null,'photoUrl':null,'confirmed':false,'removed':false,'visibility':'private','summary':{}},
      },
    });
    expect(p.coAuthored, true);
    expect(p.authors['ahmed']!.confirmed, true);
    expect(p.authors['mohamed']!.visibility, 'private');
  });
}
```

Note: this task also adds a `Post.fromMap(String id, Map data)` factory (extract the body of the existing `fromFirestore` so it is unit-testable without a `DocumentSnapshot`). `fromFirestore` becomes `Post.fromMap(doc.id, doc.data())`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/models/post_coauthor_test.dart`
Expected: FAIL — `Post.fromMap` undefined / fields missing.

- [ ] **Step 3: Add `PostAuthorSlot` + extend `Post`**

Add before `class Post`:

```dart
class PostAuthorSlot {
  final String userId;
  final String? caption;
  final String? photoUrl;
  final bool confirmed;
  final bool removed;
  final String visibility; // this author's chosen 'public' | 'private'
  final SessionSummary summary;

  const PostAuthorSlot({
    required this.userId,
    this.caption,
    this.photoUrl,
    this.confirmed = false,
    this.removed = false,
    this.visibility = 'public',
    required this.summary,
  });

  factory PostAuthorSlot.fromMap(Map<String, dynamic> d) => PostAuthorSlot(
        userId: d['userId'] ?? '',
        caption: d['caption'],
        photoUrl: d['photoUrl'],
        confirmed: d['confirmed'] ?? false,
        removed: d['removed'] ?? false,
        visibility: d['visibility'] ?? 'public',
        summary: SessionSummary.fromMap(d['summary'] ?? const {}),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'caption': caption,
        'photoUrl': photoUrl,
        'confirmed': confirmed,
        'removed': removed,
        'visibility': visibility,
        'summary': summary.toMap(),
      };
}
```

In `Post` add fields `authorIds`, `status`, `coAuthored`, `authors` (constructor params with defaults), then replace `fromFirestore` with a `fromMap`:

```dart
factory Post.fromFirestore(DocumentSnapshot doc) =>
    Post.fromMap(doc.id, doc.data() as Map<String, dynamic>);

factory Post.fromMap(String id, Map<String, dynamic> data) {
  final authorId = data['authorId'] ?? '';
  return Post(
    id: id,
    authorId: authorId,
    authorIds: (data['authorIds'] as List<dynamic>?)?.cast<String>() ??
        (authorId.isEmpty ? const [] : [authorId]),
    status: data['status'] ?? 'published',
    coAuthored: data['coAuthored'] ?? false,
    authors: (data['authors'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, PostAuthorSlot.fromMap(v as Map<String, dynamic>)),
        ) ?? const {},
    sessionId: data['sessionId'] ?? '',
    visibility: data['visibility'] ?? 'public',
    title: data['title'] ?? '',
    type: data['type'] ?? 'strength',
    summary: SessionSummary.fromMap(data['summary'] ?? {}),
    mediaURLs: (data['mediaURLs'] as List<dynamic>?)?.cast<String>(),
    buddyId: data['buddyId'],
    buddyName: data['buddyName'],
    likesCount: data['likesCount'] ?? 0,
    commentsCount: data['commentsCount'] ?? 0,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    reactionCounts: (data['reactionCounts'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as int)),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/models/post_coauthor_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze lib/core/models/models.dart`
```bash
git add lib/core/models/models.dart test/core/models/post_coauthor_test.dart
git commit -m "feat(post): add co-author fields + PostAuthorSlot to Post model"
```

---

## Task 2: Pure draft helpers

**Files:**
- Create: `lib/features/session/domain/joint_post_draft.dart`
- Test: `test/features/session/domain/joint_post_draft_test.dart`

**Interfaces:**
- Produces:
  - `bool bothConfirmed(Map<String, PostAuthorSlot> authors)` — true iff every non-removed slot has `confirmed == true` and there are ≥2 non-removed authors.
  - `String resolveJointVisibility(Map<String, PostAuthorSlot> authors)` — `'private'` if any non-removed slot chose `'private'`, else `'public'`.
  - `List<String> activeAuthorIds(Map<String, PostAuthorSlot> authors)` — non-removed userIds.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/session/domain/joint_post_draft.dart';

PostAuthorSlot slot(String id, {bool c = false, bool r = false, String v = 'public'}) =>
    PostAuthorSlot(userId: id, confirmed: c, removed: r, visibility: v, summary: SessionSummary());

void main() {
  test('bothConfirmed only when all active slots confirmed', () {
    expect(bothConfirmed({'a': slot('a', c: true), 'b': slot('b', c: false)}), false);
    expect(bothConfirmed({'a': slot('a', c: true), 'b': slot('b', c: true)}), true);
  });
  test('removed slot is ignored by bothConfirmed', () {
    expect(bothConfirmed({'a': slot('a', c: true), 'b': slot('b', r: true)}), false); // <2 active
  });
  test('resolveJointVisibility private wins', () {
    expect(resolveJointVisibility({'a': slot('a', v: 'public'), 'b': slot('b', v: 'private')}), 'private');
    expect(resolveJointVisibility({'a': slot('a', v: 'public'), 'b': slot('b', v: 'public')}), 'public');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/session/domain/joint_post_draft_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement**

```dart
import '../../../core/models/models.dart';

List<String> activeAuthorIds(Map<String, PostAuthorSlot> authors) =>
    authors.values.where((s) => !s.removed).map((s) => s.userId).toList();

bool bothConfirmed(Map<String, PostAuthorSlot> authors) {
  final active = authors.values.where((s) => !s.removed).toList();
  return active.length >= 2 && active.every((s) => s.confirmed);
}

String resolveJointVisibility(Map<String, PostAuthorSlot> authors) =>
    authors.values.any((s) => !s.removed && s.visibility == 'private')
        ? 'private'
        : 'public';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/session/domain/joint_post_draft_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/session/domain/joint_post_draft.dart test/features/session/domain/joint_post_draft_test.dart
git commit -m "feat(post): pure helpers for joint-draft confirm/visibility"
```

---

## Task 3: PostService — joint draft lifecycle + author-scoped queries

**Files:**
- Modify: `lib/services/post_service.dart` (createPost ~107, getUserPosts ~233, watchUserPosts ~245, getPublicFeedPosts/getPublicPosts ~190-228)
- Test: `test/services/post_service_joint_test.dart` (create; uses `fake_cloud_firestore` as other service tests do — confirm the dependency is already in `dev_dependencies`, add if missing)

**Interfaces:**
- Consumes: `PostAuthorSlot`, `bothConfirmed`, `resolveJointVisibility` (Tasks 1-2).
- Produces on `PostService`:
  - `Future<String> createJointDraft({required String sessionId, required String type, required String title, required List<String> authorIds, required Map<String, SessionSummary> summaries, required Duration ttl})` — creates one `posts/{id}` with `coAuthored:true, status:'draft', authorIds`, an `authors` map seeded with each author's `summary` and defaults (`confirmed:false, removed:false, visibility:'public'`), `expiresAt = now + ttl`. Returns postId. Idempotent per session: if a draft with this `sessionId` already exists, returns its id instead of creating a second.
  - `Future<void> setAuthorSlot({required String postId, required String userId, String? caption, String? photoUrl, String? visibility})` — updates only `authors.$userId.{caption,photoUrl,visibility}` (each field only when non-null).
  - `Future<void> confirmJointPost({required String postId, required String userId})` — sets `authors.$userId.confirmed = true`.
  - `Future<void> removeAuthorSlot({required String postId, required String userId})` — sets `authors.$userId.removed = true`.
  - `Stream<Post> watchJointDraft(String postId)`.
- Modified queries: `getUserPosts`, `watchUserPosts` change `where('authorId', isEqualTo: userId)` → `where('authorIds', arrayContains: userId).where('status', isEqualTo: 'published')`, then in Dart drop posts where `post.authors[userId]?.removed == true`. `getPublicFeedPosts`/`getPublicPosts` add `.where('status', isEqualTo: 'published')`. The existing solo `createPost` must now also write `'authorIds': [params.authorId], 'status': 'published', 'coAuthored': false`.

- [ ] **Step 1: Write the failing test** (draft lifecycle with `fake_cloud_firestore`)

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
// ... construct PostService with the fake (mirror the pattern in existing post_service tests)

void main() {
  test('createJointDraft then both confirm marks both slots confirmed', () async {
    // create draft for ['ahmed','mohamed']
    // confirmJointPost ahmed; confirmJointPost mohamed
    // read doc: authors.ahmed.confirmed == true && authors.mohamed.confirmed == true, status still 'draft'
    //   (publish transition is the CF's job, Task 6 — not the client's)
  });
  test('getUserPosts excludes drafts and removed slots', () async {
    // seed a published co-post with ahmed removed -> getUserPosts('ahmed') empty, getUserPosts('mohamed') has it
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/post_service_joint_test.dart`
Expected: FAIL — methods undefined.

- [ ] **Step 3: Implement the service methods + query changes**

`createJointDraft` (real code):

```dart
Future<String> createJointDraft({
  required String sessionId,
  required String type,
  required String title,
  required List<String> authorIds,
  required Map<String, SessionSummary> summaries,
  Duration ttl = const Duration(hours: 24),
}) async {
  // Idempotent: one draft per session.
  final existing = await _firestore
      .collection('posts')
      .where('sessionId', isEqualTo: sessionId)
      .where('coAuthored', isEqualTo: true)
      .limit(1)
      .get();
  if (existing.docs.isNotEmpty) return existing.docs.first.id;

  final ref = _firestore.collection('posts').doc();
  final authors = <String, dynamic>{
    for (final uid in authorIds)
      uid: PostAuthorSlot(userId: uid, summary: summaries[uid] ?? SessionSummary()).toMap(),
  };
  await ref.set({
    'coAuthored': true,
    'status': 'draft',
    'authorIds': authorIds,
    'authorId': authorIds.first, // legacy field, harmless
    'sessionId': sessionId,
    'type': type,
    'title': title,
    'visibility': 'public',
    'summary': (summaries[authorIds.first] ?? SessionSummary()).toMap(),
    'authors': authors,
    'mediaURLs': <String>[],
    'likesCount': 0,
    'commentsCount': 0,
    'createdAt': FieldValue.serverTimestamp(),
    'expiresAt': Timestamp.fromDate(DateTime.now().add(ttl)),
  });
  return ref.id;
}

Future<void> setAuthorSlot({
  required String postId, required String userId,
  String? caption, String? photoUrl, String? visibility,
}) async {
  final data = <String, dynamic>{};
  if (caption != null) data['authors.$userId.caption'] = caption;
  if (photoUrl != null) data['authors.$userId.photoUrl'] = photoUrl;
  if (visibility != null) data['authors.$userId.visibility'] = visibility;
  if (data.isEmpty) return;
  await _firestore.collection('posts').doc(postId).update(data);
}

Future<void> confirmJointPost({required String postId, required String userId}) =>
    _firestore.collection('posts').doc(postId)
        .update({'authors.$userId.confirmed': true});

Future<void> removeAuthorSlot({required String postId, required String userId}) =>
    _firestore.collection('posts').doc(postId)
        .update({'authors.$userId.removed': true});

Stream<Post> watchJointDraft(String postId) => _firestore
    .collection('posts').doc(postId).snapshots()
    .map((d) => Post.fromFirestore(d));
```

Query edits: add `.where('status', isEqualTo: 'published')` to public feed queries; in `getUserPosts`/`watchUserPosts` swap to `arrayContains` + status filter, then `.where((p) => p.authors[userId]?.removed != true)` in Dart. In solo `createPost` add the three fields to `postData`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/post_service_joint_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze lib/services/post_service.dart`
```bash
git add lib/services/post_service.dart test/services/post_service_joint_test.dart
git commit -m "feat(post): joint-draft lifecycle + author-scoped queries in PostService"
```

---

## Task 4: Firestore rules — co-author create/update/delete + publish gating

**Files:**
- Modify: `firebase/firestore.rules` (`match /posts/{postId}`, 313-317)
- Test: `test/firebase/firestore_rules_contract_test.dart` (extend — source-string assertions like the existing tests in that file)

**Interfaces:**
- Produces rule guarantees:
  - **create**: solo post — `authorId == uid` (unchanged path). Joint draft — `coAuthored == true`, `status == 'draft'`, caller is in `authorIds`, `authorIds.size() == 2`, `authors` keys equal `authorIds`.
  - **update**: an author may write only their own `authors.$uid.*` sub-fields (`caption`, `photoUrl`, `visibility`, `confirmed`, `removed`) plus never change `authorIds`/`coAuthored`/`sessionId`. A **client may never set `status`** on a co-authored post (only the CF, which bypasses rules, may publish). Likes/comments counters keep their existing allowances.
  - **delete**: unchanged (`authorId == uid`) — joint deletes go through `removed` flags + CF cleanup, never a client delete.

- [ ] **Step 1: Write the failing contract test**

```dart
test('posts rules gate joint draft create + own-slot-only update + no client publish', () {
  final src = File('firebase/firestore.rules').readAsStringSync();
  expect(src, contains('isJointDraftCreate()'));
  expect(src, contains('isOwnAuthorSlotUpdate()'));
  // client can never set status on a coAuthored post:
  expect(src, contains("!request.resource.data.diff(resource.data).affectedKeys().hasAny(['status'])"));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/firebase/firestore_rules_contract_test.dart -p vm --plain-name "joint draft"`
Expected: FAIL.

- [ ] **Step 3: Rewrite the posts rules**

```
match /posts/{postId} {
  allow read: if isAuthenticated();

  function isSoloCreate() {
    return request.resource.data.authorId == request.auth.uid &&
      (request.resource.data.coAuthored != true);
  }
  function isJointDraftCreate() {
    return request.resource.data.coAuthored == true &&
      request.resource.data.status == 'draft' &&
      request.resource.data.authorIds.size() == 2 &&
      request.resource.data.authorIds.hasAny([request.auth.uid]) &&
      request.resource.data.authors.keys().hasAll(request.resource.data.authorIds) &&
      request.resource.data.authorIds.hasAll(request.resource.data.authors.keys());
  }
  allow create: if isAuthenticated() && (isSoloCreate() || isJointDraftCreate());

  function frozenPostFields() {
    return ['authorIds', 'coAuthored', 'sessionId', 'authorId'];
  }
  function isOwnAuthorSlotUpdate() {
    // Only this author's authors.<uid>.* changed; identity + status frozen.
    return resource.data.coAuthored == true &&
      request.resource.data.authorIds.hasAny([request.auth.uid]) &&
      !request.resource.data.diff(resource.data).affectedKeys().hasAny(frozenPostFields()) &&
      !request.resource.data.diff(resource.data).affectedKeys().hasAny(['status']) &&
      request.resource.data.authors.diff(resource.data.authors).affectedKeys().hasOnly([request.auth.uid]);
  }
  allow update: if isAuthenticated() && (
    (resource.data.authorId == request.auth.uid && resource.data.coAuthored != true) ||
    isOwnAuthorSlotUpdate()
    // (existing like/comment counter allowances, if any, kept here)
  );

  allow delete: if isAuthenticated() && resource.data.authorId == request.auth.uid
    && resource.data.coAuthored != true;

  // ... existing comments/reactions subcollection rules unchanged ...
}
```

- [ ] **Step 4: Run test + deploy-check**

Run: `flutter test test/firebase/firestore_rules_contract_test.dart`
Expected: PASS.
Run: `firebase deploy --only firestore:rules --dry-run` (or `firebase firestore:rules:canary` if configured) to confirm the rules compile. Do NOT deploy yet — deployment is a manual step after review.

- [ ] **Step 5: Commit**

```bash
git add firebase/firestore.rules test/firebase/firestore_rules_contract_test.dart
git commit -m "feat(post): firestore rules for joint-post create/own-slot update; block client publish"
```

---

## Task 5: Firestore indexes

**Files:**
- Modify: `firebase/firestore.indexes.json`
- Test: none (config only; verified by the query in Task 3 at runtime).

- [ ] **Step 1: Add composite indexes**

Add to the `indexes` array:

```json
{ "collectionGroup": "posts", "queryScope": "COLLECTION", "fields": [
  { "fieldPath": "authorIds", "arrayConfig": "CONTAINS" },
  { "fieldPath": "status", "order": "ASCENDING" },
  { "fieldPath": "createdAt", "order": "DESCENDING" } ] },
{ "collectionGroup": "posts", "queryScope": "COLLECTION", "fields": [
  { "fieldPath": "visibility", "order": "ASCENDING" },
  { "fieldPath": "status", "order": "ASCENDING" },
  { "fieldPath": "createdAt", "order": "DESCENDING" } ] }
```

- [ ] **Step 2: Commit** (deploy is a manual step later)

```bash
git add firebase/firestore.indexes.json
git commit -m "feat(post): composite indexes for author-scoped + public published queries"
```

---

## Task 6: Cloud Functions — publish gate, expiry, cleanup

**Files:**
- Modify: `functions/index.js`
- Test: manual (emulator) — Firebase CF unit tests are not set up in this repo; add a short emulator checklist to the PR description.

**Interfaces:**
- Produces:
  - `publishJointPostWhenBothConfirm` — `onDocumentUpdated('posts/{postId}')`: if `coAuthored && status == 'draft'` and every non-removed author slot `confirmed`, set `status: 'published'`, `visibility` = private-if-any-private, `createdAt: now`. Uses admin SDK (bypasses rules).
  - `expireStaleJointPostDrafts` — `onSchedule('every 15 minutes')`: drafts with `status == 'draft'` and `expiresAt < now` → set `status: 'expired'`; for each author with `confirmed == true`, send a `jointPostInvite`-style "post it solo?" notification (Task 7 delivery path).
  - `cleanupFullyRemovedJointPosts` — `onDocumentUpdated('posts/{postId}')`: if `coAuthored` and every author slot `removed` → delete the doc.

- [ ] **Step 1: Implement `publishJointPostWhenBothConfirm`**

```js
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");

exports.publishJointPostWhenBothConfirm = onDocumentUpdated("posts/{postId}", async (event) => {
  const after = event.data.after.data();
  if (!after || after.coAuthored !== true || after.status !== "draft") return;
  const authors = Object.values(after.authors || {});
  const active = authors.filter((a) => !a.removed);
  if (active.length < 2 || !active.every((a) => a.confirmed === true)) return;
  const anyPrivate = active.some((a) => a.visibility === "private");
  await event.data.after.ref.update({
    status: "published",
    visibility: anyPrivate ? "private" : "public",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});
```

- [ ] **Step 2: Implement `expireStaleJointPostDrafts` + `cleanupFullyRemovedJointPosts`**

```js
exports.expireStaleJointPostDrafts = onSchedule("every 15 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  const snap = await admin.firestore().collection("posts")
    .where("coAuthored", "==", true).where("status", "==", "draft")
    .where("expiresAt", "<", now).get();
  for (const doc of snap.docs) {
    await doc.ref.update({ status: "expired" });
    const authors = Object.values(doc.data().authors || {});
    for (const a of authors.filter((x) => x.confirmed && !x.removed)) {
      // reuse the push path used by deliverNotificationPush / recipientAllowsPush
      await sendSoloRepostOffer(a.userId, doc.id, doc.data().sessionId);
    }
  }
});

exports.cleanupFullyRemovedJointPosts = onDocumentUpdated("posts/{postId}", async (event) => {
  const after = event.data.after.data();
  if (!after || after.coAuthored !== true) return;
  const authors = Object.values(after.authors || {});
  if (authors.length > 0 && authors.every((a) => a.removed === true)) {
    await event.data.after.ref.delete();
  }
});
```

`sendSoloRepostOffer` writes a notification doc of a new type `jointPostExpired` (owner-only create by the CF) that deep-links the recap/solo-share screen.

- [ ] **Step 3: Lint**

Run: `cd functions && npx eslint index.js` (or the repo's configured lint). Fix issues.

- [ ] **Step 4: Commit** (deploy is a manual step later)

```bash
git add functions/index.js
git commit -m "feat(post): CFs to publish joint post on dual-confirm, expire stale drafts, cleanup"
```

---

## Task 7: Notification — "join the post" + "post it solo"

**Files:**
- Modify: `lib/services/notification_service.dart`, `functions/index.js` (recipientAllowsPush type list if gated)
- Test: `test/services/notification_service_logging_contract_test.dart` (extend if it enumerates types)

**Interfaces:**
- Produces: `NotificationService.sendJointPostInvite({required String recipientId, required String fromName, required String postId, required String sessionId})` — writes an owner-authored notification (per the existing owner-only notifications model) whose tap deep-links `recap/joint?postId=...`. And a `jointPostExpired` type (sent by the CF) linking the solo-share screen.

- [ ] **Step 1: Write the failing test** (assert the new type strings exist where types are enumerated)
- [ ] **Step 2: Run → fails**
- [ ] **Step 3: Implement the send method + register the type**
- [ ] **Step 4: Run → passes**
- [ ] **Step 5: Commit**

```bash
git commit -am "feat(post): joint-post invite + expiry notification types"
```

---

## Task 8: Recap branches to the joint composer

**Files:**
- Modify: `lib/features/session/presentation/recap_page.dart` (`_handleShare` ~234, build)
- Test: `test/features/session/presentation/recap_joint_branch_test.dart` (create)

**Interfaces:**
- Consumes: `createJointDraft`, `watchJointDraft` (Task 3); `JointPostComposer` (Task 9).
- Produces: recap decides — if the session is a **two-human paired session** (`session.partnerKind == PairedPartnerKind.realFriend` OR a two-human matchmaking pair; NOT bot) → on entering the share step it calls `createJointDraft` (idempotent) with both authors' summaries and renders `JointPostComposer(postId: draftId)` instead of the solo share card. Solo path unchanged.

- [ ] **Step 1: Write the failing widget test** — a paired-human session renders `JointPostComposer`; a solo session renders the existing solo share card.
- [ ] **Step 2: Run → fails**
- [ ] **Step 3: Implement the branch** (guard: only when both participants are human; derive summaries per author from the session).
- [ ] **Step 4: Run → passes**
- [ ] **Step 5: Analyze + commit**

```bash
git commit -am "feat(post): recap creates a joint draft + shows the composer for paired sessions"
```

---

## Task 9: JointPostComposer — side-by-side two-slot UI

**Files:**
- Create: `lib/features/session/presentation/widgets/joint_post_composer.dart`
- Test: `test/features/session/presentation/widgets/joint_post_composer_test.dart`

**Interfaces:**
- Consumes: `watchJointDraft`, `setAuthorSlot`, `confirmJointPost` (Task 3); `MediaService.uploadPostPhoto` (existing).
- Produces: `class JointPostComposer extends ConsumerStatefulWidget { final String postId; }` — streams the draft; renders **two slots side by side** (`Row` of two `Expanded`): left = current user's slot (camera/gallery button, caption `TextField`, public/private toggle, a **Post** button that uploads the photo → `setAuthorSlot` → `confirmJointPost`), right = partner's slot (their photo or **profile-picture fallback**, their caption, a live status — "waiting…", "ready", or "posted ✓"). Header shows "You with {partner}" + stacked avatars. When both `confirmed` the CF publishes and the screen routes to `/?tab=feed` with a "Posted together" confirmation. On narrow widths the two slots stack but keep the same order (you first).

- [ ] **Step 1: Write the failing widget test** — renders both slots; tapping Post with a caption calls `setAuthorSlot` then `confirmJointPost`; partner slot with no photo shows the profile-picture fallback; both-confirmed shows the "Posted together" state.
- [ ] **Step 2: Run → fails**
- [ ] **Step 3: Implement the composer** (reuse the existing photo-pick + upload-progress code from `recap_page.dart`; mic/voice UI is not on this screen — this is post-session).
- [ ] **Step 4: Run → passes**
- [ ] **Step 5: Analyze + commit**

```bash
git commit -am "feat(post): side-by-side joint post composer with live partner slot"
```

---

## Task 10: Feed/profile card renders co-authored posts

**Files:**
- Modify: `lib/widgets/post_card_widget.dart`
- Test: `test/widgets/post_card_joint_test.dart`

**Interfaces:**
- Consumes: `Post.coAuthored`, `Post.authors`, `Post.authorIds`.
- Produces: when `post.coAuthored`, the card header shows "**{A} with {B}**" + stacked avatars; the media area shows **two photos side by side** (each author's `photoUrl`, or their **profile picture** when null, skipping any `removed` author); both captions render attributed; an expandable "Session activity" shows both authors' `summary`. Non-co-authored posts render exactly as today.

- [ ] **Step 1: Write the failing widget test** — a co-authored post shows both names, two images (or profile-pic fallback), both captions; a removed author is omitted; a solo post is unchanged.
- [ ] **Step 2: Run → fails**
- [ ] **Step 3: Implement the co-authored branch**
- [ ] **Step 4: Run → passes**
- [ ] **Step 5: Analyze + commit**

```bash
git commit -am "feat(post): render co-authored posts (stacked avatars, dual photo, both activities)"
```

---

## Task 11: Delete = remove own slot

**Files:**
- Modify: `lib/widgets/post_card_widget.dart` (post overflow menu), wherever the existing delete action lives.
- Test: extend `test/widgets/post_card_joint_test.dart`.

**Interfaces:**
- Consumes: `removeAuthorSlot` (Task 3).
- Produces: on a co-authored post the "Delete" action becomes **"Remove from my profile"** → `removeAuthorSlot(postId, uid)` (the card disappears from this user's profile/feed; the post stays for the other author; the CF deletes the doc once both are removed). Solo posts keep the existing full-delete.

- [ ] **Step 1: Write the failing test** — co-authored overflow shows "Remove from my profile" and calls `removeAuthorSlot`; solo shows "Delete".
- [ ] **Step 2: Run → fails**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run → passes**
- [ ] **Step 5: Commit**

```bash
git commit -am "feat(post): co-authored delete removes only the caller's slot"
```

---

## Task 12: Full regression + manual emulator pass

- [ ] **Step 1:** `flutter analyze lib test` → No issues.
- [ ] **Step 2:** `flutter test` → all pass (fix any drift in existing post/profile/feed tests caused by the `status`/`authorIds` additions).
- [ ] **Step 3 (manual, documented in PR):** Firebase emulator two-account run — pair session → both reach recap → each takes a photo (and one skips, verifying profile-pic fallback) → both tap Post → one joint post appears on **both** profiles; one author "Remove from my profile" → gone from theirs, present on the other; let a draft sit 24h (or force `expiresAt` in the past) → expiry notification offers a solo post.
- [ ] **Step 4: Commit** any test fixups.

---

## Task 13: Embed joint composer inside recap stats page

**Decision (resolved 2026-07-28):** Task 8 shipped `JointPostComposer` as a full-screen `Scaffold` that replaces recap's entire body for paired sessions, so partners never see the stats/breakdown screen. User chose **option (c)**: redesign the composer as a section that renders inside the existing stats page, rather than a separate full-screen replacement — stats and compose in one scroll, not two screens.

**Files:**
- Modify: `lib/features/session/presentation/recap_page.dart` (remove the full-screen joint branch added in Task 8; render stats body always, append composer content below it for paired sessions)
- Modify: `lib/features/session/presentation/widgets/joint_post_composer.dart` (de-`Scaffold`: expose the composer content as an embeddable widget/section rather than a route-level screen; preserve its existing `PopScope` back-navigation behavior by moving that guard up to `recap_page.dart`'s own scaffold)
- Test: extend `test/features/session/presentation/recap_joint_branch_test.dart` — joint session now shows BOTH the stats/breakdown content AND the composer section on one page; solo path unchanged.

**Interfaces:**
- Consumes: `JointPostComposer` (Task 9), `_isTwoHumanPairedSession` / `_ensureJointDraft()` (Task 8).
- Produces: paired-session recap = stats/breakdown (unchanged content) + joint composer section below it, one scrollable page. Solo recap unchanged.

- [ ] **Step 1: Write the failing test** — joint recap renders both stats content and composer section; solo recap unchanged; back-navigation still guarded.
- [ ] **Step 2: Run → fails**
- [ ] **Step 3: Implement** — extract composer's body from its `Scaffold` into a plain widget; recap_page renders stats + composer section for paired sessions.
- [ ] **Step 4: Run → passes**
- [ ] **Step 5: Analyze + commit**

```bash
git commit -am "feat(post): embed joint composer inside recap stats page instead of replacing it"
```

---

## Task 14: Solo-repost offer on an expired joint draft

**Gap found in Task 12's regression pass (resolved 2026-07-28):** the plan states three times (Architecture, Global Constraints, Task 12's manual checklist) that an expired joint draft "offers the confirmed author a solo repost," but no task 1-13 ever built the client-side half. `expireStaleJointPostDrafts` (Task 6) sets `status: 'expired'` and fires a `joint_post_expired` notification; tapping it deep-links to `/post/:postId` (Task 7) — but nothing there handles `status == 'expired'`, so the confirmed author currently lands on a broken/partial draft render with no way to act on it.

**Decision (resolved 2026-07-28):** user chose a simple dialog (Public / Private / Discard) over reusing the full recap share screen — minimal new UI, pre-filled with the confirmed author's own existing draft data.

**Files:**
- Modify: `lib/services/post_service.dart` — add `repostSoloFromExpiredDraft(String postId, String uid)`. Reads the draft's `authors[uid]` slot (caption, photoUrl — already-uploaded, do NOT re-run the photo-upload pipeline) plus the draft's `title`/`type`/`summary`, and writes a **new** plain solo post document with the same shape `createPost` produces (`authorId: uid`, `authorIds: [uid]`, `status: 'published'`, `coAuthored: false`, `visibility` per the user's dialog choice). The original expired draft document is left as-is (`status: 'expired'`) — it already doesn't appear in any query (author-scoped queries filter `status == 'published'`).
- Modify: `lib/features/feed/presentation/post_detail_page.dart` — when the loaded post has `status == 'expired'` and the current user is a non-removed, confirmed author in `authors`, show a dialog (Public / Private / Discard) instead of (or before) attempting the normal render. "Discard" just dismisses. Public/Private calls `repostSoloFromExpiredDraft` and then navigates to the new post (or back to feed). A user who is NOT a confirmed author of the expired draft (e.g. opened via a stale link, or never confirmed) sees a plain "This post is no longer available" state — no dialog.
- Test: `test/services/post_service_joint_test.dart` (extend) — `repostSoloFromExpiredDraft` writes a correctly-shaped solo post from an expired draft's slot data, does not touch the original draft doc, does not attempt a photo upload.
- Test: extend `test/widgets/post_card_joint_test.dart` or create `test/features/feed/post_detail_page_expired_test.dart` — confirmed author sees the repost dialog on an expired draft; each button does the right thing; a non-author sees no dialog.

- [ ] **Step 1: Write the failing tests** for both the service method and the page-level dialog behavior.
- [ ] **Step 2: Run → fails**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run → passes**
- [ ] **Step 5: Analyze + commit**

```bash
git commit -am "feat(post): offer solo repost when a joint draft expires"
```

---

## Self-Review

- **Spec coverage:** one post on both profiles (Tasks 1,3,10) ✓; "A with B" + stacked avatars (10) ✓; both activities (10) ✓; side-by-side photo slots (9) ✓; partner sees the other's photo before posting (9, live stream) ✓; posts only when both tap Post (6 CF + 4 rules) ✓; no photo → profile picture (9,10) ✓; co-session public/private choice, private-wins (2,6) ✓; solo unchanged (3,8) ✓; expire→solo offer (6,7) ✓; remove-own-slot (11) ✓.
- **Placeholder scan:** CF unit tests are genuinely absent in this repo, so Task 6 uses a documented emulator checklist rather than fake test code — this is a real constraint, not a placeholder. All Dart tasks carry runnable test code.
- **Type consistency:** `PostAuthorSlot`, `authors: Map<String, PostAuthorSlot>`, `status`, `authorIds`, and the service method names (`createJointDraft`, `setAuthorSlot`, `confirmJointPost`, `removeAuthorSlot`, `watchJointDraft`) are used identically across Tasks 1-11.

## Open risks / decisions already made

- **Matchmaking strangers can co-post** (user decision). Mitigation: the flow requires the stranger to actively take-photo-or-Post; ignoring it lets the draft expire. Revisit if abuse appears.
- **Publish is CF-gated** (not client), so a slow CF cold-start briefly leaves the post in `draft` after the second confirm — the composer shows "finishing…" until the stream flips to `published`.
- **Backfill:** existing solo posts have no `authorIds`/`status`; `Post.fromMap` defaults handle reads, but the author-scoped **queries** now filter `status == 'published'` and `arrayContains`. A one-time backfill script (write `authorIds:[authorId]`, `status:'published'` onto all existing posts) is required before the query change ships, or old posts vanish from profiles. Add this as a pre-deploy migration step in the PR.
