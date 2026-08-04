const { initializeApp } = require("firebase-admin/app");
const { getAppCheck } = require("firebase-admin/app-check");
const { getAuth } = require("firebase-admin/auth");
const { FieldValue, getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");

initializeApp();

const appCheck = getAppCheck();
const auth = getAuth();
const db = getFirestore();
const messaging = getMessaging();

const INVALID_TOKEN_ERRORS = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

function allowedCorsOrigins() {
  return (process.env.ALLOWED_CORS_ORIGINS || "")
    .split(",")
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}

function setCorsHeaders(req, res) {
  const origin = req.get("Origin");
  res.set("Vary", "Origin");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Firebase-AppCheck");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (origin && allowedCorsOrigins().includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
}

function requireString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required.`);
  }
  return value.trim();
}

function followDocId(followerId, followeeId) {
  return `${followerId}_${followeeId}`;
}

function normalizeData(data) {
  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== null && value !== undefined)
      .map(([key, value]) => [key, typeof value === "string" ? value : JSON.stringify(value)]),
  );
}

async function getUserDisplayName(userId) {
  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) {
    return "Someone";
  }
  const data = userDoc.data() || {};
  return typeof data.displayName === "string" && data.displayName.trim().length > 0
    ? data.displayName.trim()
    : "Someone";
}

async function getRecipientDevices(recipientId) {
  const snapshot = await db
    .collection("users")
    .doc(recipientId)
    .collection("devices")
    .get();

  return snapshot.docs
    .map((doc) => {
      const data = doc.data() || {};
      return {
        id: doc.id,
        token: typeof data.token === "string" ? data.token : null,
      };
    })
    .filter((device) => device.token);
}

async function pruneInvalidTokens(recipientId, devices, responses) {
  const batch = db.batch();
  let invalidCount = 0;

  responses.forEach((response, index) => {
    const code = response.error && response.error.code;
    if (!response.success && INVALID_TOKEN_ERRORS.has(code)) {
      invalidCount += 1;
      batch.delete(
        db.collection("users").doc(recipientId).collection("devices").doc(devices[index].id),
      );
    }
  });

  if (invalidCount > 0) {
    await batch.commit();
  }
}

// Mirrors NotificationService.shouldSendNotification on the client: gates the
// FCM push (not the durable in-app doc) on the recipient's preferences. Missing
// settings doc / fields default to enabled.
async function recipientAllowsPush(recipientId, type) {
  const snap = await db
    .collection("users")
    .doc(recipientId)
    .collection("settings")
    .doc("notifications")
    .get();
  const prefs = snap.exists ? snap.data() || {} : {};
  const enabled = (key) => prefs[key] !== false;

  if (!enabled("pushEnabled")) {
    return false;
  }

  switch (type) {
    case "session_invite":
      return enabled("sessionInvites");
    case "turn_change":
      return true; // core in-session gameplay, gated only by pushEnabled
    case "voice_note":
      return enabled("voiceNotes");
    case "new_follower":
    case "follow_request":
      return enabled("followRequests");
    case "follow_accepted":
      return enabled("followAccepted");
    case "post_like":
      return enabled("postLikes");
    case "post_comment":
      return enabled("postComments");
    default:
      return true;
  }
}

// Sends the FCM push for an already-persisted notification and returns
// { delivered, failed, skipped }. This is the single push-delivery path in the
// backend: the HTTP endpoint (client-triggered notifications) and
// server-initiated notifications (e.g. the scheduled joint-draft expiry offer)
// both go through it, so every type gets the same preference gate and the same
// invalid-token pruning. Writing a notification doc without calling this leaves
// the notification sitting silently in the in-app tab.
async function pushToRecipientDevices(recipientId, type, payload) {
  const allowPush = await recipientAllowsPush(recipientId, type);
  if (!allowPush) {
    logger.info("Recipient disabled push for this type.", { recipientId, type });
    return { delivered: 0, failed: 0, skipped: true };
  }

  const devices = await getRecipientDevices(recipientId);
  if (devices.length === 0) {
    logger.info("No device tokens found for recipient.", { recipientId, type });
    return { delivered: 0, failed: 0, skipped: true };
  }

  const response = await messaging.sendEachForMulticast({
    tokens: devices.map((device) => device.token),
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: normalizeData(payload.data),
  });

  await pruneInvalidTokens(recipientId, devices, response.responses);

  return {
    delivered: response.successCount,
    failed: response.failureCount,
    skipped: false,
  };
}

async function persistRecipientNotification(recipientId, type, payload) {
  const notifications = db
    .collection("users")
    .doc(recipientId)
    .collection("notifications");
  const isSessionInvite = type === "session_invite" && payload.data.sessionId;
  const isJointPostInvite = type === "joint_post_invite" && payload.data.postId;
  const isDeterministic = isSessionInvite || isJointPostInvite;
  const notificationRef = isSessionInvite
    ? notifications.doc(`session_invite_${payload.data.sessionId}`)
    : isJointPostInvite
      ? notifications.doc(`joint_post_invite_${payload.data.postId}`)
      : notifications.doc();

  const base = {
    userId: recipientId,
    type,
    title: payload.title,
    message: payload.body,
    data: payload.data,
    read: false,
  };

  if (isDeterministic) {
    // Deterministic id keyed on the session/post so a retried/re-sent invite
    // can't create duplicate invite docs — it refreshes the existing one in
    // place.
    await notificationRef.set(
      { ...base, createdAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
  } else {
    await notificationRef.set({
      ...base,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  return notificationRef.id;
}

async function buildSessionInvitePayload(callerId, recipientId, data) {
  const sessionId = requireString(data.sessionId, "data.sessionId");
  const sessionDoc = await db.collection("sessions").doc(sessionId).get();

  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }

  const session = sessionDoc.data() || {};
  const invitedUserIds = Array.isArray(session.invitedUserIds) ? session.invitedUserIds : [];
  if (session.hostId !== callerId || !invitedUserIds.includes(recipientId)) {
    throw new HttpsError("permission-denied", "Caller is not allowed to send this invite.");
  }

  const inviterName = await getUserDisplayName(callerId);
  const sessionType =
    typeof data.sessionType === "string" && data.sessionType.trim().length > 0
      ? data.sessionType.trim()
      : typeof session.type === "string"
        ? session.type
        : "strength";

  return {
    title: "Session Invite",
    body: `${inviterName} invited you to a ${sessionType} session!`,
    data: {
      type: "session_invite",
      sessionId,
      hostId: callerId,
      hostName: inviterName,
      byUserName: inviterName,
      sessionType,
      expiresAt:
        session.inviteExpiresAt && typeof session.inviteExpiresAt.toDate === "function"
          ? session.inviteExpiresAt.toDate().toISOString()
          : data.expiresAt,
      context: "one_to_one",
    },
  };
}

// Mirrors buildSessionInvitePayload's shape/validation for the joint-post
// "post it together?" invite: the caller (sharer) triggers this via
// NotificationService.sendJointPostInvite, and the CF re-validates the post
// server-side rather than trusting the client's fromName/postId pairing.
async function buildJointPostInvitePayload(callerId, recipientId, data) {
  const postId = requireString(data.postId, "data.postId");
  const sessionId = requireString(data.sessionId, "data.sessionId");
  const postDoc = await db.collection("posts").doc(postId).get();

  if (!postDoc.exists) {
    throw new HttpsError("not-found", "Post not found.");
  }

  const post = postDoc.data() || {};
  const authorIds = Object.values(post.authors || {}).map((author) => author.userId);
  if (
    post.coAuthored !== true ||
    post.status !== "draft" ||
    !authorIds.includes(callerId) ||
    !authorIds.includes(recipientId)
  ) {
    throw new HttpsError("permission-denied", "Caller is not allowed to send this invite.");
  }

  const inviterName = await getUserDisplayName(callerId);

  return {
    title: "Post It Together?",
    body: `${inviterName} wants to post your session together!`,
    data: {
      type: "joint_post_invite",
      postId,
      sessionId,
      fromName: inviterName,
      byUserName: inviterName,
    },
  };
}

async function buildTurnChangePayload(callerId, recipientId, data) {
  const sessionId = requireString(data.sessionId, "data.sessionId");
  const sessionDoc = await db.collection("sessions").doc(sessionId).get();

  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }

  const session = sessionDoc.data() || {};
  const participants = Array.isArray(session.participants) ? session.participants : [];
  if (!participants.includes(callerId) || !participants.includes(recipientId)) {
    throw new HttpsError("permission-denied", "Caller is not part of this session.");
  }
  if (session.activeUserId !== recipientId) {
    throw new HttpsError("failed-precondition", "Recipient is not the active session user.");
  }

  const sessionType =
    typeof data.sessionType === "string" && data.sessionType.trim().length > 0
      ? data.sessionType.trim()
      : typeof session.type === "string"
        ? session.type
        : "strength";

  return {
    title: "Your Turn!",
    body: `It's your turn to log a set in the ${sessionType} session`,
    data: {
      type: "turn_change",
      sessionId,
      sessionType,
      action: "open_session",
    },
  };
}

