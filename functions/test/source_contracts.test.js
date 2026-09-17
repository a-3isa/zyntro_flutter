const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");

describe("Cloud Functions source contracts", () => {
  it("rate-limits and dedupes notification pushes (Z-FN-001)", () => {
    assert.match(source, /PUSH_RATE_LIMIT_MAX\s*=\s*30/);
    assert.match(source, /PUSH_DEDUP_WINDOW_MS\s*=\s*15\s*\*\s*1000/);
    assert.match(source, /enforcePushRateLimit/);
    assert.match(source, /enforcePushDedup/);
  });

  it("consumes App Check limited-use tokens (Z-FN-002)", () => {
    assert.match(source, /verifyToken\(token,\s*\{\s*consume:\s*true\s*\}\)/);
  });

  it("expands account deletion cleanup (Z-FN-003)", () => {
    assert.match(source, /detachUserFromSessions/);
    assert.match(source, /deleteStoragePrefix/);
    assert.match(source, /workouts"\)\.where\("userId"/);
  });

  it("writes schedule heartbeats for ops liveness (Z-OBS-002)", () => {
    assert.match(source, /function writeScheduleHeartbeat/);
    assert.match(source, /writeScheduleHeartbeat\("expireStalePairedInvites"/);
    assert.match(source, /writeScheduleHeartbeat\("expireStaleSessions"/);
    assert.match(source, /writeScheduleHeartbeat\("expireStaleJointPostDrafts"/);
  });

  it("cleans ephemeral session subs on expiry (Z-DATA-004)", () => {
    assert.match(source, /deleteByQuery\(doc\.ref\.collection\("presence"\)\)/);
    assert.match(source, /deleteByQuery\(doc\.ref\.collection\("plans"\)\)/);
    assert.match(source, /Expired stale sessions/);
  });
});
