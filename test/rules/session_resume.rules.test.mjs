// Behavioral (emulator-backed) tests for the rules added by
// specs/007-resume-active-session: per-member session termination, the activity
// stamps that ride along with every session state change, and the runtime
// feature-flag document.
//
// Per-member termination is the reason these exist. Terminating a shared
// session must end it for the terminating member ONLY — the partner keeps
// training. A rule that let one member write another's uid into
// `endedParticipants`, or that let the termination write smuggle in other
// fields, would silently end someone else's workout. That is exactly the class
// of defect a string-contract test cannot catch.
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
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..', '..');

const ALICE = 'alice';
const BOB = 'bob';
const MALLORY = 'mallory';

const SESSION = 'session1';

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
    // A live two-person session. No `invitationStatus`, so the paired-invite
    // transitions do not apply and the participant/termination rules are what
    // gets exercised.
    await setDoc(doc(db, 'sessions', SESSION), {
      hostId: ALICE,
      participants: [ALICE, BOB],
      participantTypes: { [ALICE]: 'gym', [BOB]: 'gym' },
      status: 'active',
      phase: 'live',
      activeUserId: ALICE,
      endedParticipants: [],
    });
    await setDoc(doc(db, 'config', 'featureFlags'), {
      resumeActiveSessionEnabled: true,
    });
  });
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

describe('sessions/{id} — per-member termination', () => {
  it('lets a participant end their own part in the session', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        endedParticipants: [ALICE],
      }),
    );
  });

  it('leaves the session live for the other participant', async () => {
    await updateDoc(doc(as(ALICE), 'sessions', SESSION), {
      endedParticipants: [ALICE],
    });
    // Bob is still a participant of a live session and can still act in it.
    await assertSucceeds(
      updateDoc(doc(as(BOB), 'sessions', SESSION), { activeUserId: BOB }),
    );
  });

  it('refuses to let a member terminate on someone else’s behalf', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        endedParticipants: [BOB],
      }),
    );
  });

  it('refuses to let a member terminate everyone at once', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        endedParticipants: [ALICE, BOB],
      }),
    );
  });

  it('refuses to let a termination write remove an existing entry', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'sessions', SESSION), {
        endedParticipants: [BOB],
      });
    });
    // Alice may add herself, but must not drop Bob while doing it.
    await assertFails(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        endedParticipants: [ALICE],
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        endedParticipants: [BOB, ALICE],
      }),
    );
  });

  it('refuses a non-participant terminating in someone else’s session', async () => {
    await assertFails(
      updateDoc(doc(as(MALLORY), 'sessions', SESSION), {
        endedParticipants: [MALLORY],
      }),
    );
  });

  it('allows handing the turn to the remaining member in the same termination write', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        endedParticipants: [ALICE],
        activeUserId: BOB,
      }),
    );
  });

  it('refuses a termination write that smuggles in another field', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        endedParticipants: [ALICE],
        hostId: ALICE === BOB ? ALICE : BOB,
      }),
    );
  });

  it('allows the activity stamps to ride along with a termination', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        endedParticipants: [ALICE],
        lastActivityAt: new Date(),
        expiresAt: new Date(Date.now() + 3 * 60 * 60 * 1000),
      }),
    );
  });
});

describe('sessions/{id} — activity stamps on ordinary writes', () => {
  it('lets a participant stamp activity alongside a turn change', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        activeUserId: BOB,
        lastActivityAt: new Date(),
        expiresAt: new Date(Date.now() + 3 * 60 * 60 * 1000),
      }),
    );
  });

  it('lets a participant refresh occupancy from the presence heartbeat', async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        lastOccupiedAt: new Date(),
        expiresAt: new Date(Date.now() + 3 * 60 * 60 * 1000),
      }),
    );
  });

  it('still refuses a non-participant writing stamps', async () => {
    await assertFails(
      updateDoc(doc(as(MALLORY), 'sessions', SESSION), {
        lastActivityAt: new Date(),
      }),
    );
  });

  it('does not let the stamps be used to smuggle a host takeover', async () => {
    await assertFails(
      updateDoc(doc(as(BOB), 'sessions', SESSION), {
        hostId: BOB,
        lastActivityAt: new Date(),
      }),
    );
  });

  it('refuses completing a shared session while the partner is still live', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        status: 'completed',
        endedAt: new Date(),
      }),
    );
  });

  it('lets the last live member complete the session', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'sessions', SESSION), {
        endedParticipants: [BOB],
      });
    });
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        status: 'completed',
        endedAt: new Date(),
      }),
    );
  });

  it('refuses shrinking the participant roster', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'sessions', SESSION), {
        participants: [ALICE],
      }),
    );
  });
});

describe('config/{document} — runtime feature flags', () => {
  it('is readable by a signed-in user', async () => {
    await assertSucceeds(getDoc(doc(as(ALICE), 'config', 'featureFlags')));
  });

  it('is readable before sign-in, because the app reads it at startup', async () => {
    await assertSucceeds(getDoc(doc(anon(), 'config', 'featureFlags')));
  });

  it('refuses a client flipping the kill switch', async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), 'config', 'featureFlags'), {
        resumeActiveSessionEnabled: false,
      }),
    );
  });

  it('refuses a client creating a new flag document', async () => {
    await assertFails(
      setDoc(doc(as(ALICE), 'config', 'somethingElse'), { enabled: true }),
    );
  });
});