async function buildVoiceNotePayload(callerId, recipientId, data) {
  const sessionId = requireString(data.sessionId, "data.sessionId");
  const audioUrl = requireString(data.audioUrl, "data.audioUrl");
  const sessionDoc = await db.collection("sessions").doc(sessionId).get();

  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }

  const session = sessionDoc.data() || {};
  const participants = Array.isArray(session.participants) ? session.participants : [];
  if (!participants.includes(callerId) || !participants.includes(recipientId)) {
    throw new HttpsError("permission-denied", "Caller is not allowed to send this voice note.");
  }

  const senderName = await getUserDisplayName(callerId);
  return {
    title: "Voice Note",
    body: `${senderName} sent you a voice note`,
    data: {
      type: "voice_note",
      sessionId,
      audioUrl,
      autoPlay: true,
    },
  };
}

async function buildFollowRequestPayload(callerId, recipientId) {
  const followDoc = await db.collection("follows").doc(followDocId(callerId, recipientId)).get();

  if (!followDoc.exists || followDoc.data().status !== "pending") {
    throw new HttpsError("failed-precondition", "No pending follow request was found.");
  }

  const requesterName = await getUserDisplayName(callerId);
  return {
    title: "New Follow Request",
    body: `${requesterName} wants to follow you`,
    data: {
      type: "follow_request",
      fromUserId: callerId,
      byUserName: requesterName,
    },
  };
}

