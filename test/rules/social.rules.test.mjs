// Behavioral (emulator-backed) tests for the user, follow, block, report and
// buddy-pair rules in firebase/firestore.rules.
//
// These collections carried 537 lines of rules with no behavioral coverage —
// only test/firebase/firestore_rules_contract_test.dart, which asserts that
// certain source strings are PRESENT in the rules file. A string-contract test
// cannot catch a predicate that is syntactically there but logically vacuous,
// and it passes just as happily if a rule is rewritten to grant strictly more
// access. These tests actually execute the rules against the emulator.
//
// Run with:
//   cd test/rules && npm install && npm test
// (npm test wraps `firebase emulators:exec --only firestore`, so the emulator
// is started/stopped automatically. Requires Java on PATH.)

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, getDocs, collection, query, where, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..', '..');

const ALICE = 'alice';
const BOB = 'bob';
const MALLORY = 'mallory';
const MOD = 'moderator';

let testEnv;

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
    for (const uid of [ALICE, BOB, MALLORY]) {
      await setDoc(doc(db, 'users', uid), {
        displayName: uid,
        isPrivate: false,
        workoutScore: 0,
        totalWorkouts: 0,
        isModerator: false,
        isBanned: false,
      });
    }
    // isModerator() reads this document, so it must be seeded out-of-band.
    await setDoc(doc(db, 'users', MOD), {
      displayName: 'mod',
      isPrivate: false,
      isModerator: true,
    });
  });
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

