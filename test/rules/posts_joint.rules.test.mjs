// Behavioral (emulator-backed) tests for the co-authored `posts/{postId}`
// rules in firebase/firestore.rules.
//
// The Dart test at test/firebase/firestore_rules_contract_test.dart only
// asserts that certain source strings are PRESENT in the rules file — it can
// never catch a predicate that is syntactically there but logically vacuous
// (exactly the class of bug that let a co-author flip a published joint post
// from private to public). These tests actually execute the rules against the
// Firestore emulator.
//
// Run with:
//   cd test/rules && npm install && npm test
// (npm test wraps `firebase emulators:exec --only firestore`, so the Firestore
// emulator is started/stopped automatically. Requires Java on PATH.)

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..', '..');

const ALICE = 'alice';
const BOB = 'bob';
const MALLORY = 'mallory';
const SESSION_ID = 'session-1';
const DRAFT_ID = `joint_${SESSION_ID}`;
const PUBLISHED_ID = 'joint-published';
const SOLO_ID = 'solo-1';

let testEnv;

/** A minimal author slot, matching PostAuthorSlot.toMap(). */
function slot(uid, overrides = {}) {
  return {
    userId: uid,
    caption: null,
    photoUrl: null,
    confirmed: false,
    removed: false,
    visibility: 'public',
    summary: {},
    ...overrides,
  };
}

function jointPost(overrides = {}) {
  return {
    coAuthored: true,
    status: 'draft',
    authorIds: [ALICE, BOB],
    authorId: ALICE,
    sessionId: SESSION_ID,
    type: 'strength',
    title: 'Push day',
    visibility: 'public',
    summary: {},
    authors: { [ALICE]: slot(ALICE), [BOB]: slot(BOB) },
    mediaURLs: [],
    likesCount: 0,
    commentsCount: 0,
    ...overrides,
  };
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-zyntro',
    firestore: {
      rules: readFileSync(
        resolve(REPO_ROOT, 'firebase', 'firestore.rules'),
        'utf8',
      ),
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // A real paired session that alice and bob both trained.
    await setDoc(doc(db, 'sessions', SESSION_ID), {
      hostId: ALICE,
      participants: [ALICE, BOB],
      status: 'completed',
      phase: 'recap',
      type: 'strength',
    });
    // A session mallory hosted alone — she is its only participant.
    await setDoc(doc(db, 'sessions', 'session-mallory'), {
      hostId: MALLORY,
      participants: [MALLORY],
      status: 'completed',
      phase: 'recap',
      type: 'strength',
    });
    // A published joint post owned by alice + bob (as the CF would leave it).
    await setDoc(
      doc(db, 'posts', PUBLISHED_ID),
      jointPost({
        status: 'published',
        visibility: 'private',
        authors: {
          [ALICE]: slot(ALICE, { confirmed: true, visibility: 'private' }),
          [BOB]: slot(BOB, { confirmed: true, visibility: 'public' }),
        },
      }),
    );
    // A plain solo post owned by alice.
    await setDoc(doc(db, 'posts', SOLO_ID), {
      authorId: ALICE,
      authorIds: [ALICE],
      status: 'published',
      coAuthored: false,
      sessionId: SESSION_ID,
      visibility: 'public',
      title: 'Leg day',
      type: 'strength',
      summary: {},
      mediaURLs: [],
      likesCount: 0,
      commentsCount: 0,
    });
  });
});

function db(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

describe('joint draft create — session membership (fix I2)', () => {
  it('DENIES a non-participant creating a joint draft naming two OTHER users', async () => {
    // Mallory never shared a session with alice or bob. Before the
    // sessionHasAllParticipants check she could plant a co-authored draft
    // naming both of them.
    await assertFails(
      setDoc(
        doc(db(MALLORY), 'posts', 'mallory-planted'),
        jointPost({ authorIds: [ALICE, BOB] }),
      ),
    );
  });

  it('DENIES an author dragging a non-participant into their own session draft', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), 'posts', 'alice-drags-mallory'),
        jointPost({
          authorIds: [ALICE, MALLORY],
          authors: { [ALICE]: slot(ALICE), [MALLORY]: slot(MALLORY) },
        }),
      ),
    );
  });

  it('DENIES a joint draft pointing at a session that does not exist', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), 'posts', 'no-such-session'),
        jointPost({ sessionId: 'session-does-not-exist' }),
      ),
    );
  });

  it('ALLOWS an actual participant creating the joint draft for their session', async () => {
    await assertSucceeds(
      setDoc(doc(db(ALICE), 'posts', DRAFT_ID), jointPost()),
    );
  });

  it('ALLOWS the other participant creating the same draft', async () => {
    await assertSucceeds(
      setDoc(doc(db(BOB), 'posts', DRAFT_ID), jointPost()),
    );
  });
});

