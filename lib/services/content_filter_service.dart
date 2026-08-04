import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:profanity_filter/profanity_filter.dart';

/// Content filter service for detecting and censoring inappropriate text.
/// Wraps the profanity_filter package with validation methods.
class ContentFilterService {
  final ProfanityFilter _filter = ProfanityFilter();

  /// Words the generic profanity list rejects but this app must allow.
  ///
  /// Zyntro is a workout tracker, and several standard movements are words a
  /// general-purpose filter flags. "Snatch" is an Olympic lift; without this
  /// allowlist a user cannot title a post after the exercise they just did.
  /// Kept deliberately narrow — each entry is a real movement or gym term, not
  /// a general relaxation of the filter.
  static const gymTermAllowlist = <String>{
    'snatch',
    'clean',
    'jerk',
    'thrust',
    'thruster',
    'crack', // as in "crack a PR"
  };

  /// Profane words in [text], excluding [gymTermAllowlist] entries.
  List<String> _offendingWords(String text) {
    return _filter
        .getAllProfanity(text)
        .where((word) => !gymTermAllowlist.contains(word.toLowerCase()))
        .toList();
  }

  /// Check if text contains profanity.
  bool containsProfanity(String text) {
    if (text.isEmpty) return false;
    if (!_filter.hasProfanity(text)) return false;
    return _offendingWords(text).isNotEmpty;
  }

  /// Censor profanity in text (replaces with asterisks).
  String censorText(String text) {
    if (text.isEmpty) return text;
    if (!containsProfanity(text)) return text;
    return _filter.censor(text);
  }

  /// Get list of detected profane words in text.
  List<String> getDetectedWords(String text) {
    if (text.isEmpty) return [];
    return _offendingWords(text);
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