describe('users/{userId}', () => {
  it('lets an owner update their own ordinary profile fields', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'users', ALICE), { displayName: 'Alice A' }),
    );
  });

  it('stops an owner inflating workoutScore or streak counters', async () => {
    // Z-DATA-001: integrity fields are Admin/CF only.
    await assertFails(
      updateDoc(doc(as(ALICE), 'users', ALICE), {
        workoutScore: 120,
        totalWorkouts: 4,
        buddyWorkouts: 2,
        currentStreak: 3,
        longestStreak: 9,
        lastWorkoutDate: '2026-08-03',
        weeklyWorkouts: 2,
        weekStartDate: '2026-08-03',
      }),
    );
  });

  it('stops an owner writing a single integrity field', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'users', ALICE), { workoutScore: 99999 }),
    );
    await assertFails(
      updateDoc(doc(as(ALICE), 'users', ALICE), { currentStreak: 99 }),
    );
  });

  it('stops a user granting themselves moderator', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'users', ALICE), { isModerator: true }),
    );
  });

  it('stops a user creating their profile as moderator (Z-SEC-008)', async () => {
    const newbie = 'user_newbie';
    await assertFails(
      setDoc(doc(as(newbie), 'users', newbie), {
        displayName: 'Newbie',
        isPrivate: false,
        isModerator: true,
      }),
    );
  });

  it('stops a user clearing their own ban', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'users', ALICE),
        { isBanned: true, banReason: 'spam' },
        { merge: true },
      );
    });

    await assertFails(
      updateDoc(doc(as(ALICE), 'users', ALICE), {
        isBanned: false,
        banReason: null,
      }),
    );
  });

  it('stops a user granting themselves global leaderboard access', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'users', ALICE), {
        hasGlobalLeaderboardAccess: true,
      }),
    );
  });

  it('stops a user editing somebody else', async () => {
    await assertFails(
      updateDoc(doc(as(MALLORY), 'users', ALICE), { displayName: 'pwned' }),
    );
  });

  it('stops anyone deleting a user', async () => {
    await assertFails(deleteDoc(doc(as(ALICE), 'users', ALICE)));
  });

  it('stops an unauthenticated client reading users', async () => {
    await assertFails(getDoc(doc(anon(), 'users', ALICE)));
  });

  it('lets a stranger read a public profile', async () => {
    await assertSucceeds(getDoc(doc(as(MALLORY), 'users', ALICE)));
  });

  it('stops a stranger reading a private profile', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', ALICE), { isPrivate: true }, { merge: true });
    });
    await assertFails(getDoc(doc(as(MALLORY), 'users', ALICE)));
  });

  it('lets an approved follower read a private profile', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', ALICE), { isPrivate: true }, { merge: true });
      await setDoc(doc(db, 'follows', `${MALLORY}_${ALICE}`), {
        followerId: MALLORY,
        followeeId: ALICE,
        status: 'approved',
      });
    });
    await assertSucceeds(getDoc(doc(as(MALLORY), 'users', ALICE)));
  });

  it('lets the owner read their private profile', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', ALICE), { isPrivate: true }, { merge: true });
    });
    await assertSucceeds(getDoc(doc(as(ALICE), 'users', ALICE)));
  });

  it('lets a moderator update another user', async () => {
    await assertSucceeds(
      updateDoc(doc(as(MOD), 'users', ALICE), { isBanned: true }),
    );
  });

  // Z-SEC-001 — list must not bypass private get ACL.
  // Queries that *could* return a private doc for a stranger fail entirely
  // (rules are not filters). Constrained public queries succeed without them.
  it('denies a stranger collection list that could include a private profile', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'users', ALICE), {
        isPrivate: true,
        usernameLower: 'alice',
      }),
    );

    // Emulator may filter unauthorized docs rather than fail the query.
    // Either outcome is acceptable if private Alice is not returned.
    let ids = [];
    try {
      const snap = await getDocs(collection(as(MALLORY), 'users'));
      ids = snap.docs.map((d) => d.id);
    } catch {
      return; // hard deny — also fine
    }
    if (ids.includes(ALICE)) {
      throw new Error(`private Alice leaked via list: ${ids.join(',')}`);
    }
  });

  it('denies a username prefix query that could return a private profile', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'users', ALICE), {
        isPrivate: true,
        usernameLower: 'alice',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as(BOB), 'users', BOB), {
        isPrivate: false,
        usernameLower: 'bob',
      }),
    );

    const privatePrefix = query(
      collection(as(MALLORY), 'users'),
      where('usernameLower', '>=', 'ali'),
      where('usernameLower', '<=', 'ali\uf8ff'),
    );
    let ids = [];
    try {
      const snap = await getDocs(privatePrefix);
      ids = snap.docs.map((d) => d.id);
    } catch {
      return;
    }
    if (ids.includes(ALICE)) {
      throw new Error(`private Alice leaked via prefix query: ${ids.join(',')}`);
    }
  });

  it('lets a stranger search public profiles with isPrivate == false', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'users', ALICE), {
        isPrivate: true,
        usernameLower: 'alice',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as(BOB), 'users', BOB), {
        isPrivate: false,
        usernameLower: 'bobby',
      }),
    );

    const publicSearch = query(
      collection(as(MALLORY), 'users'),
      where('isPrivate', '==', false),
      where('usernameLower', '>=', 'bob'),
      where('usernameLower', '<=', 'bob\uf8ff'),
    );
    const snap = await assertSucceeds(getDocs(publicSearch));
    const ids = snap.docs.map((d) => d.id);
    if (!ids.includes(BOB)) {
      throw new Error(`expected public Bob in results, got ${ids.join(',')}`);
    }
    if (ids.includes(ALICE)) {
      throw new Error('private Alice must not appear in public search');
    }
  });

  it('lets a moderator get a private profile', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', ALICE), { isPrivate: true }, { merge: true });
    });
    await assertSucceeds(getDoc(doc(as(MOD), 'users', ALICE)));
  });
});

