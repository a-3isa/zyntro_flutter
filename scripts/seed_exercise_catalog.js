#!/usr/bin/env node
/**
 * Seeds the Firestore `exerciseCatalog` collection from the local GymExercises dataset.
 *
 * Prerequisites:
 *   - gcloud CLI authenticated (gcloud auth login), OR
 *   - GOOGLE_APPLICATION_CREDENTIALS set to a service account key file
 *
 * Usage:
 *   node scripts/seed_exercise_catalog.js [--dry-run] [--project <id>]
 *
 * Options:
 *   --dry-run    Print documents without writing to Firestore
 *   --project    Firebase project ID (default: read from .firebaserc or 'zynrto')
 */

'use strict';

const https = require('https');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// CLI flags
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const projectIdx = args.indexOf('--project');
let PROJECT_ID = projectIdx !== -1 ? args[projectIdx + 1] : null;

if (!PROJECT_ID) {
  try {
    const rc = JSON.parse(
      fs.readFileSync(path.join(__dirname, '..', '.firebaserc'), 'utf8'),
    );
    PROJECT_ID = rc.projects?.default || 'zynrto';
  } catch {
    PROJECT_ID = 'zynrto';
  }
}

const FIRESTORE_BASE =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// ---------------------------------------------------------------------------
// Exercise data (mirrors lib/core/data/gym_exercises.dart)
// ---------------------------------------------------------------------------
function tokens(name) {
  return name.toLowerCase().replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim().split(' ').filter(Boolean);
}

