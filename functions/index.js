const { initializeApp } = require("firebase-admin/app");
const { getAppCheck } = require("firebase-admin/app-check");
const { getAuth } = require("firebase-admin/auth");
const { FieldValue, getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");
const logger = require("firebase-functions/logger");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onUserDeleted } = require("firebase-functions/v2/identity");
const { onSchedule } = require("firebase-functions/v2/scheduler");

initializeApp();

const appCheck = getAppCheck();
const auth = getAuth();
const db = getFirestore();
const messaging = getMessaging();
const storage = getStorage();

const INVALID_TOKEN_ERRORS = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

// Ops heartbeat for scheduled jobs (Z-OBS-002). Writes even when the job
// finds nothing to do, so a missing/stale heartbeat means the schedule is
// unhealthy rather than "quietly idle".
async function writeScheduleHeartbeat(jobName, extra = {}) {
  await db.collection("ops").doc("heartbeats").collection("jobs").doc(jobName).set({
    jobName,
    lastRunAt: FieldValue.serverTimestamp(),
    ...extra,
  }, { merge: true });
}

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

async function isBlockedPair(a, b) {
  if (!a || !b || a === b) {
    return false;
  }
  const [ab, ba] = await Promise.all([
    db.collection("blocks").doc(`${a}_${b}`).get(),
    db.collection("blocks").doc(`${b}_${a}`).get(),
  ]);
  return ab.exists || ba.exists;
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

/** Recipient UI language for push copy (Z-I18N-003). Defaults to English. */
async function getUserLocale(userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const raw =
      userDoc.exists && typeof userDoc.data()?.locale === "string"
        ? userDoc.data().locale.trim().toLowerCase()
        : "en";
    return raw.startsWith("ar") ? "ar" : "en";
  } catch (_) {
    return "en";
  }
}