describe('follows/{followId}', () => {
  const edge = (from, to) => `${from}_${to}`;

  async function seedFollow(from, to, status) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'follows', edge(from, to)), {
        followerId: from,
        followeeId: to,
        status,
      });
    });
  }

  it('lets a user create their own follow edge', async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), 'follows', edge(ALICE, BOB)), {
        followerId: ALICE,
        followeeId: BOB,
        status: 'pending',
      }),
    );
  });

  it('stops an unverified password user creating a follow edge (Z-AUTH-002)', async () => {
    const unverified = (uid) =>
      testEnv.authenticatedContext(uid, {
        email_verified: false,
        firebase: { sign_in_provider: 'password' },
      }).firestore();

    await assertFails(
      setDoc(doc(unverified(ALICE), 'follows', edge(ALICE, BOB)), {
        followerId: ALICE,
        followeeId: BOB,
        status: 'pending',
      }),
    );
  });

  it('lets a verified password user create a follow edge (Z-AUTH-002)', async () => {
    const verified = (uid) =>
      testEnv.authenticatedContext(uid, {
        email_verified: true,
        firebase: { sign_in_provider: 'password' },
      }).firestore();

    await assertSucceeds(
      setDoc(doc(verified(ALICE), 'follows', edge(ALICE, BOB)), {
        followerId: ALICE,
        followeeId: BOB,
        status: 'pending',
      }),
    );
  });

  it('lets a federated user create a follow without email_verified claim (Z-AUTH-002)', async () => {
    const google = (uid) =>
      testEnv.authenticatedContext(uid, {
        email_verified: false,
        firebase: { sign_in_provider: 'google.com' },
      }).firestore();

    await assertSucceeds(
      setDoc(doc(google(ALICE), 'follows', edge(ALICE, BOB)), {
        followerId: ALICE,
        followeeId: BOB,
        status: 'pending',
      }),
    );
  });

  it('lets a follower create an approved edge only when the followee is public', async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), 'follows', edge(ALICE, BOB)), {
        followerId: ALICE,
        followeeId: BOB,
        status: 'approved',
      }),
    );
  });

  it('stops a follower creating an already-approved edge against a private account', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', BOB), { isPrivate: true }, { merge: true });
    });
    await assertFails(
      setDoc(doc(as(ALICE), 'follows', edge(ALICE, BOB)), {
        followerId: ALICE,
        followeeId: BOB,
        status: 'approved',
      }),
    );
  });

  it('stops a user forging a follow on somebody else\'s behalf', async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), 'follows', edge(ALICE, BOB)), {
        followerId: ALICE,
        followeeId: BOB,
        status: 'pending',
      }),
    );
  });

  it('lets the followee approve a pending request', async () => {
    await seedFollow(ALICE, BOB, 'pending');

    await assertSucceeds(
      updateDoc(doc(as(BOB), 'follows', edge(ALICE, BOB)), {
        status: 'approved',
      }),
    );
  });

  it('stops the follower approving their own request', async () => {
    // The core property of this collection: following a private account must
    // require that account's consent, so the requester cannot self-approve.
    await seedFollow(ALICE, BOB, 'pending');

    await assertFails(
      updateDoc(doc(as(ALICE), 'follows', edge(ALICE, BOB)), {
        status: 'approved',
      }),
    );
  });

  it('stops an unrelated user approving somebody else\'s request', async () => {
    await seedFollow(ALICE, BOB, 'pending');

    await assertFails(
      updateDoc(doc(as(MALLORY), 'follows', edge(ALICE, BOB)), {
        status: 'approved',
      }),
    );
  });

  it('lets the follower unfollow', async () => {
    await seedFollow(ALICE, BOB, 'approved');
    await assertSucceeds(deleteDoc(doc(as(ALICE), 'follows', edge(ALICE, BOB))));
  });

  it('lets the followee remove a follower', async () => {
    await seedFollow(ALICE, BOB, 'approved');
    await assertSucceeds(deleteDoc(doc(as(BOB), 'follows', edge(ALICE, BOB))));
  });

  it('stops a third party deleting a follow edge', async () => {
    await seedFollow(ALICE, BOB, 'approved');
    await assertFails(
      deleteDoc(doc(as(MALLORY), 'follows', edge(ALICE, BOB))),
    );
  });

  it('lets the followee list their own pending requests', async () => {
    await seedFollow(ALICE, BOB, 'pending');
    await assertSucceeds(getDoc(doc(as(BOB), 'follows', edge(ALICE, BOB))));
    await assertSucceeds(
      getDocs(
        query(
          collection(as(BOB), 'follows'),
          where('followeeId', '==', BOB),
          where('status', '==', 'pending'),
        ),
      ),
    );
  });

  it('hides pending follow requests from strangers', async () => {
    await seedFollow(ALICE, BOB, 'pending');
    await assertFails(getDoc(doc(as(MALLORY), 'follows', edge(ALICE, BOB))));
    await assertFails(
      getDocs(
        query(
          collection(as(MALLORY), 'follows'),
          where('followeeId', '==', BOB),
          where('status', '==', 'pending'),
        ),
      ),
    );
  });

  it('lets a stranger list approved follow edges', async () => {
    await seedFollow(ALICE, BOB, 'approved');
    await assertSucceeds(getDoc(doc(as(MALLORY), 'follows', edge(ALICE, BOB))));
    await assertSucceeds(
      getDocs(
        query(
          collection(as(MALLORY), 'follows'),
          where('status', '==', 'approved'),
        ),
      ),
    );
  });
});

