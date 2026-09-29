// `posts.authorIsPrivate` lets multi-author post queries satisfy the
// Firestore `list` rule (isListablePublicPost) without per-doc user lookups,
// which a query can't prove. It is server-owned: the rules forbid clients
// from writing it.

// Ids of every author on a post (co-authored posts carry several).
function postAuthorIds(post) {
  const ids = Array.isArray(post.authorIds) && post.authorIds.length > 0
    ? post.authorIds
    : [post.authorId];
  return [...new Set(ids.filter((id) => typeof id === "string" && id))];
}

// True when any author is a private account. A missing user doc counts as
// private so an orphaned post fails closed (mirrors isPublicProfile).
async function computeAuthorIsPrivate(db, post, known = new Map()) {
  const ids = postAuthorIds(post);
  if (ids.length === 0) return true;

  const missing = ids.filter((id) => !known.has(id));
  if (missing.length > 0) {
    const snaps = await db.getAll(...missing.map((id) => db.collection("users").doc(id)));
    for (const snap of snaps) {
      known.set(snap.id, !snap.exists || snap.get("isPrivate") === true);
    }
  }
  return ids.some((id) => known.get(id) === true);
}

// Re-stamp every post in `docs` whose flag is stale. Returns the number of
// posts updated. `known` caches user privacy across calls.
async function restampPosts(db, docs, known = new Map()) {
  let updated = 0;
  let batch = db.batch();
  let pending = 0;

  for (const doc of docs) {
    const next = await computeAuthorIsPrivate(db, doc.data(), known);
    if (doc.get("authorIsPrivate") === next) continue;
    batch.update(doc.ref, { authorIsPrivate: next });
    pending += 1;
    updated += 1;
    if (pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return updated;
}

module.exports = { computeAuthorIsPrivate, postAuthorIds, restampPosts };