const exercises = [
  // ── CHEST ──────────────────────────────────────────────────────────────
  { id: 'bench_press',           name: 'Bench Press',            muscleGroup: 'chest',     equipment: 'Barbell' },
  { id: 'incline_bench_press',   name: 'Incline Bench Press',    muscleGroup: 'chest',     equipment: 'Barbell' },
  { id: 'decline_bench_press',   name: 'Decline Bench Press',    muscleGroup: 'chest',     equipment: 'Barbell' },
  { id: 'dumbbell_bench_press',  name: 'Dumbbell Bench Press',   muscleGroup: 'chest',     equipment: 'Dumbbell' },
  { id: 'dumbbell_flyes',        name: 'Dumbbell Flyes',         muscleGroup: 'chest',     equipment: 'Dumbbell' },
  { id: 'incline_dumbbell_flyes',name: 'Incline Dumbbell Flyes', muscleGroup: 'chest',     equipment: 'Dumbbell' },
  { id: 'cable_crossover',       name: 'Cable Crossover',        muscleGroup: 'chest',     equipment: 'Cables' },
  { id: 'cable_flyes',           name: 'Cable Flyes',            muscleGroup: 'chest',     equipment: 'Cables' },
  { id: 'push_ups',              name: 'Push-Ups',               muscleGroup: 'chest',     equipment: 'Bodyweight' },
  { id: 'chest_dips',            name: 'Chest Dips',             muscleGroup: 'chest',     equipment: 'Bodyweight' },
  { id: 'machine_chest_press',   name: 'Machine Chest Press',    muscleGroup: 'chest',     equipment: 'Machine' },
  { id: 'pec_deck_fly',          name: 'Pec Deck Fly',           muscleGroup: 'chest',     equipment: 'Machine' },

  // ── BACK ────────────────────────────────────────────────────────────────
  { id: 'lat_pulldown',          name: 'Lat Pulldown',           muscleGroup: 'back',      equipment: 'Cables' },
  { id: 'pull_ups',              name: 'Pull-Ups',               muscleGroup: 'back',      equipment: 'Pull-up Bar' },
  { id: 'chin_ups',              name: 'Chin-Ups',               muscleGroup: 'back',      equipment: 'Pull-up Bar' },
  { id: 'barbell_row',           name: 'Barbell Row',            muscleGroup: 'back',      equipment: 'Barbell' },
  { id: 'dumbbell_row',          name: 'Dumbbell Row',           muscleGroup: 'back',      equipment: 'Dumbbell' },
  { id: 'cable_row',             name: 'Seated Cable Row',       muscleGroup: 'back',      equipment: 'Cables' },
  { id: 't_bar_row',             name: 'T-Bar Row',              muscleGroup: 'back',      equipment: 'Barbell' },
  { id: 'deadlift',              name: 'Deadlift',               muscleGroup: 'back',      equipment: 'Barbell' },
  { id: 'face_pulls',            name: 'Face Pulls',             muscleGroup: 'back',      equipment: 'Cables' },
  { id: 'straight_arm_pulldown', name: 'Straight Arm Pulldown',  muscleGroup: 'back',      equipment: 'Cables' },
  { id: 'machine_row',           name: 'Machine Row',            muscleGroup: 'back',      equipment: 'Machine' },

  // ── SHOULDERS ───────────────────────────────────────────────────────────
  { id: 'overhead_press',           name: 'Overhead Press',          muscleGroup: 'shoulders', equipment: 'Barbell' },
  { id: 'dumbbell_shoulder_press',  name: 'Dumbbell Shoulder Press', muscleGroup: 'shoulders', equipment: 'Dumbbell' },
  { id: 'arnold_press',             name: 'Arnold Press',            muscleGroup: 'shoulders', equipment: 'Dumbbell' },
  { id: 'lateral_raises',           name: 'Lateral Raises',          muscleGroup: 'shoulders', equipment: 'Dumbbell' },
  { id: 'front_raises',             name: 'Front Raises',            muscleGroup: 'shoulders', equipment: 'Dumbbell' },
  { id: 'rear_delt_flyes',          name: 'Rear Delt Flyes',         muscleGroup: 'shoulders', equipment: 'Dumbbell' },
  { id: 'cable_lateral_raises',     name: 'Cable Lateral Raises',    muscleGroup: 'shoulders', equipment: 'Cables' },
  { id: 'upright_rows',             name: 'Upright Rows',            muscleGroup: 'shoulders', equipment: 'Barbell' },
  { id: 'shrugs',                   name: 'Shrugs',                  muscleGroup: 'shoulders', equipment: 'Barbell' },
  { id: 'machine_shoulder_press',   name: 'Machine Shoulder Press',  muscleGroup: 'shoulders', equipment: 'Machine' },

  // ── BICEPS ──────────────────────────────────────────────────────────────
  { id: 'barbell_curl',          name: 'Barbell Curl',           muscleGroup: 'biceps',    equipment: 'Barbell' },
  { id: 'dumbbell_curl',         name: 'Dumbbell Curl',          muscleGroup: 'biceps',    equipment: 'Dumbbell' },
  { id: 'hammer_curl',           name: 'Hammer Curl',            muscleGroup: 'biceps',    equipment: 'Dumbbell' },
  { id: 'preacher_curl',         name: 'Preacher Curl',          muscleGroup: 'biceps',    equipment: 'Barbell' },
  { id: 'concentration_curl',    name: 'Concentration Curl',     muscleGroup: 'biceps',    equipment: 'Dumbbell' },
  { id: 'cable_curl',            name: 'Cable Curl',             muscleGroup: 'biceps',    equipment: 'Cables' },
  { id: 'incline_dumbbell_curl', name: 'Incline Dumbbell Curl',  muscleGroup: 'biceps',    equipment: 'Dumbbell' },
  { id: 'ez_bar_curl',           name: 'EZ Bar Curl',            muscleGroup: 'biceps',    equipment: 'Barbell' },
  { id: 'spider_curl',           name: 'Spider Curl',            muscleGroup: 'biceps',    equipment: 'Dumbbell' },

  // ── TRICEPS ─────────────────────────────────────────────────────────────
  { id: 'tricep_pushdown',           name: 'Tricep Pushdown',          muscleGroup: 'triceps',   equipment: 'Cables' },
  { id: 'skull_crushers',            name: 'Skull Crushers',           muscleGroup: 'triceps',   equipment: 'Barbell' },
  { id: 'close_grip_bench_press',    name: 'Close Grip Bench Press',   muscleGroup: 'triceps',   equipment: 'Barbell' },
  { id: 'tricep_dips',               name: 'Tricep Dips',              muscleGroup: 'triceps',   equipment: 'Bodyweight' },
  { id: 'overhead_tricep_extension', name: 'Overhead Tricep Extension',muscleGroup: 'triceps',   equipment: 'Dumbbell' },
  { id: 'kickbacks',                 name: 'Tricep Kickbacks',         muscleGroup: 'triceps',   equipment: 'Dumbbell' },
  { id: 'diamond_push_ups',          name: 'Diamond Push-Ups',         muscleGroup: 'triceps',   equipment: 'Bodyweight' },
  { id: 'rope_pushdown',             name: 'Rope Pushdown',            muscleGroup: 'triceps',   equipment: 'Cables' },

  // ── LEGS ────────────────────────────────────────────────────────────────
  { id: 'squat',                 name: 'Barbell Squat',          muscleGroup: 'legs',      equipment: 'Barbell' },
  { id: 'front_squat',           name: 'Front Squat',            muscleGroup: 'legs',      equipment: 'Barbell' },
  { id: 'leg_press',             name: 'Leg Press',              muscleGroup: 'legs',      equipment: 'Machine' },
  { id: 'lunges',                name: 'Lunges',                 muscleGroup: 'legs',      equipment: 'Dumbbell' },
  { id: 'bulgarian_split_squat', name: 'Bulgarian Split Squat',  muscleGroup: 'legs',      equipment: 'Dumbbell' },
  { id: 'leg_extension',         name: 'Leg Extension',          muscleGroup: 'legs',      equipment: 'Machine' },
  { id: 'leg_curl',              name: 'Leg Curl',               muscleGroup: 'legs',      equipment: 'Machine' },
  { id: 'romanian_deadlift',     name: 'Romanian Deadlift',      muscleGroup: 'legs',      equipment: 'Barbell' },
  { id: 'calf_raises',           name: 'Calf Raises',            muscleGroup: 'legs',      equipment: 'Machine' },
  { id: 'goblet_squat',          name: 'Goblet Squat',           muscleGroup: 'legs',      equipment: 'Dumbbell' },
  { id: 'hack_squat',            name: 'Hack Squat',             muscleGroup: 'legs',      equipment: 'Machine' },
  { id: 'hip_thrust',            name: 'Hip Thrust',             muscleGroup: 'legs',      equipment: 'Barbell' },
  { id: 'step_ups',              name: 'Step-Ups',               muscleGroup: 'legs',      equipment: 'Dumbbell' },

  // ── CORE ────────────────────────────────────────────────────────────────
  { id: 'plank',               name: 'Plank',             muscleGroup: 'core',      equipment: 'Bodyweight' },
  { id: 'crunches',            name: 'Crunches',          muscleGroup: 'core',      equipment: 'Bodyweight' },
  { id: 'hanging_leg_raises',  name: 'Hanging Leg Raises',muscleGroup: 'core',      equipment: 'Pull-up Bar' },
  { id: 'cable_woodchops',     name: 'Cable Woodchops',   muscleGroup: 'core',      equipment: 'Cables' },
  { id: 'ab_wheel_rollout',    name: 'Ab Wheel Rollout',  muscleGroup: 'core',      equipment: 'Other' },
  { id: 'russian_twists',      name: 'Russian Twists',    muscleGroup: 'core',      equipment: 'Bodyweight' },
  { id: 'dead_bug',            name: 'Dead Bug',          muscleGroup: 'core',      equipment: 'Bodyweight' },
  { id: 'mountain_climbers',   name: 'Mountain Climbers', muscleGroup: 'core',      equipment: 'Bodyweight' },
  { id: 'bicycle_crunches',    name: 'Bicycle Crunches',  muscleGroup: 'core',      equipment: 'Bodyweight' },
  { id: 'side_plank',          name: 'Side Plank',        muscleGroup: 'core',      equipment: 'Bodyweight' },
  { id: 'cable_crunch',        name: 'Cable Crunch',      muscleGroup: 'core',      equipment: 'Cables' },
];