function pushCopy(locale, en, ar) {
  return locale === "ar" ? ar : en;
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
    case "buddy_invite":
    case "buddy_accepted":
    case "buddy_session":
      return enabled("buddyInvites");
    case "session_milestone":
      return enabled("sessionMilestones");
    case "streak_milestone":
    case "friend_streak_broken":
    case "friend_streak_extended":
      return enabled("streakNotifications");
    case "joint_post_invite":
    case "joint_post_expired":
    case "partner_left":
      return true;
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
  // One departure, one notification. Keyed on (session, leaver) so a retry, or
  // a partner who terminates while the recipient reopens the app repeatedly,
  // refreshes the same doc instead of stacking duplicates for one event.
  const isPartnerLeft =
    type === "partner_left" && payload.data.sessionId && payload.data.leaverId;
  const isDeterministic = isSessionInvite || isJointPostInvite || isPartnerLeft;
  const notificationRef = isSessionInvite
    ? notifications.doc(`session_invite_${payload.data.sessionId}`)
    : isJointPostInvite
      ? notifications.doc(`joint_post_invite_${payload.data.postId}`)
      : isPartnerLeft
        ? notifications.doc(
          `partner_left_${payload.data.sessionId}_${payload.data.leaverId}`,
        )
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
  const locale = await getUserLocale(recipientId);
  const sessionType =
    typeof data.sessionType === "string" && data.sessionType.trim().length > 0
      ? data.sessionType.trim()
      : typeof session.type === "string"
        ? session.type
        : "strength";

  return {
    title: pushCopy(locale, "Session Invite", "دعوة جلسة"),
    body: pushCopy(
      locale,
      `${inviterName} invited you to a ${sessionType} session!`,
      `${inviterName} دعاك إلى جلسة ${sessionType}!`,
    ),
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
  const locale = await getUserLocale(recipientId);

  return {
    title: pushCopy(locale, "Post It Together?", "منشور مشترك؟"),
    body: pushCopy(
      locale,
      `${inviterName} wants to post your session together!`,
      `${inviterName} يريد نشر جلستكما معاً!`,
    ),
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

  const locale = await getUserLocale(recipientId);

  return {
    title: pushCopy(locale, "Your Turn!", "دورك!"),
    body: pushCopy(
      locale,
      `It's your turn to log a set in the ${sessionType} session`,
      `حان دورك لتسجيل مجموعة في جلسة ${sessionType}`,
    ),
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
  const locale = await getUserLocale(recipientId);
  return {
    title: pushCopy(locale, "Voice Note", "رسالة صوتية"),
    body: pushCopy(
      locale,
      `${senderName} sent you a voice note`,
      `${senderName} أرسل لك رسالة صوتية`,
    ),
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
  const locale = await getUserLocale(recipientId);
  return {
    title: pushCopy(locale, "New Follow Request", "طلب متابعة جديد"),
    body: pushCopy(
      locale,
      `${requesterName} wants to follow you`,
      `${requesterName} يريد متابعتك`,
    ),
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
  const locale = await getUserLocale(recipientId);
  return {
    title: pushCopy(locale, "New Follower", "متابع جديد"),
    body: pushCopy(
      locale,
      `${followerName} started following you`,
      `${followerName} بدأ بمتابعتك`,
    ),
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
  const locale = await getUserLocale(recipientId);
  return {
    title: pushCopy(locale, "Follow Request Accepted", "تم قبول طلب المتابعة"),
    body: pushCopy(
      locale,
      `${acceptorName} accepted your follow request`,
      `${acceptorName} قبل طلب متابعتك`,
    ),
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

  const locale = await getUserLocale(recipientId);
  return {
    title: pushCopy(locale, "New Reaction", "تفاعل جديد"),
    body: pushCopy(
      locale,
      `${likerName} reacted to your post`,
      `${likerName} تفاعل مع منشورك`,
    ),
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

  const locale = await getUserLocale(recipientId);
  return {
    title: pushCopy(locale, "New Comment", "تعليق جديد"),
    body: pushCopy(
      locale,
      `${commenterName} commented on your post`,
      `${commenterName} علّق على منشورك`,
    ),
    data: {
      type: "post_comment",
      postId,
      commentId,
      byUserId: callerId,
      byUserName: commenterName,
    },
  };
}

async function buildPartnerLeftPayload(callerId, recipientId, data) {
  const sessionId = requireString(data.sessionId, "data.sessionId");
  const leaverId = requireString(data.leaverId, "data.leaverId");
  if (leaverId !== callerId) {
    throw new HttpsError("permission-denied", "Caller is not the leaver.");
  }

  const sessionDoc = await db.collection("sessions").doc(sessionId).get();
  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }

  const session = sessionDoc.data() || {};
  const participants = Array.isArray(session.participants) ? session.participants : [];
  const ended = Array.isArray(session.endedParticipants) ? session.endedParticipants : [];
  if (!participants.includes(callerId) || !participants.includes(recipientId)) {
    throw new HttpsError("permission-denied", "Caller is not part of this session.");
  }
  if (!ended.includes(callerId)) {
    throw new HttpsError("failed-precondition", "Caller has not left this session.");
  }

  const leaverName = await getUserDisplayName(callerId);
  const locale = await getUserLocale(recipientId);
  return {
    title: pushCopy(locale, `${leaverName} left`, `${leaverName} غادر`),
    body: pushCopy(
      locale,
      `${leaverName} left the session. Finish or carry on.`,
      `${leaverName} غادر الجلسة. أنهِ أو واصل.`,
    ),
    data: {
      type: "partner_left",
      sessionId,
      leaverId,
      action: "open_session",
    },
  };
}

async function buildBuddyInvitePayload(callerId, recipientId, data) {
  const buddyPairId = requireString(data.buddyPairId, "data.buddyPairId");
  const pairDoc = await db.collection("buddyPairs").doc(buddyPairId).get();
  if (!pairDoc.exists) {
    throw new HttpsError("not-found", "Buddy pair not found.");
  }
  const pair = pairDoc.data() || {};
  const participants = Array.isArray(pair.participants) ? pair.participants : [];
  if (pair.initiatorId !== callerId || !participants.includes(callerId)) {
    throw new HttpsError("permission-denied", "Caller is not allowed to send this buddy invite.");
  }
  const inviterName = await getUserDisplayName(callerId);
  const locale = await getUserLocale(recipientId);
  return {
    title: pushCopy(locale, "Buddy Invite", "دعوة صديق تمارين"),
    body: pushCopy(
      locale,
      `${inviterName} wants to be your workout buddy!`,
      `${inviterName} يريد أن يكون رفيق تمارينك!`,
    ),
    data: {
      type: "buddy_invite",
      buddyPairId,
      fromUserId: callerId,
      byUserName: inviterName,
    },
  };
}

async function buildBuddyAcceptedPayload(callerId, recipientId, data) {
  const buddyPairId = requireString(data.buddyPairId, "data.buddyPairId");
  const pairDoc = await db.collection("buddyPairs").doc(buddyPairId).get();
  if (!pairDoc.exists) {
    throw new HttpsError("not-found", "Buddy pair not found.");
  }
  const pair = pairDoc.data() || {};
  const participants = Array.isArray(pair.participants) ? pair.participants : [];
  if (!participants.includes(callerId) || !participants.includes(recipientId)) {
    throw new HttpsError("permission-denied", "Caller is not allowed to send this buddy update.");
  }
  const acceptorName = await getUserDisplayName(callerId);
  const locale = await getUserLocale(recipientId);
  return {
    title: pushCopy(locale, "Buddy Accepted", "تم قبول دعوة الصديق"),
    body: pushCopy(
      locale,
      `${acceptorName} accepted your buddy invite!`,
      `${acceptorName} قبل دعوة رفيق التمارين!`,
    ),
    data: {
      type: "buddy_accepted",
      buddyPairId,
      fromUserId: callerId,
      byUserName: acceptorName,
    },
  };
}

async function buildBuddySessionPayload(callerId, recipientId, data) {
  const sessionId = requireString(data.sessionId, "data.sessionId");
  const sessionDoc = await db.collection("sessions").doc(sessionId).get();
  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }
  const session = sessionDoc.data() || {};
  const participants = Array.isArray(session.participants) ? session.participants : [];
  if (!participants.includes(callerId)) {
    throw new HttpsError("permission-denied", "Caller is not a session participant.");
  }
  const hostName = await getUserDisplayName(callerId);
  const locale = await getUserLocale(recipientId);
  return {
    title: pushCopy(locale, "Buddy Session", "جلسة رفيق"),
    body: pushCopy(
      locale,
      `${hostName} started a buddy workout — jump in!`,
      `${hostName} بدأ تمرين رفيق — انضم الآن!`,
    ),
    data: {
      type: "buddy_session",
      sessionId,
      fromUserId: callerId,
      byUserName: hostName,
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
    case "partner_left":
      return buildPartnerLeftPayload(callerId, recipientId, data);
    case "buddy_invite":
      return buildBuddyInvitePayload(callerId, recipientId, data);
    case "buddy_accepted":
      return buildBuddyAcceptedPayload(callerId, recipientId, data);
    case "buddy_session":
      return buildBuddySessionPayload(callerId, recipientId, data);
    default:
      throw new HttpsError("failed-precondition", `Push delivery is not supported for ${type}.`);
  }
}

function getStatusCode(error) {
  switch (error.code) {
    case "resource-exhausted":
      return 429;
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
    // Consume limited-use tokens so a captured token cannot be replayed
    // against deliverNotificationPush / applySessionScore (Z-FN-002).
    await appCheck.verifyToken(token, { consume: true });
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

// Z-FN-001: authenticated callers can otherwise spam FCM cost and inboxes.
const PUSH_RATE_LIMIT_MAX = 30;
const PUSH_RATE_LIMIT_WINDOW_MS = 60 * 1000;
const PUSH_DEDUP_WINDOW_MS = 15 * 1000;

async function enforcePushRateLimit(callerId) {
  const ref = db.collection("rateLimits").doc(`push_${callerId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    let windowStartMs = now;
    let count = 0;
    if (snap.exists) {
      const data = snap.data() || {};
      windowStartMs = typeof data.windowStartMs === "number" ? data.windowStartMs : now;
      count = typeof data.count === "number" ? data.count : 0;
      if (now - windowStartMs > PUSH_RATE_LIMIT_WINDOW_MS) {
        windowStartMs = now;
        count = 0;
      }
    }
    if (count >= PUSH_RATE_LIMIT_MAX) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many notification requests. Try again shortly.",
      );
    }
    tx.set(
      ref,
      {
        windowStartMs,
        count: count + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

async function enforcePushDedup(callerId, type, recipientId, payloadData) {
  const sessionPart =
    payloadData && typeof payloadData.sessionId === "string"
      ? payloadData.sessionId
      : "";
  const key = `${callerId}_${type}_${recipientId}_${sessionPart}`;
  // Keep doc ids short / safe for Firestore.
  const docId = `dedup_${Buffer.from(key).toString("base64url").slice(0, 100)}`;
  const ref = db.collection("rateLimits").doc(docId);
  const now = Date.now();
  const snap = await ref.get();
  if (snap.exists) {
    const lastAt = snap.data()?.lastAtMs;
    if (typeof lastAt === "number" && now - lastAt < PUSH_DEDUP_WINDOW_MS) {
      throw new HttpsError(
        "resource-exhausted",
        "Duplicate notification suppressed.",
      );
    }
  }
  await ref.set(
    {
      lastAtMs: now,
      key,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
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
    await enforcePushRateLimit(callerId);
    const type = requireString(req.body && req.body.type, "type");
    const recipientId = requireString(req.body && req.body.recipientId, "recipientId");
    const payloadData = getPayloadData(req.body);
    await enforcePushDedup(callerId, type, recipientId, payloadData);

    if (await isBlockedPair(callerId, recipientId)) {
      logger.info("Skipping push for blocked pair.", { callerId, recipientId, type });
      res.status(200).json({
        delivered: 0,
        skipped: true,
        blocked: true,
      });
      return;
    }

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

  if (!snapshot.empty) {
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
  }

  await writeScheduleHeartbeat("expireStalePairedInvites", {
    processed: snapshot.size,
  });
});

// A live session must not outlive the workout it represents. The app can no
// longer close sessions on its own: terminating on app-close was removed
// because it destroyed the very session the member wanted to come back to, and
// `AppLifecycleState.detached` is not delivered reliably on a force-quit or an
// OS kill anyway. So expiry has to happen server-side, with no client running.
//
// `expiresAt` is written by the client as max(lastActivityAt, lastOccupiedAt)
// + 3h. It is stored rather than derived here because Firestore permits only
// one range filter per query — the two conditions in the spec (3h without
// activity, 3h with an empty room) cannot both be expressed otherwise.
//
// Guarded on `status === 'active'`, so a re-run cannot double-expire a session.
// Recorded work is untouched: this closes the session document only.
exports.expireStaleSessions = onSchedule("every 15 minutes", async () => {
  const now = Timestamp.now();
  const snapshot = await db
    .collection("sessions")
    .where("status", "==", "active")
    .where("expiresAt", "<", now)
    .limit(200)
    .get();

  if (!snapshot.empty) {
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      // `ref`, not `reference` — the latter is the Dart/Flutter property and is
      // undefined in the Node SDK. It broke expireStalePairedInvites once.
      batch.update(doc.ref, {
        status: "completed",
        endedReason: "expired",
        endedAt: FieldValue.serverTimestamp(),
      });
      // Abandonment counter for SC-014: a session nobody came back to, as
      // distinct from one somebody deliberately finished.
      batch.set(db.collection("analytics").doc(), {
        type: "session_expired_abandoned",
        sessionId: doc.id,
        timestamp: FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();

    // Z-DATA-004: drop ephemeral presence (and empty-room plans) so expiry
    // does not leave live-listener docs billing forever. Timeline events stay
    // for any later workout/history reconstruction.
    await Promise.allSettled(
      snapshot.docs.map(async (doc) => {
        await deleteByQuery(doc.ref.collection("presence"));
        await deleteByQuery(doc.ref.collection("plans"));
      }),
    );

    logger.info("Expired stale sessions.", { count: snapshot.size });
  }

  await writeScheduleHeartbeat("expireStaleSessions", {
    processed: snapshot.size,
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
  const locale = await getUserLocale(userId);
  const payload = {
    title: pushCopy(locale, "Joint Post Expired", "انتهت صلاحية المنشور المشترك"),
    body: pushCopy(
      locale,
      "Your co-author didn't confirm in time. Want to post it solo instead?",
      "لم يؤكد شريكك في الوقت. هل تريد نشره بمفردك؟",
    ),
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
    await writeScheduleHeartbeat("expireStaleJointPostDrafts", {
      processed: 0,
    });
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

  await writeScheduleHeartbeat("expireStaleJointPostDrafts", {
    processed: snapshot.size,
  });
});

// Deletes a joint post once every author slot has soft-left (removed). A
// joint post with no remaining authors has nothing left to show, so it's
// cleaned up rather than left as an orphaned doc — including Storage media
// under posts/{postId}/ (Z-FN-005).
exports.cleanupFullyRemovedJointPosts = onDocumentUpdated("posts/{postId}", async (event) => {
  const after = event.data.after.data();
  if (!after || after.coAuthored !== true) {
    return;
  }

  const authors = Object.values(after.authors || {});
  if (authors.length === 0 || !authors.every((author) => author.removed === true)) {
    return;
  }

  const postId = event.params.postId;
  const postRef = event.data.after.ref;
  await deleteByQuery(postRef.collection("comments"));
  await deleteByQuery(postRef.collection("reactions"));
  await deleteStoragePrefix(`posts/${postId}/`);
  await postRef.delete();
  logger.info("Deleted fully-removed joint post.", { postId });
});

async function deleteByQuery(query) {
  let total = 0;
  for (;;) {
    const snapshot = await query.limit(200).get();
    if (snapshot.empty) {
      return total;
    }
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    total += snapshot.size;
    if (snapshot.size < 200) {
      return total;
    }
  }
}

async function deleteUserSubcollection(uid, name) {
  await deleteByQuery(db.collection("users").doc(uid).collection(name));
}

async function deletePostsByAuthor(uid) {
  for (;;) {
    const snapshot = await db.collection("posts").where("authorId", "==", uid).limit(50).get();
    if (snapshot.empty) {
      break;
    }
    for (const post of snapshot.docs) {
      await deleteByQuery(post.ref.collection("comments"));
      await deleteByQuery(post.ref.collection("reactions"));
      await deleteStoragePrefix(`posts/${post.id}/`);
      await post.ref.delete();
    }
    if (snapshot.size < 50) {
      break;
    }
  }

  // Joint / co-authored drafts where this uid is listed (Z-FN-003).
  for (;;) {
    const snapshot = await db
      .collection("posts")
      .where("authorIds", "array-contains", uid)
      .limit(50)
      .get();
    if (snapshot.empty) {
      return;
    }
    for (const post of snapshot.docs) {
      const data = post.data() || {};
      const authorIds = Array.isArray(data.authorIds)
        ? data.authorIds.filter((id) => id !== uid)
        : [];
      if (authorIds.length === 0) {
        await deleteByQuery(post.ref.collection("comments"));
        await deleteByQuery(post.ref.collection("reactions"));
        await deleteStoragePrefix(`posts/${post.id}/`);
        await post.ref.delete();
        continue;
      }
      const authors = { ...(data.authors || {}) };
      delete authors[uid];
      await post.ref.update({
        authorIds,
        authors,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    if (snapshot.size < 50) {
      return;
    }
  }
}

async function deleteStoragePrefix(prefix) {
  try {
    await storage.bucket().deleteFiles({ prefix });
    logger.info("Deleted storage prefix.", { prefix });
  } catch (error) {
    logger.warn("Storage prefix delete skipped.", { prefix, error: String(error) });
  }
}

async function detachUserFromSessions(uid) {
  for (;;) {
    const snapshot = await db
      .collection("sessions")
      .where("participants", "array-contains", uid)
      .limit(50)
      .get();
    if (snapshot.empty) {
      break;
    }
    for (const doc of snapshot.docs) {
      const data = doc.data() || {};
      const participants = (data.participants || []).filter((id) => id !== uid);
      if (participants.length === 0 || data.hostId === uid) {
        await deleteByQuery(doc.ref.collection("events"));
        await deleteByQuery(doc.ref.collection("plans"));
        await deleteByQuery(doc.ref.collection("presence"));
        await doc.ref.delete();
      } else {
        const ended = Array.isArray(data.endedParticipants)
          ? data.endedParticipants.filter((id) => id !== uid)
          : [];
        const participantTypes = { ...(data.participantTypes || {}) };
        delete participantTypes[uid];
        await doc.ref.update({
          participants,
          endedParticipants: ended,
          participantTypes,
          lastActivityAt: FieldValue.serverTimestamp(),
        });
        try {
          await doc.ref.collection("plans").doc(uid).delete();
          await doc.ref.collection("presence").doc(uid).delete();
        } catch (_) {
          // Subdocs may already be gone.
        }
      }
    }
    if (snapshot.size < 50) {
      break;
    }
  }
}

exports.cleanupDeletedUser = onUserDeleted(async (event) => {
  const uid = event.data.uid;
  logger.info("Cleaning up deleted user.", { uid });

  for (const name of [
    "devices",
    "notifications",
    "settings",
    "stats",
    "personalExercises",
    "joinedEvents",
  ]) {
    await deleteUserSubcollection(uid, name);
  }

  await deleteByQuery(db.collection("usernames").where("uid", "==", uid));
  await deleteByQuery(db.collection("follows").where("followerId", "==", uid));
  await deleteByQuery(db.collection("follows").where("followeeId", "==", uid));
  await deleteByQuery(db.collection("blocks").where("blockerId", "==", uid));
  await deleteByQuery(db.collection("blocks").where("blockedId", "==", uid));
  await deleteByQuery(db.collection("matchmaking_queue").where("userId", "==", uid));
  await deleteByQuery(db.collection("workouts").where("userId", "==", uid));
  await detachUserFromSessions(uid);
  await deletePostsByAuthor(uid);
  await deleteStoragePrefix(`profilePhotos/${uid}/`);

  try {
    await db.collection("users").doc(uid).delete();
  } catch (e) {
    logger.warn("User profile delete skipped.", { uid, error: String(e) });
  }

  logger.info("Deleted-user cleanup finished.", { uid });
});

/**
 * Z-DATA-001 phase 1 stub — server-authoritative score/streak grant.
 * Clients no longer write workoutScore / streaks / stats/prs. Phase 2 will
 * port computeWorkoutScore + advanceStreak here (or on session complete) and
 * use Admin SDK to update users/{uid}. Until then this endpoint refuses work.
 */
exports.applySessionScore = onRequest({ invoker: "public" }, async (req, res) => {
  setCorsHeaders(req, res);
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
    await requireHttpAuth(req);
  } catch (e) {
    const code = e instanceof HttpsError ? e.code : "unauthenticated";
    const status = code === "unauthenticated" || code === "permission-denied" ? 401 : 400;
    res.status(status).json({ error: e.message || String(e) });
    return;
  }
  logger.info("applySessionScore stub invoked — not implemented yet.", {
    sessionId: req.body && req.body.sessionId,
  });
  res.status(501).json({
    error: "applySessionScore not implemented",
    hint: "Scores are frozen client-side until server grant ships (Z-DATA-001).",
  });
});
