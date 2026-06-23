const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const INVALID_TOKEN_ERRORS = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

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

async function persistRecipientNotification(recipientId, type, payload) {
  const notifications = db
    .collection("users")
    .doc(recipientId)
    .collection("notifications");
  const isDeterministic = type === "session_invite" && payload.data.sessionId;
  const notificationRef = isDeterministic
    ? notifications.doc(`session_invite_${payload.data.sessionId}`)
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
    // The client writes this same doc first (with extras like groupSize) so the
    // in-app listener fires instantly. Merge — rather than overwrite — so we
    // don't drop those extras or reset the client's original createdAt.
    await notificationRef.set(base, { merge: true });
  } else {
    await notificationRef.set({
      ...base,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    const decodedToken = await admin.auth().verifyIdToken(header.slice("Bearer ".length));
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
    await admin.appCheck().verifyToken(token);
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
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Firebase-AppCheck");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
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
    // The client (createNotification / notifySessionInvite) already writes the
    // canonical in-app doc before calling this endpoint, so persisting here too
    // produced duplicate notifications. Only session_invite is persisted — as a
    // deterministic merge that reconciles server-authoritative fields (e.g. the
    // session's real expiresAt) onto the client's doc. All other types are
    // push-only here.
    const notificationId =
      type === "session_invite"
        ? await persistRecipientNotification(recipientId, type, payload)
        : null;
    const devices = await getRecipientDevices(recipientId);

    if (devices.length === 0) {
      logger.info("No device tokens found for recipient.", { recipientId, type });
      res.status(200).json({
        notificationId,
        delivered: 0,
        skipped: true,
      });
      return;
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

    logger.info("Delivered push notification.", {
      callerId,
      recipientId,
      type,
      delivered: response.successCount,
      failed: response.failureCount,
    });

    res.status(200).json({
      notificationId,
      delivered: response.successCount,
      failed: response.failureCount,
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
  const now = admin.firestore.Timestamp.now();
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
    batch.update(doc.reference, { invitationStatus: "expired" });
  });
  await batch.commit();

  logger.info("Expired stale paired-session invites.", {
    count: snapshot.size,
  });
});
