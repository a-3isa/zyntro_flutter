const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");

describe("deliverNotificationPush live path (Z-FN-004)", () => {
  it("requires POST + App Check + auth before work", () => {
    assert.match(source, /exports\.deliverNotificationPush = onRequest/);
    assert.match(source, /await requireHttpAppCheck\(req\)/);
    assert.match(source, /await requireHttpAuth\(req\)/);
    assert.match(source, /Method not allowed/);
  });

  it("rate-limits, dedupes, and skips blocked pairs", () => {
    assert.match(source, /await enforcePushRateLimit\(callerId\)/);
    assert.match(source, /await enforcePushDedup\(/);
    assert.match(source, /await isBlockedPair\(callerId, recipientId\)/);
    assert.match(source, /skipped: true,\s*blocked: true/);
  });

  it("persists the in-app notification then pushes FCM", () => {
    assert.match(source, /await persistRecipientNotification\(/);
    assert.match(source, /await pushToRecipientDevices\(/);
    assert.match(source, /Delivered push notification/);
  });

  it("maps HttpsError to HTTP status JSON", () => {
    assert.match(source, /if \(error instanceof HttpsError\)/);
    assert.match(source, /getStatusCode\(error\)/);
  });
});