// ---------------------------------------------------------------------------
// Firestore field helpers
// ---------------------------------------------------------------------------
function firestoreDoc(name, fields) {
  return { name, fields };
}

function strField(v) { return { stringValue: v }; }
function boolField(v) { return { booleanValue: v }; }
function arrayField(values) {
  return { arrayValue: { values: values.map(strField) } };
}
function timestampField() {
  return { timestampValue: new Date().toISOString() };
}

function exerciseToFields(ex) {
  const normalizedName = ex.name.toLowerCase().replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim();
  const searchTokens = tokens(ex.name);
  return {
    id:             strField(ex.id),
    name:           strField(ex.name),
    normalizedName: strField(normalizedName),
    searchTokens:   arrayField(searchTokens),
    muscleGroup:    strField(ex.muscleGroup),
    equipment:      strField(ex.equipment),
    isActive:       boolField(true),
    createdAt:      timestampField(),
  };
}

// ---------------------------------------------------------------------------
// Firestore REST batchWrite
// ---------------------------------------------------------------------------
function httpsPost(url, token, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const u = new URL(url);
    const req = https.request(
      {
        hostname: u.hostname,
        path: u.pathname + u.search,
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
        },
      },
      (res) => {
        let buf = '';
        res.on('data', (c) => (buf += c));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(JSON.parse(buf));
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${buf}`));
          }
        });
      },
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function batchWrite(token, writes) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:batchWrite`;
  return httpsPost(url, token, { writes });
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  console.log(`\nFirestore exercise catalog seeder`);
  console.log(`  Project : ${PROJECT_ID}`);
  console.log(`  Exercises: ${exercises.length}`);
  console.log(`  Mode    : ${DRY_RUN ? 'DRY RUN (no writes)' : 'LIVE'}\n`);

  // Verify FR-013 coverage
  const groups = [...new Set(exercises.map((e) => e.muscleGroup))];
  console.log(`Muscle groups (${groups.length}): ${groups.join(', ')}`);
  if (groups.length < 6) {
    console.error('ERROR: FR-013 requires at least 6 distinct muscle groups.');
    process.exit(1);
  }
  if (exercises.length < 40) {
    console.error('ERROR: FR-013 requires at least 40 exercises.');
    process.exit(1);
  }
  console.log(`FR-013: ✓ ${exercises.length} exercises, ${groups.length} muscle groups\n`);

  if (DRY_RUN) {
    exercises.forEach((ex) =>
      console.log(`  [DRY] exerciseCatalog/${ex.id} — ${ex.name} (${ex.muscleGroup})`),
    );
    console.log('\nDry run complete — no documents written.');
    return;
  }

  // Get access token
  let token;
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    // Use service account via gcloud
    try {
      token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();
    } catch {
      console.error('Failed to get access token. Ensure gcloud is authenticated.');
      process.exit(1);
    }
  } else {
    try {
      token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();
    } catch {
      console.error(
        'Failed to get access token.\n' +
        'Run: gcloud auth application-default login\n' +
        'Or set GOOGLE_APPLICATION_CREDENTIALS to a service account key file.',
      );
      process.exit(1);
    }
  }

  // Build write operations (batch up to 500 per call)
  const writes = exercises.map((ex) => ({
    update: {
      name: `projects/${PROJECT_ID}/databases/(default)/documents/exerciseCatalog/${ex.id}`,
      fields: exerciseToFields(ex),
    },
  }));

  // Split into chunks of 500 (Firestore limit)
  const CHUNK = 500;
  for (let i = 0; i < writes.length; i += CHUNK) {
    const chunk = writes.slice(i, i + CHUNK);
    process.stdout.write(`Writing ${chunk.length} exercises to exerciseCatalog... `);
    try {
      await batchWrite(token, chunk);
      console.log('✓');
    } catch (err) {
      console.error(`\nWrite failed: ${err.message}`);
      process.exit(1);
    }
  }

  console.log(`\n✓ Seeded ${exercises.length} exercises across ${groups.length} muscle groups.`);
  console.log('FR-013 minimum-coverage criteria met.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
