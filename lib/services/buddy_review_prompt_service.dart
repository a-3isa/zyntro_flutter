import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local counter + one-shot store review prompt after the 3rd real-friend
/// buddy session (Z-ENH-017). Uses SharedPreferences so it does not depend on
/// server-owned `buddyWorkouts` (Z-DATA-001).
class BuddyReviewPromptService {
  BuddyReviewPromptService({
    SharedPreferences? prefs,
    InAppReview? inAppReview,
  }) : _prefsOverride = prefs,
       _review = inAppReview ?? InAppReview.instance;

  static const completedCountKey = 'buddy_sessions_completed_for_review';
  static const alreadyAskedKey = 'in_app_review_requested';
  static const threshold = 3;

  final SharedPreferences? _prefsOverride;
  final InAppReview _review;

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? SharedPreferences.getInstance();

  /// Whether a review prompt should fire for this completed count.
  static bool shouldRequestReview({
    required int completedCount,
    required bool alreadyAsked,
  }) {
    if (alreadyAsked) return false;
    return completedCount >= threshold;
  }

  /// Call after a real-friend buddy session successfully ends.
  Future<void> onBuddySessionCompleted() async {
    try {
      final prefs = await _prefs();
      if (prefs.getBool(alreadyAskedKey) == true) return;

      final next = (prefs.getInt(completedCountKey) ?? 0) + 1;
      await prefs.setInt(completedCountKey, next);

      if (!shouldRequestReview(
        completedCount: next,
        alreadyAsked: false,
      )) {
        return;
      }

      if (!await _review.isAvailable()) return;
      await _review.requestReview();
      await prefs.setBool(alreadyAskedKey, true);
    } catch (e) {
      debugPrint('[BuddyReviewPrompt] skipped: $e');
    }
  }
}

final buddyReviewPromptServiceProvider = Provider<BuddyReviewPromptService>((
  ref,
) {
  return BuddyReviewPromptService();
});
