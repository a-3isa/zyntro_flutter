// One-time backfill: stamp authorIds/status/coAuthored on existing posts
// so the new author-scoped queries (getUserPosts/watchUserPosts, feed queries)
// don't drop pre-existing posts that predate the joint-post feature.
//
// STATUS: ALREADY RUN against the production project `zynrto` (2026-07-28),
// before the joint-post branch shipped. It is kept in the repo as the record
// of what was applied and as a safety net for any post that slipped through.
//
// Idempotent and safe to re-run: it skips every document that already has an
// `authorIds` field and only writes the three fields in the update mask, so a
// second run over an already-backfilled collection is a no-op. Pass --dry-run
// to see what it would touch without writing.
//
// Usage:  firebase login  &&  node scripts/backfill_post_authorids.js [--dry-run]
const https = require("https");
const fs = require("fs");
const path = require("path");
const os = require("os");

const DRY_RUN = process.argv.includes("--dry-run");
const PROJECT_ID = "zynrto";
const COLLECTION = "posts";
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

async function listPage(token, pageToken) {
  let p = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}?pageSize=300`;
  if (pageToken) p += `&pageToken=${encodeURIComponent(pageToken)}`;
  return request("GET", p, token);
}

function patchDoc(token, name, authorId) {
  const updateMask = "updateMask.fieldPaths=authorIds&updateMask.fieldPaths=status&updateMask.fieldPaths=coAuthored";
  const relName = name.split("/documents/")[1];
  const p = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${relName}?${updateMask}`;
  const body = {
    fields: {
      authorIds: { arrayValue: { values: [{ stringValue: authorId }] } },
      status: { stringValue: "published" },
      coAuthored: { booleanValue: false },
    },
  };
  return request("PATCH", p, token, body);
}

async function main() {
  const token = getAccessToken();
  let pageToken;
  let scanned = 0, needsBackfill = 0, patched = 0, skippedNoAuthorId = 0;
  do {
    const page = await listPage(token, pageToken);
    const docs = page.documents || [];
    for (const doc of docs) {
      scanned++;
      const fields = doc.fields || {};
      if (fields.authorIds) continue; // already backfilled/co-authored
      needsBackfill++;
      const authorId = fields.authorId && fields.authorId.stringValue;
      if (!authorId) { skippedNoAuthorId++; console.warn("skip (no authorId):", doc.name); continue; }
      if (DRY_RUN) {
        console.log("[dry-run] would backfill", doc.name, "authorId=", authorId);
        continue;
      }
      await patchDoc(token, doc.name, authorId);
      patched++;
      if (patched % 50 === 0) console.log("patched", patched, "so far...");
    }
    pageToken = page.nextPageToken;
  } while (pageToken);

  console.log("---");
  console.log("scanned:", scanned, "needing backfill:", needsBackfill, "patched:", patched, "skipped (no authorId):", skippedNoAuthorId);
  if (DRY_RUN) console.log("(dry run — no writes made)");
}

main().catch(e => { console.error(e); process.exit(1); });
