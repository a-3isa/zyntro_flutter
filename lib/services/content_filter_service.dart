import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:profanity_filter/profanity_filter.dart';

/// Content filter service for detecting and censoring inappropriate text.
/// Wraps the profanity_filter package with validation methods.
///
/// Z-SOC-001: also normalizes leetspeak / separators and checks a small
/// multi-locale blocklist so English-only package gaps are less trivial to bypass.
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

  /// High-confidence English stems checked against the normalized string
  /// (catches `sh1t`, `f.u.c.k`, etc.).
  static const englishAbuseStems = <String>{
    'shit',
    'fuck',
    'cunt',
    'bitch',
    'asshole',
    'motherfuck',
    'nigger',
    'nigga',
  };

  /// Extra blocked tokens beyond the English package list (normalized form).
  static const extraBlocklist = <String>{
    'puta',
    'puto',
    'mierda',
    'cabron',
    'pendejo',
    'sharmuta',
    'sharmoota',
    'kosomak',
    'putain',
    'salope',
    'encule',
  };

  /// Collapse leetspeak and separators so `sh1t` / `f.u.c.k` match.
  @visibleForTesting
  static String normalizeForFilter(String input) {
    final lower = input.toLowerCase();
    final buf = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      switch (ch) {
        case '0':
          buf.write('o');
        case '1':
          buf.write('i');
        case '3':
          buf.write('e');
        case '4':
          buf.write('a');
        case '5':
          buf.write('s');
        case '7':
          buf.write('t');
        case '8':
          buf.write('b');
        case '@':
          buf.write('a');
        case '\$':
          buf.write('s');
        case '!':
          buf.write('i');
        default:
          if (RegExp(r'[a-z\u0600-\u06ff]').hasMatch(ch)) {
            buf.write(ch);
          }
      }
    }
    return buf.toString();
  }

  /// Profane words in [text], excluding [gymTermAllowlist] entries.
  List<String> _offendingWords(String text) {
    final found = <String>{
      ..._filter
          .getAllProfanity(text)
          .where((word) => !gymTermAllowlist.contains(word.toLowerCase())),
    };

    final normalized = normalizeForFilter(text);
    for (final stem in englishAbuseStems) {
      if (normalized.contains(stem) && !gymTermAllowlist.contains(stem)) {
        found.add(stem);
      }
    }
    for (final token in extraBlocklist) {
      if (normalized.contains(token)) {
        found.add(token);
      }
    }

    return found.toList();
  }

  /// Check if text contains profanity.
  bool containsProfanity(String text) {
    if (text.isEmpty) return false;
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