async function buildNewFollowerPayload(callerId, recipientId) {
  const followDoc = await db.collection("follows").doc(followDocId(callerId, recipientId)).get();

  if (!followDoc.exists || followDoc.data().status !== "approved") {
    throw new HttpsError("failed-precondition", "No approved follow was found.");
  }

  const followerName = await getUserDisplayName(callerId);
  return {
    title: "New Follower",
    body: `${followerName} started following you`,
    data: {
      type: "new_follower",
      fromUserId: callerId,
      byUserName: followerName,
    },
  };
}

async function buildFollowAcceptedPayload(callerId, recipientId) {
  const followDoc = await db.collection("follows").doc(followDocId(recipientId, callerId)).get();

  if (!followDoc.exists || followDoc.data().status !== "approved") {
    throw new HttpsError("failed-precondition", "No approved follow request was found.");
  }

  const acceptorName = await getUserDisplayName(callerId);
  return {
    title: "Follow Request Accepted",
    body: `${acceptorName} accepted your follow request`,
    data: {
      type: "follow_accepted",
      byUserId: callerId,
      byUserName: acceptorName,
    },
  };
}

async function buildPostLikePayload(callerId, recipientId, data) {
  const postId = requireString(data.postId, "data.postId");
  const postDoc = await db.collection("posts").doc(postId).get();

  if (!postDoc.exists || postDoc.data().authorId !== recipientId) {
    throw new HttpsError("permission-denied", "Caller cannot notify for this post reaction.");
  }

  const reactionDoc = await db
    .collection("posts")
    .doc(postId)
    .collection("reactions")
    .doc(callerId)
    .get();

  if (!reactionDoc.exists) {
    throw new HttpsError("failed-precondition", "Reaction document not found.");
  }

  const likerName = await getUserDisplayName(callerId);
  const reactionType =
    typeof reactionDoc.data().type === "string"
      ? reactionDoc.data().type
      : typeof data.reactionType === "string"
        ? data.reactionType
        : "fire";

  return {
    title: "New Reaction",
    body: `${likerName} reacted to your post`,
    data: {
      type: "post_like",
      postId,
      byUserId: callerId,
      reactionType,
    },
  };
}

