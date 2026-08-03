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
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

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

  it('lets an owner write their own maintained workout counters', async () => {
    // These are the streak/score counters session end writes. They are
    // deliberately NOT privileged — the client-trust model for scoring is
    // pre-existing and documented in the leaderboard scoring spec.
    await assertSucceeds(
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

  it('stops a user granting themselves moderator', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'users', ALICE), { isModerator: true }),
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

  it('lets a moderator update another user', async () => {
    await assertSucceeds(
      updateDoc(doc(as(MOD), 'users', ALICE), { isBanned: true }),
    );
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

  it('lets a user file their own report', async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), 'reports', 'report-1'), {
        reporterId: ALICE,
        targetId: MALLORY,
        status: 'pending',
      }),
    );
  });

  it('stops a user filing a report under somebody else\'s name', async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), 'reports', 'report-1'), {
        reporterId: ALICE,
        targetId: BOB,
        status: 'pending',
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

  it('lets an owner read and write their own stats', async () => {
    await assertSucceeds(
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

  it('documents that any signed-in user can READ another user\'s stats', async () => {
    // stats/{statId} is `allow read: if isAuthenticated()`, so personal records
    // are readable by anyone signed in. That is the rule as written today and
    // this test pins it; whether PRs should be public is a product question,
    // recorded in the audit findings rather than changed here.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', ALICE, 'stats', 'prs'), {
        strength: { bench: { bestEstimate: 100 } },
      });
    });

    await assertSucceeds(
      getDoc(doc(as(MALLORY), 'users', ALICE, 'stats', 'prs')),
    );
  });
});