describe('joint post update — full top-level diff is constrained (fix I1)', () => {
  it('DENIES a co-author flipping visibility alone on a published joint post', async () => {
    // The "private wins" Global Constraint: alice picked private, so the
    // published post is private. Bob must not be able to make it public.
    await assertFails(
      updateDoc(doc(db(BOB), 'posts', PUBLISHED_ID), {
        visibility: 'public',
      }),
    );

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), 'posts', PUBLISHED_ID));
      assert.equal(snap.data().visibility, 'private');
    });
  });

  it('DENIES a co-author rewriting title / summary / mediaURLs', async () => {
    await assertFails(
      updateDoc(doc(db(BOB), 'posts', PUBLISHED_ID), { title: 'hijacked' }),
    );
    await assertFails(
      updateDoc(doc(db(BOB), 'posts', PUBLISHED_ID), {
        summary: { totalSets: 999 },
      }),
    );
    await assertFails(
      updateDoc(doc(db(BOB), 'posts', PUBLISHED_ID), {
        mediaURLs: ['https://evil.example/x.jpg'],
      }),
    );
  });

  it('DENIES smuggling visibility alongside a legitimate own-slot edit', async () => {
    await assertFails(
      updateDoc(doc(db(BOB), 'posts', PUBLISHED_ID), {
        [`authors.${BOB}.caption`]: 'nice one',
        visibility: 'public',
      }),
    );
  });

  it('DENIES a client publishing a draft itself (status stays server-only)', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'posts', DRAFT_ID), jointPost());
    });
    await assertFails(
      updateDoc(doc(db(ALICE), 'posts', DRAFT_ID), { status: 'published' }),
    );
  });

  it('DENIES a non-author touching a joint post at all', async () => {
    await assertFails(
      updateDoc(doc(db(MALLORY), 'posts', PUBLISHED_ID), {
        [`authors.${MALLORY}.caption`]: 'hi',
      }),
    );
    await assertFails(
      updateDoc(doc(db(MALLORY), 'posts', PUBLISHED_ID), {
        visibility: 'public',
      }),
    );
  });
});

describe('joint post update — legitimate paths still work (no regression)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'posts', DRAFT_ID), jointPost());
    });
  });

  it('ALLOWS an author editing their own slot (caption/photo/visibility)', async () => {
    await assertSucceeds(
      updateDoc(doc(db(ALICE), 'posts', DRAFT_ID), {
        [`authors.${ALICE}.caption`]: 'PR!',
        [`authors.${ALICE}.photoUrl`]: 'https://example.com/a.jpg',
        [`authors.${ALICE}.visibility`]: 'private',
      }),
    );
  });

  it('ALLOWS an author confirming their own slot', async () => {
    await assertSucceeds(
      updateDoc(doc(db(BOB), 'posts', DRAFT_ID), {
        [`authors.${BOB}.confirmed`]: true,
      }),
    );
  });

  it('ALLOWS an author soft-removing their own slot', async () => {
    await assertSucceeds(
      updateDoc(doc(db(BOB), 'posts', PUBLISHED_ID), {
        [`authors.${BOB}.removed`]: true,
      }),
    );
  });

  it('DENIES an author writing the OTHER author slot', async () => {
    await assertFails(
      updateDoc(doc(db(ALICE), 'posts', DRAFT_ID), {
        [`authors.${BOB}.confirmed`]: true,
      }),
    );
  });

  it('ALLOWS an author bumping engagement counters (parity with solo owner)', async () => {
    await assertSucceeds(
      updateDoc(doc(db(BOB), 'posts', PUBLISHED_ID), { likesCount: 1 }),
    );
  });

  // Since Z-SEC-006 any signed-in user may nudge a counter by exactly ±1 (a
  // like is a +1 from the liker), but nobody may set an arbitrary tally.
  it('ALLOWS a non-author nudging engagement counters by one', async () => {
    await assertSucceeds(
      updateDoc(doc(db(MALLORY), 'posts', PUBLISHED_ID), { likesCount: 1 }),
    );
  });

  it('DENIES a non-author setting an arbitrary engagement tally', async () => {
    await assertFails(
      updateDoc(doc(db(MALLORY), 'posts', PUBLISHED_ID), { likesCount: 50 }),
    );
  });
});

describe('solo posts — unchanged behavior', () => {
  it('ALLOWS a solo create by the author', async () => {
    await assertSucceeds(
      setDoc(doc(db(ALICE), 'posts', 'solo-new'), {
        authorId: ALICE,
        authorIds: [ALICE],
        status: 'published',
        coAuthored: false,
        sessionId: SESSION_ID,
        visibility: 'public',
        title: 'Leg day',
        type: 'strength',
        summary: {},
        mediaURLs: [],
        likesCount: 0,
        commentsCount: 0,
      }),
    );
  });

  it('ALLOWS the solo owner to update their own post', async () => {
    await assertSucceeds(
      updateDoc(doc(db(ALICE), 'posts', SOLO_ID), { visibility: 'private' }),
    );
  });

  it('DENIES a solo create that plants someone else as a second author', async () => {
    await assertFails(
      setDoc(doc(db(MALLORY), 'posts', 'solo-planted'), {
        authorId: MALLORY,
        authorIds: [MALLORY, ALICE],
        status: 'published',
        coAuthored: false,
        sessionId: SESSION_ID,
        visibility: 'public',
        title: 'Leg day',
        type: 'strength',
        summary: {},
        likesCount: 0,
        commentsCount: 0,
      }),
    );
  });

  it('DENIES a non-owner updating a solo post', async () => {
    await assertFails(
      updateDoc(doc(db(MALLORY), 'posts', SOLO_ID), { title: 'hijacked' }),
    );
  });
});