async function buildPostCommentPayload(callerId, recipientId, data) {
  const postId = requireString(data.postId, "data.postId");
  const commentId = requireString(data.commentId, "data.commentId");
  const postDoc = await db.collection("posts").doc(postId).get();

  if (!postDoc.exists || postDoc.data().authorId !== recipientId) {
    throw new HttpsError("permission-denied", "Caller cannot notify for this post comment.");
  }

  const commentDoc = await db
    .collection("posts")
    .doc(postId)
    .collection("comments")
    .doc(commentId)
    .get();

  if (!commentDoc.exists || commentDoc.data().authorId !== callerId) {
    throw new HttpsError("failed-precondition", "Comment document not found.");
  }

  const commenterName =
    typeof commentDoc.data().authorName === "string" && commentDoc.data().authorName.trim().length > 0
      ? commentDoc.data().authorName.trim()
      : await getUserDisplayName(callerId);
  const commentText =
    typeof commentDoc.data().text === "string" ? commentDoc.data().text.trim() : "";
  const preview =
    commentText.length > 50 ? `${commentText.slice(0, 50)}...` : commentText;

  return {
    title: "New Comment",
    body: `${commenterName}: "${preview}"`,
    data: {
      type: "post_comment",
      postId,
      commentId,
      byUserId: callerId,
      byUserName: commenterName,
    },
  };
}

async function buildPushPayload(type, callerId, recipientId, data) {
  switch (type) {
    case "session_invite":
      return buildSessionInvitePayload(callerId, recipientId, data);
    case "joint_post_invite":
      return buildJointPostInvitePayload(callerId, recipientId, data);
    case "turn_change":
      return buildTurnChangePayload(callerId, recipientId, data);
    case "voice_note":
      return buildVoiceNotePayload(callerId, recipientId, data);
    case "new_follower":
      return buildNewFollowerPayload(callerId, recipientId);
    case "follow_request":
      return buildFollowRequestPayload(callerId, recipientId);
    case "follow_accepted":
      return buildFollowAcceptedPayload(callerId, recipientId);
    case "post_like":
      return buildPostLikePayload(callerId, recipientId, data);
    case "post_comment":
      return buildPostCommentPayload(callerId, recipientId, data);
    default:
      throw new HttpsError("failed-precondition", `Push delivery is not supported for ${type}.`);
  }
}

function getStatusCode(error) {
  switch (error.code) {
    case "unauthenticated":
      return 401;
    case "permission-denied":
      return 403;
    case "not-found":
      return 404;
    case "invalid-argument":
      return 400;
    case "failed-precondition":
      return 412;
    default:
      return 500;
  }
}

async function requireHttpAuth(req) {
  const header = req.get("Authorization") || "";
  if (!header.startsWith("Bearer ")) {
    throw new HttpsError("unauthenticated", "Missing bearer token.");
  }

  try {
    const decodedToken = await auth.verifyIdToken(header.slice("Bearer ".length));
    return decodedToken.uid;
  } catch (error) {
    logger.warn("Invalid bearer token for deliverNotificationPush.", error);
    throw new HttpsError("unauthenticated", "Invalid bearer token.");
  }
}

async function requireHttpAppCheck(req) {
  const token = req.get("X-Firebase-AppCheck") || "";
  if (!token) {
    throw new HttpsError("unauthenticated", "Missing App Check token.");
  }

  try {
    await appCheck.verifyToken(token);
  } catch (error) {
    logger.warn("Invalid App Check token for deliverNotificationPush.", error);
    throw new HttpsError("unauthenticated", "Invalid App Check token.");
  }
}

function getPayloadData(body) {
  if (body && typeof body.data === "object" && body.data !== null) {
    return body.data;
  }
  return {};
}

