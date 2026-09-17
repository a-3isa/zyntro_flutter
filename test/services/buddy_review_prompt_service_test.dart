import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zyntro_flutter/services/buddy_review_prompt_service.dart';

void main() {
  group('BuddyReviewPromptService.shouldRequestReview', () {
    test('waits until the third buddy session', () {
      expect(
        BuddyReviewPromptService.shouldRequestReview(
          completedCount: 2,
          alreadyAsked: false,
        ),
        isFalse,
      );
      expect(
        BuddyReviewPromptService.shouldRequestReview(
          completedCount: 3,
          alreadyAsked: false,
        ),
        isTrue,
      );
    });

    test('never asks again after a prior prompt', () {
      expect(
        BuddyReviewPromptService.shouldRequestReview(
          completedCount: 99,
          alreadyAsked: true,
        ),
        isFalse,
      );
    });
  });

  test('onBuddySessionCompleted increments the local counter', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = BuddyReviewPromptService(prefs: prefs);

    await service.onBuddySessionCompleted();
    await service.onBuddySessionCompleted();

    expect(prefs.getInt(BuddyReviewPromptService.completedCountKey), 2);
    expect(prefs.getBool(BuddyReviewPromptService.alreadyAskedKey), isNull);
  });
}
