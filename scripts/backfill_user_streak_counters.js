// One-time backfill: derive the maintained streak counters
// (currentStreak, longestStreak, lastWorkoutDate, weeklyWorkouts,
// weekStartDate, buddyWorkouts) onto every user document from their existing
// completed sessions.
//
// Why: calculateUserStreak used to recompute these by reading a user's entire
// completed-session history on every request, a read cost that grew with every
// workout they ever logged. They are now maintained incrementally at session
// end and read as one document. Users whose documents predate the counters
// fall back to the old history scan until either their next completed session
// writes the counters, or this script runs.
//
// STATUS: NOT YET RUN. The fallback path in UserService means running this is
// an optimization, not a correctness requirement — nothing breaks if it never
// runs, users just keep paying the old scan cost until their next session.
//
// Idempotent and safe to re-run: it skips every user document that already has
// a `lastWorkoutDate`, and only writes the six fields in the update mask.
// Pass --dry-run to see what it would touch without writing.
//
// Usage:  firebase login  &&  node scripts/backfill_user_streak_counters.js [--dry-run]
const https = require("https");
const fs = require("fs");
const path = require("path");
const os = require("os");

const DRY_RUN = process.argv.includes("--dry-run");
const PROJECT_ID = "zynrto";
const BASE = "firestore.googleapis.com";

function getAccessToken() {
  const cfgPath = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");
  if (!fs.existsSync(cfgPath)) throw new Error("Run firebase login first.");
  const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
  const t = cfg.tokens;
  if (!t || !t.access_token) throw new Error("No access token.");
  if (t.expires_at && t.expires_at < Date.now()) throw new Error("Token expired. Run: firebase login --reauth");
  return t.access_token;
}

function request(method, reqPath, token, body) {
  return new Promise((resolve, reject) => {
    const json = body ? JSON.stringify(body) : undefined;
    const headers = { "Authorization": "Bearer " + token };
    if (json) {
      headers["Content-Type"] = "application/json";
      headers["Content-Length"] = Buffer.byteLength(json);
    }
    const req = https.request({ hostname: BASE, path: reqPath, method, headers }, res => {
      let d = "";
      res.on("data", c => d += c);
      res.on("end", () => {
        if (res.statusCode >= 300) return reject(new Error("HTTP " + res.statusCode + ": " + d));
        resolve(d ? JSON.parse(d) : {});
      });
    });
    req.on("error", reject);
    if (json) req.write(json);
    req.end();
  });
}

async function listUsers(token, pageToken) {
  let p = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users?pageSize=300`;
  if (pageToken) p += `&pageToken=${encodeURIComponent(pageToken)}`;
  return request("GET", p, token);
}

// Completed sessions for one user. Mirrors the client query in
// UserService._calculateUserStreakFromHistory.
async function listCompletedSessions(token, userId) {
  const p = `/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`;
  const body = {
    structuredQuery: {
      from: [{ collectionId: "sessions" }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: "participants" },
                op: "ARRAY_CONTAINS",
                value: { stringValue: userId },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: "status" },
                op: "EQUAL",
                value: { stringValue: "completed" },
              },
            },
          ],
        },
      },
    },
  };
  const rows = await request("POST", p, token, body);
  return rows.filter(r => r.document).map(r => r.document);
}

// These three must stay in lockstep with lib/features/session/domain/workout_streak.dart.
function calendarDay(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function weekStartFor(date) {
  const midnight = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  // JS getDay() is 0=Sunday; the app's week starts Monday.
  const isoWeekday = midnight.getDay() === 0 ? 7 : midnight.getDay();
  midnight.setDate(midnight.getDate() - (isoWeekday - 1));
  return calendarDay(midnight);
}

function deriveCounters(sessions, userId) {
  const days = new Set();
  let buddyWorkouts = 0;
  let weeklyWorkouts = 0;
  const thisWeek = weekStartFor(new Date());

  for (const doc of sessions) {
    const fields = doc.fields || {};
    const participants = (fields.participants && fields.participants.arrayValue && fields.participants.arrayValue.values) || [];
    if (participants.length > 1) buddyWorkouts++;

    const createdAt = fields.createdAt && fields.createdAt.timestampValue;
    if (!createdAt) continue;
    const date = new Date(createdAt);
    days.add(calendarDay(date));
    if (weekStartFor(date) === thisWeek) weeklyWorkouts++;
  }

  const sorted = [...days].sort(); // ascending yyyy-MM-dd sorts chronologically
  let longestStreak = 0;
  let run = 0;
  let previous = null;
  for (const day of sorted) {
    if (previous === null) {
      run = 1;
    } else {
      const gap = (new Date(day) - new Date(previous)) / 86400000;
      run = gap === 1 ? run + 1 : 1;
    }
    if (run > longestStreak) longestStreak = run;
    previous = day;
  }

  // `run` currently holds the streak ending on the most recent workout day.
  // Store it as-is; the client zeroes it on read when it has gone stale, the
  // same way it does for counters written by session end.
  return {
    currentStreak: sorted.length ? run : 0,
    longestStreak,
    lastWorkoutDate: sorted.length ? sorted[sorted.length - 1] : null,
    weeklyWorkouts,
    weekStartDate: thisWeek,
    buddyWorkouts,
  };
}

function patchUser(token, name, counters) {
  const paths = ["currentStreak", "longestStreak", "lastWorkoutDate", "weeklyWorkouts", "weekStartDate", "buddyWorkouts"];
  const updateMask = paths.map(f => `updateMask.fieldPaths=${f}`).join("&");
  const relName = name.split("/documents/")[1];
  const p = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${relName}?${updateMask}`;
  const body = {
    fields: {
      currentStreak: { integerValue: String(counters.currentStreak) },
      longestStreak: { integerValue: String(counters.longestStreak) },
      lastWorkoutDate: { stringValue: counters.lastWorkoutDate },
      weeklyWorkouts: { integerValue: String(counters.weeklyWorkouts) },
      weekStartDate: { stringValue: counters.weekStartDate },
      buddyWorkouts: { integerValue: String(counters.buddyWorkouts) },
    },
  };
  return request("PATCH", p, token, body);
}

async function main() {
  const token = getAccessToken();
  let pageToken;
  let scanned = 0, alreadyDone = 0, noHistory = 0, patched = 0;
  do {
    const page = await listUsers(token, pageToken);
    for (const doc of page.documents || []) {
      scanned++;
      const fields = doc.fields || {};
      if (fields.lastWorkoutDate) { alreadyDone++; continue; }

      const userId = doc.name.split("/").pop();
      const sessions = await listCompletedSessions(token, userId);
      const counters = deriveCounters(sessions, userId);

      // A user with no completed sessions has nothing to backfill; leaving
      // lastWorkoutDate unset keeps them on the (free, zero-result) fallback.
      if (!counters.lastWorkoutDate) { noHistory++; continue; }

      if (DRY_RUN) {
        console.log("[dry-run] would backfill", userId, JSON.stringify(counters));
        continue;
      }
      await patchUser(token, doc.name, counters);
      patched++;
      if (patched % 25 === 0) console.log("patched", patched, "so far...");
    }
    pageToken = page.nextPageToken;
  } while (pageToken);

  console.log("---");
  console.log("scanned:", scanned, "already had counters:", alreadyDone, "no completed sessions:", noHistory, "patched:", patched);
  if (DRY_RUN) console.log("(dry run — no writes made)");
}

main().catch(e => { console.error(e); process.exit(1); });