describe('blocks/{blockId}', () => {
  const blockId = (blocker, blocked) => `${blocker}_${blocked}`;

  async function seedBlock(blocker, blocked) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'blocks', blockId(blocker, blocked)), {
        blockerId: blocker,
        blockedUserId: blocked,
      });
    });
  }

  it('lets a user block somebody', async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), 'blocks', blockId(ALICE, MALLORY)), {
        blockerId: ALICE,
        blockedUserId: MALLORY,
      }),
    );
  });

  it('stops a user forging a block attributed to somebody else', async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), 'blocks', blockId(ALICE, BOB)), {
        blockerId: ALICE,
        blockedUserId: BOB,
      }),
    );
  });

  it('lets the blocker read their own block', async () => {
    await seedBlock(ALICE, MALLORY);
    await assertSucceeds(
      getDoc(doc(as(ALICE), 'blocks', blockId(ALICE, MALLORY))),
    );
  });

  it('stops the blocked user discovering they are blocked', async () => {
    await seedBlock(ALICE, MALLORY);
    await assertFails(
      getDoc(doc(as(MALLORY), 'blocks', blockId(ALICE, MALLORY))),
    );
  });

  it('stops anyone editing a block in place', async () => {
    await seedBlock(ALICE, MALLORY);
    await assertFails(
      updateDoc(doc(as(ALICE), 'blocks', blockId(ALICE, MALLORY)), {
        blockedUserId: BOB,
      }),
    );
  });

  it('lets the blocker unblock', async () => {
    await seedBlock(ALICE, MALLORY);
    await assertSucceeds(
      deleteDoc(doc(as(ALICE), 'blocks', blockId(ALICE, MALLORY))),
    );
  });

  it('stops the blocked user removing the block on themselves', async () => {
    await seedBlock(ALICE, MALLORY);
    await assertFails(
      deleteDoc(doc(as(MALLORY), 'blocks', blockId(ALICE, MALLORY))),
    );
  });
});

describe('reports/{reportId}', () => {
  async function seedReport(reporter) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'reports', 'report-1'), {
        reporterId: reporter,
        targetId: MALLORY,
        status: 'pending',
      });
    });
  }

  // A report must match the schema isReportCreate() enforces (the shape
  // ModerationService writes): reporterId, reportedUserId, reason, status,
  // createdAt = request.time.
  it('lets a user file their own report', async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), 'reports', 'report-1'), {
        reporterId: ALICE,
        reportedUserId: MALLORY,
        reason: 'spam',
        status: 'pending',
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('stops a user filing a report under somebody else\'s name', async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), 'reports', 'report-1'), {
        reporterId: ALICE,
        reportedUserId: BOB,
        reason: 'spam',
        status: 'pending',
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('lets the reporter read their own report', async () => {
    await seedReport(ALICE);
    await assertSucceeds(getDoc(doc(as(ALICE), 'reports', 'report-1')));
  });

  it('stops the reported user reading the report against them', async () => {
    await seedReport(ALICE);
    await assertFails(getDoc(doc(as(MALLORY), 'reports', 'report-1')));
  });

  it('lets a moderator read any report', async () => {
    await seedReport(ALICE);
    await assertSucceeds(getDoc(doc(as(MOD), 'reports', 'report-1')));
  });

  it('stops the reporter resolving their own report', async () => {
    await seedReport(ALICE);
    await assertFails(
      updateDoc(doc(as(ALICE), 'reports', 'report-1'), { status: 'resolved' }),
    );
  });

  it('lets a moderator resolve a report', async () => {
    await seedReport(ALICE);
    await assertSucceeds(
      updateDoc(doc(as(MOD), 'reports', 'report-1'), { status: 'resolved' }),
    );
  });

  it('stops anyone deleting a report, moderators included', async () => {
    await seedReport(ALICE);
    await assertFails(deleteDoc(doc(as(ALICE), 'reports', 'report-1')));
    await assertFails(deleteDoc(doc(as(MOD), 'reports', 'report-1')));
  });
});

