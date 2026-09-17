const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { normalizeUserLocale, pushCopy } = require("../lib/push_copy");

describe("push_copy unit helpers (Z-TEST-003)", () => {
  it("normalizeUserLocale maps Arabic variants to ar", () => {
    assert.equal(normalizeUserLocale("ar"), "ar");
    assert.equal(normalizeUserLocale("ar-SA"), "ar");
    assert.equal(normalizeUserLocale(" AR "), "ar");
  });

  it("normalizeUserLocale defaults non-Arabic to en", () => {
    assert.equal(normalizeUserLocale("en"), "en");
    assert.equal(normalizeUserLocale("fr"), "en");
    assert.equal(normalizeUserLocale(""), "en");
    assert.equal(normalizeUserLocale(null), "en");
    assert.equal(normalizeUserLocale(undefined), "en");
  });

  it("pushCopy selects Arabic or English body", () => {
    assert.equal(pushCopy("en", "Hello", "مرحبا"), "Hello");
    assert.equal(pushCopy("ar", "Hello", "مرحبا"), "مرحبا");
  });
});
