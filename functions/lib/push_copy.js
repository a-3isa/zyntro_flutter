"use strict";

/**
 * Pure push localization helpers (Z-I18N-003 / Z-TEST-003).
 * Kept free of Firebase so Node unit tests can exercise them without emulators.
 */

function normalizeUserLocale(raw) {
  if (typeof raw !== "string") return "en";
  const trimmed = raw.trim().toLowerCase();
  if (!trimmed) return "en";
  return trimmed.startsWith("ar") ? "ar" : "en";
}

function pushCopy(locale, en, ar) {
  return locale === "ar" ? ar : en;
}

module.exports = {
  normalizeUserLocale,
  pushCopy,
};