describe('buddyPairs/{pairId}', () => {
  async function seedPair(participants, initiator) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'buddyPairs', 'pair-1'), {
        initiatorId: initiator,
        participants,
      });
    });
  }

  it('lets a user open a pair with themselves as the only member', async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), 'buddyPairs', 'pair-1'), {
        initiatorId: ALICE,
        participants: [ALICE],
      }),
    );
  });

  it('stops a user creating a pair naming somebody else as initiator', async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), 'buddyPairs', 'pair-1'), {
        initiatorId: ALICE,
        participants: [ALICE],
      }),
    );
  });

  it('stops a user pre-loading a pair with another member', async () => {
    // Joining is the invitee's decision; a creator cannot enrol them up front.
    await assertFails(
      setDoc(doc(as(ALICE), 'buddyPairs', 'pair-1'), {
        initiatorId: ALICE,
        participants: [ALICE, BOB],
      }),
    );
  });

  it('lets a participant read their pair', async () => {
    await seedPair([ALICE, BOB], ALICE);
    await assertSucceeds(getDoc(doc(as(BOB), 'buddyPairs', 'pair-1')));
  });

  it('stops a non-participant reading the pair', async () => {
    await seedPair([ALICE, BOB], ALICE);
    await assertFails(getDoc(doc(as(MALLORY), 'buddyPairs', 'pair-1')));
  });

  it('stops a non-participant editing the pair', async () => {
    await seedPair([ALICE, BOB], ALICE);
    await assertFails(
      updateDoc(doc(as(MALLORY), 'buddyPairs', 'pair-1'), {
        participants: [ALICE, BOB, MALLORY],
      }),
    );
  });

  it('stops anyone deleting a pair', async () => {
    await seedPair([ALICE, BOB], ALICE);
    await assertFails(deleteDoc(doc(as(ALICE), 'buddyPairs', 'pair-1')));
  });
});

describe('users/{userId} private subcollections', () => {
  it('lets an owner create a notification addressed to themselves', async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), 'users', ALICE, 'notifications', 'n1'), {
        userId: ALICE,
        type: 'follow',
        read: false,
      }),
    );
  });

  it('stops a notification whose userId does not match its inbox', async () => {
    // The rule requires request.resource.data.userId == userId, so a payload
    // cannot claim to belong to a different user than the path it is written
    // to — the two must agree.
    await assertFails(
      setDoc(doc(as(ALICE), 'users', ALICE, 'notifications', 'n1'), {
        userId: BOB,
        type: 'follow',
        read: false,
      }),
    );
  });

  it('stops a user writing notifications into somebody else\'s inbox', async () => {
    // Cross-user notifications are written by the Cloud Function with admin
    // privileges; a client forging them would let anyone spam any inbox.
    await assertFails(
      setDoc(doc(as(MALLORY), 'users', ALICE, 'notifications', 'n1'), {
        userId: ALICE,
        type: 'follow',
        read: false,
      }),
    );
  });

  it('stops a user reading somebody else\'s notifications', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', ALICE, 'notifications', 'n1'), {
        type: 'follow',
        read: false,
      });
    });

    await assertFails(
      getDoc(doc(as(MALLORY), 'users', ALICE, 'notifications', 'n1')),
    );
  });

  it('stops a user reading somebody else\'s settings and devices', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', ALICE, 'settings', 's1'), { theme: 'dark' });
      await setDoc(doc(db, 'users', ALICE, 'devices', 'd1'), { token: 'tok' });
    });

    await assertFails(getDoc(doc(as(MALLORY), 'users', ALICE, 'settings', 's1')));
    await assertFails(getDoc(doc(as(MALLORY), 'users', ALICE, 'devices', 'd1')));
  });

  it('stops an owner writing their own stats (server-owned)', async () => {
    await assertFails(
      setDoc(doc(as(ALICE), 'users', ALICE, 'stats', 'prs'), {
        strength: { bench: { bestEstimate: 100 } },
      }),
    );
  });

  it('stops a user writing somebody else\'s stats', async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), 'users', ALICE, 'stats', 'prs'), {
        strength: { bench: { bestEstimate: 1 } },
      }),
    );
  });

});

