// Behavioral Storage rules tests (Z-TEST-004).
//
// Run via `npm test` in this directory (emulators:exec includes storage).

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getBytes } from 'firebase/storage';
import { doc, setDoc } from 'firebase/firestore';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..', '..');

const ALICE = 'alice';
const BOB = 'bob';

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
    storage: {
      rules: readFileSync(
        resolve(REPO_ROOT, 'firebase', 'storage.rules'),
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
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', ALICE), {
      displayName: 'Alice',
      isPrivate: false,
    });
    await setDoc(doc(db, 'users', BOB), {
      displayName: 'Bob',
      isPrivate: false,
    });
    await setDoc(doc(db, 'posts', 'post1'), {
      authorId: ALICE,
      visibility: 'public',
    });
    await setDoc(doc(db, 'sessions', 'session1'), {
      participants: [ALICE, BOB],
      hostId: ALICE,
      status: 'active',
    });
  });
});

function tinyJpeg() {
  // Minimal JPEG SOI/EOI pair is enough for content-type checks.
  return new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
}

describe('storage rules', () => {
  it('lets the profile owner upload a photo under their uid', async () => {
    const alice = testEnv.authenticatedContext(ALICE);
    const storage = alice.storage();
    await assertSucceeds(
      uploadBytes(ref(storage, `profilePhotos/${ALICE}/avatar.jpg`), tinyJpeg(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  it('blocks another user from writing into someone else\'s profilePhotos', async () => {
    const bob = testEnv.authenticatedContext(BOB);
    const storage = bob.storage();
    await assertFails(
      uploadBytes(ref(storage, `profilePhotos/${ALICE}/hack.jpg`), tinyJpeg(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  it('denies unknown top-level paths', async () => {
    const alice = testEnv.authenticatedContext(ALICE);
    const storage = alice.storage();
    await assertFails(
      uploadBytes(ref(storage, `secrets/${ALICE}/x.bin`), tinyJpeg(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  it('lets a post author upload post media', async () => {
    const alice = testEnv.authenticatedContext(ALICE);
    const storage = alice.storage();
    await assertSucceeds(
      uploadBytes(ref(storage, 'posts/post1/photo.jpg'), tinyJpeg(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  it('blocks a stranger from writing post media', async () => {
    const bob = testEnv.authenticatedContext(BOB);
    const storage = bob.storage();
    await assertFails(
      uploadBytes(ref(storage, 'posts/post1/photo.jpg'), tinyJpeg(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  it('lets session participants upload voice notes', async () => {
    const alice = testEnv.authenticatedContext(ALICE);
    const storage = alice.storage();
    await assertSucceeds(
      uploadBytes(
        ref(storage, 'voiceNotes/session1/note.m4a'),
        new Uint8Array([0x00, 0x01]),
        { contentType: 'audio/mp4' },
      ),
    );
  });

  it('blocks non-participants from reading voice notes', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const storage = ctx.storage();
      await uploadBytes(
        ref(storage, 'voiceNotes/session1/note.m4a'),
        new Uint8Array([0x00, 0x01]),
        { contentType: 'audio/mp4' },
      );
    });

    const mallory = testEnv.authenticatedContext('mallory');
    await assertFails(getBytes(ref(mallory.storage(), 'voiceNotes/session1/note.m4a')));
  });
});
