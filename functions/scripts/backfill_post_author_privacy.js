// One-off backfill: stamp `authorIsPrivate` on every existing post so it can
// match the isListablePublicPost `list` rule. Idempotent — only stale docs
// are written, so re-running is safe.
//
// Run from functions/ with Admin credentials for the target project:
//   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> \
//     node scripts/backfill_post_author_privacy.js [--dry-run]
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldPath } = require("firebase-admin/firestore");
const { computeAuthorIsPrivate, restampPosts } = require("../lib/post_author_privacy");

const PAGE_SIZE = 300;

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  initializeApp();
  const db = getFirestore();
  const known = new Map();

  let scanned = 0;
  let updated = 0;
  let cursor = null;

  for (;;) {
    let query = db.collection("posts").orderBy(FieldPath.documentId()).limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;

    scanned += page.size;
    if (dryRun) {
      for (const doc of page.docs) {
        const next = await computeAuthorIsPrivate(db, doc.data(), known);
        if (doc.get("authorIsPrivate") !== next) updated += 1;
      }
    } else {
      updated += await restampPosts(db, page.docs, known);
    }
    cursor = page.docs[page.docs.length - 1];
    console.log(`scanned ${scanned}, ${dryRun ? "would update" : "updated"} ${updated}`);
  }

  console.log(`Done. ${scanned} posts scanned, ${updated} ${dryRun ? "stale" : "stamped"}.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
