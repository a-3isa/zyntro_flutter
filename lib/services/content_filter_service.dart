import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:profanity_filter/profanity_filter.dart';

/// Content filter service for detecting and censoring inappropriate text.
/// Wraps the profanity_filter package with validation methods.
class ContentFilterService {
  final ProfanityFilter _filter = ProfanityFilter();

  /// Check if text contains profanity.
  bool containsProfanity(String text) {
    if (text.isEmpty) return false;
    return _filter.hasProfanity(text);
  }

  /// Censor profanity in text (replaces with asterisks).
  String censorText(String text) {
    if (text.isEmpty) return text;
    return _filter.censor(text);
  }

  /// Get list of detected profane words in text.
  List<String> getDetectedWords(String text) {
    if (text.isEmpty) return [];
    return _filter.getAllProfanity(text);
  }

  /// Validate text and throw if profanity detected.
  /// Use this for input validation before saving to Firestore.
  void validateText(String text, String fieldName) {
    if (containsProfanity(text)) {
      final words = getDetectedWords(text);
      debugPrint(
        '[ContentFilterService] Profanity detected in $fieldName: $words',
      );
      throw ContentFilterException(
        'Your $fieldName contains inappropriate language. Please revise.',
      );
    }
  }
}

/// Exception thrown when content contains profanity.
class ContentFilterException implements Exception {
  final String message;
  ContentFilterException(this.message);

  @override
  String toString() => message;
}

/// Content filter service provider.
final contentFilterServiceProvider = Provider<ContentFilterService>((ref) {
  return ContentFilterService();
});