describe('users/{userId}/stats — personal record visibility', () => {
  async function seedStats(uid) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', uid, 'stats', 'prs'), {
        strength: { bench: { bestEstimate: 100 } },
      });
    });
  }

  async function setPrivate(uid, isPrivate) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'users', uid),
        { isPrivate },
        { merge: true },
      );
    });
  }

  async function seedApprovedFollow(follower, followee) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'follows', `${follower}_${followee}`), {
        followerId: follower,
        followeeId: followee,
        status: 'approved',
      });
    });
  }

  it('lets anyone signed in read a public account\'s records', async () => {
    await setPrivate(ALICE, false);
    await seedStats(ALICE);

    await assertSucceeds(
      getDoc(doc(as(MALLORY), 'users', ALICE, 'stats', 'prs')),
    );
  });

  it('hides a private account\'s records from a stranger', async () => {
    await setPrivate(ALICE, true);
    await seedStats(ALICE);

    await assertFails(getDoc(doc(as(MALLORY), 'users', ALICE, 'stats', 'prs')));
  });

  it('still shows a private account\'s records to its owner', async () => {
    await setPrivate(ALICE, true);
    await seedStats(ALICE);

    await assertSucceeds(getDoc(doc(as(ALICE), 'users', ALICE, 'stats', 'prs')));
  });

  it('shows a private account\'s records to an approved follower', async () => {
    // Going private must not cut off the followers the owner already approved.
    await setPrivate(ALICE, true);
    await seedStats(ALICE);
    await seedApprovedFollow(BOB, ALICE);

    await assertSucceeds(getDoc(doc(as(BOB), 'users', ALICE, 'stats', 'prs')));
  });

  it('hides a private account\'s records from a pending follower', async () => {
    await setPrivate(ALICE, true);
    await seedStats(ALICE);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'follows', `${BOB}_${ALICE}`), {
        followerId: BOB,
        followeeId: ALICE,
        status: 'pending',
      });
    });

    await assertFails(getDoc(doc(as(BOB), 'users', ALICE, 'stats', 'prs')));
  });

  it('does not treat being followed BY someone as permission to read them', async () => {
    // alice follows mallory; that says nothing about mallory's right to read
    // alice. The follow edge direction must not be usable backwards.
    await setPrivate(ALICE, true);
    await seedStats(ALICE);
    await seedApprovedFollow(ALICE, MALLORY);

    await assertFails(getDoc(doc(as(MALLORY), 'users', ALICE, 'stats', 'prs')));
  });

  it('fails closed when the owner document does not exist', async () => {
    await seedStats('ghost');

    await assertFails(getDoc(doc(as(MALLORY), 'users', 'ghost', 'stats', 'prs')));
  });

  it('stops an unauthenticated client reading any records', async () => {
    await setPrivate(ALICE, false);
    await seedStats(ALICE);

    await assertFails(getDoc(doc(anon(), 'users', ALICE, 'stats', 'prs')));
  });
});