exports.deliverNotificationPush = onRequest({ invoker: "public" }, async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === "OPTIONS") {
    if (req.get("Origin") && !res.get("Access-Control-Allow-Origin")) {
      res.status(403).send("");
    } else {
      res.status(204).send("");
    }
    return;
  }

  if (req.get("Origin") && !res.get("Access-Control-Allow-Origin")) {
    res.status(403).json({ error: "Origin not allowed." });
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed." });
    return;
  }

  try {
    await requireHttpAppCheck(req);
    const callerId = await requireHttpAuth(req);
    const type = requireString(req.body && req.body.type, "type");
    const recipientId = requireString(req.body && req.body.recipientId, "recipientId");
    const payloadData = getPayloadData(req.body);

    const payload = await buildPushPayload(type, callerId, recipientId, payloadData);
    // The Cloud Function is the single authoritative writer for all cross-user
    // notifications — clients can only write their own (owner-only rule), so the
    // in-app doc is persisted here with server-validated content. session_invite
    // uses a deterministic id; all other types get a fresh doc.
    const notificationId = await persistRecipientNotification(
      recipientId,
      type,
      payload,
    );

    // The durable in-app doc is always written above; the FCM push, however,
    // respects the recipient's notification preferences (and global pushEnabled).
    const result = await pushToRecipientDevices(recipientId, type, payload);

    if (result.skipped) {
      res.status(200).json({
        notificationId,
        delivered: 0,
        skipped: true,
      });
      return;
    }

    logger.info("Delivered push notification.", {
      callerId,
      recipientId,
      type,
      delivered: result.delivered,
      failed: result.failed,
    });

    res.status(200).json({
      notificationId,
      delivered: result.delivered,
      failed: result.failed,
    });
  } catch (error) {
    if (error instanceof HttpsError) {
      res.status(getStatusCode(error)).json({
        code: error.code,
        error: error.message,
      });
      return;
    }

    logger.error("deliverNotificationPush failed.", error);
    res.status(500).json({ error: "Internal error." });
  }
});

// Sweeps stale paired-session invites. Without this, an invite the recipient
// never opens leaves the host's session stuck on invitationStatus 'pending'
// forever (acceptInvite only enforces expiry lazily, on open). Runs every
// 15 minutes and flips expired pending invites to 'expired'.
// NOTE: requires a composite index on sessions(invitationStatus ASC,
// inviteExpiresAt ASC).
exports.expireStalePairedInvites = onSchedule("every 15 minutes", async () => {
  const now = Timestamp.now();
  const snapshot = await db
    .collection("sessions")
    .where("invitationStatus", "==", "pending")
    .where("inviteExpiresAt", "<", now)
    .limit(400)
    .get();

  if (snapshot.empty) {
    return;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    // `ref`, not `reference` — the latter is the Dart/Flutter property and is
    // undefined in the Node SDK, which made this pass undefined to
    // batch.update and throw on every scheduled run.
    batch.update(doc.ref, { invitationStatus: "expired" });
  });
  await batch.commit();

  logger.info("Expired stale paired-session invites.", {
    count: snapshot.size,
  });
});

// ==================== JOINT (CO-AUTHORED) POST LIFECYCLE ====================
// Security rules freeze `status`/`authors.*.confirmed` transitions for
// clients on joint posts (see firestore.rules `isOwnAuthorSlotUpdate`) — the
// Cloud Function is the only writer that can flip a joint draft to
// published/expired or delete it, using admin privileges to bypass rules.

// Publishes a joint post once every active (non-removed) author slot has
// confirmed. Guarded on `status === 'draft'` so it only fires once per post —
// subsequent author-slot edits after publish are no-ops here.
exports.publishJointPostWhenBothConfirm = onDocumentUpdated("posts/{postId}", async (event) => {
  const after = event.data.after.data();
  if (!after || after.coAuthored !== true || after.status !== "draft") {
    return;
  }

  const authors = Object.values(after.authors || {});
  const active = authors.filter((author) => !author.removed);
  if (active.length < 2 || !active.every((author) => author.confirmed === true)) {
    return;
  }

  const anyPrivate = active.some((author) => author.visibility === "private");
  await event.data.after.ref.update({
    status: "published",
    visibility: anyPrivate ? "private" : "public",
    createdAt: FieldValue.serverTimestamp(),
  });

  logger.info("Published joint post on dual confirm.", { postId: event.params.postId });
});