describe('posts/{postId} visibility', () => {
  async function seedPost(id, overrides = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'posts', id), {
        authorId: ALICE,
        visibility: 'public',
        coAuthored: false,
        ...overrides,
      });
    });
  }

  it('lets a stranger read a public post on a public account', async () => {
    await seedPost('pub-1');
    await assertSucceeds(getDoc(doc(as(MALLORY), 'posts', 'pub-1')));
  });

  it('stops a stranger reading a private post', async () => {
    await seedPost('priv-1', { visibility: 'private' });
    await assertFails(getDoc(doc(as(MALLORY), 'posts', 'priv-1')));
  });

  it('lets the author read their private post', async () => {
    await seedPost('priv-2', { visibility: 'private' });
    await assertSucceeds(getDoc(doc(as(ALICE), 'posts', 'priv-2')));
  });

  it('stops a blocked user reading a public post', async () => {
    await seedPost('pub-block');
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'blocks', `${ALICE}_${MALLORY}`), {
        blockerId: ALICE,
        blockedId: MALLORY,
      });
    });
    await assertFails(getDoc(doc(as(MALLORY), 'posts', 'pub-block')));
  });
});

describe('matchmaking_queue/{entryId}', () => {
  it('lets a user create their own waiting entry', async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), 'matchmaking_queue', 'q1'), {
        userId: ALICE,
        workoutType: 'gym',
        status: 'waiting',
      }),
    );
  });

  it('stops a user creating a queue entry for someone else', async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), 'matchmaking_queue', 'q2'), {
        userId: ALICE,
        workoutType: 'gym',
        status: 'waiting',
      }),
    );
  });
});

describe('workouts/{workoutId}', () => {
  async function seedWorkout(id, data) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'workouts', id), data);
    });
  }

  it('lets a user list their own workouts', async () => {
    await seedWorkout('w-own', { userId: ALICE, participants: [ALICE] });
    await assertSucceeds(
      getDocs(
        query(collection(as(ALICE), 'workouts'), where('userId', '==', ALICE)),
      ),
    );
  });

  it('lets a stranger list a public account\'s workouts', async () => {
    await seedWorkout('w-pub', { userId: BOB, participants: [BOB] });
    await assertSucceeds(getDoc(doc(as(MALLORY), 'workouts', 'w-pub')));
    await assertSucceeds(
      getDocs(
        query(collection(as(MALLORY), 'workouts'), where('userId', '==', BOB)),
      ),
    );
  });

  it('hides a private account\'s workouts from a stranger', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', ALICE), { isPrivate: true }, { merge: true });
      await setDoc(doc(ctx.firestore(), 'workouts', 'w-priv'), {
        userId: ALICE,
        participants: [ALICE],
      });
    });
    await assertFails(getDoc(doc(as(MALLORY), 'workouts', 'w-priv')));
    await assertFails(
      getDocs(
        query(collection(as(MALLORY), 'workouts'), where('userId', '==', ALICE)),
      ),
    );
  });

  it('lets an approved follower read a private account\'s workouts', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', ALICE), { isPrivate: true }, { merge: true });
      await setDoc(doc(ctx.firestore(), 'follows', `${BOB}_${ALICE}`), {
        followerId: BOB,
        followeeId: ALICE,
        status: 'approved',
      });
      await setDoc(doc(ctx.firestore(), 'workouts', 'w-follow'), {
        userId: ALICE,
        participants: [ALICE],
      });
    });
    await assertSucceeds(getDoc(doc(as(BOB), 'workouts', 'w-follow')));
    await assertSucceeds(
      getDocs(
        query(collection(as(BOB), 'workouts'), where('userId', '==', ALICE)),
      ),
    );
  });
});

describe('usernames/{username}', () => {
  it('lets a signed-in user look up a handle by id', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'usernames', 'alice'), {
        uid: ALICE,
        createdAt: new Date(),
      });
    });
    await assertSucceeds(getDoc(doc(as(ALICE), 'usernames', 'alice')));
  });

  it('stops listing the username registry', async () => {
    await assertFails(getDocs(collection(as(MALLORY), 'usernames')));
  });
});