// Writes the owner-scoped "post it solo?" notification for an author whose
// joint post draft expired before their co-author confirmed, and pushes it to
// their devices. Shaped like persistRecipientNotification's docs
// (title/message/data) so it renders via the same client notification model;
// `data` carries the ids the recap/solo-share screen needs to deep-link. The
// doc id is deterministic per (recipient, post) so a re-run of the scheduler
// (e.g. after a partial failure) can't create duplicate offers.
//
// This offer is server-initiated (there is no client caller and therefore no
// trip through deliverNotificationPush), so it must call the shared push path
// itself — otherwise it would only ever appear in the in-app notifications tab
// and the author would never learn the draft expired.
async function sendSoloRepostOffer(userId, postId, sessionId) {
  const payload = {
    title: "Joint Post Expired",
    body: "Your co-author didn't confirm in time. Want to post it solo instead?",
    data: {
      type: "joint_post_expired",
      postId,
      sessionId,
    },
  };

  const notificationRef = db
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .doc(`joint_post_expired_${postId}`);

  await notificationRef.set(
    {
      userId,
      type: "joint_post_expired",
      title: payload.title,
      message: payload.body,
      data: payload.data,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  // A push failure (bad token, FCM outage) must not abort the sweep or lose
  // the durable doc that was just written.
  try {
    await pushToRecipientDevices(userId, "joint_post_expired", payload);
  } catch (error) {
    logger.warn("Failed to push solo repost offer.", { userId, postId, error });
  }
}

// Sweeps joint post drafts whose confirmation window has passed. Flips them
// to 'expired' and offers each author who had already confirmed a chance to
// re-post solo (sendSoloRepostOffer writes the in-app doc AND pushes it).
// NOTE: requires a composite index on posts(coAuthored ASC, status ASC,
// expiresAt ASC).
exports.expireStaleJointPostDrafts = onSchedule("every 15 minutes", async () => {
  const now = Timestamp.now();
  const snapshot = await db
    .collection("posts")
    .where("coAuthored", "==", true)
    .where("status", "==", "draft")
    .where("expiresAt", "<", now)
    .limit(400)
    .get();

  if (snapshot.empty) {
    return;
  }

  // The status flips go in one batch, and the notifications fan out in
  // parallel. Doing both serially meant up to 400 sequential round trips plus
  // one per confirmed author in a single invocation, which risks the function
  // timeout and pushes expiry past the 15-minute schedule. The sibling
  // expireStalePairedInvites already batches its writes this way.
  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.update(doc.ref, { status: "expired" }));
  await batch.commit();

  const offers = snapshot.docs.flatMap((doc) => {
    const data = doc.data();
    return Object.values(data.authors || {})
      .filter((author) => author.confirmed === true && !author.removed)
      .map((author) => sendSoloRepostOffer(author.userId, doc.id, data.sessionId));
  });

  // allSettled, not all: one user's push failing must not abandon the rest.
  // The status flips are already committed, so a lost notification does not
  // leave a draft stuck in `draft` forever.
  const results = await Promise.allSettled(offers);
  const failed = results.filter((r) => r.status === "rejected");
  if (failed.length > 0) {
    logger.error("Some solo-repost offers failed to send.", {
      failed: failed.length,
      total: offers.length,
      firstReason: String(failed[0].reason),
    });
  }

  logger.info("Expired stale joint post drafts.", {
    count: snapshot.size,
    offersSent: offers.length - failed.length,
  });
});

// Deletes a joint post once every author slot has soft-left (removed). A
// joint post with no remaining authors has nothing left to show, so it's
// cleaned up rather than left as an orphaned doc.
exports.cleanupFullyRemovedJointPosts = onDocumentUpdated("posts/{postId}", async (event) => {
  const after = event.data.after.data();
  if (!after || after.coAuthored !== true) {
    return;
  }

  const authors = Object.values(after.authors || {});
  if (authors.length === 0 || !authors.every((author) => author.removed === true)) {
    return;
  }

  await event.data.after.ref.delete();
  logger.info("Deleted fully-removed joint post.", { postId: event.params.postId });
});
