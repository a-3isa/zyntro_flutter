import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Centralised type scale for Zyntro.
///
/// All getters are colour-agnostic — apply colour at the call site via
/// `.copyWith(color: AppColors.textV2Primary)` or let [AppTheme.textTheme]
/// provide it through the Material theme.
///
/// Text scaling is capped at 1.3× app-wide via [MediaQuery.withClampedTextScaling]
/// in [ZyntroApp.builder] — individual styles do not need to handle it.
class AppTextStyles {
  AppTextStyles._();

  /// Syne 48sp w700 — wordmark, hero headings.
  static TextStyle get display => GoogleFonts.syne(
        fontSize: AppFontSize.hero,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.1,
      );

  /// Syne 40sp w700 — screen-level page titles.
  static TextStyle get h1 => GoogleFonts.syne(
        fontSize: AppFontSize.display,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.15,
      );

  /// Syne 32sp w600 — section titles.
  static TextStyle get h2 => GoogleFonts.syne(
        fontSize: AppFontSize.xxxl,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.2,
      );

  /// Syne 24sp w600 — card headings, modal titles.
  static TextStyle get h3 => GoogleFonts.syne(
        fontSize: AppFontSize.xxl,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.25,
      );

  /// Syne 20sp w600 — list item headings, tab titles.
  static TextStyle get h4 => GoogleFonts.syne(
        fontSize: AppFontSize.xl,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
      );

  /// Syne 18sp w600 — AppBar titles, section labels.
  static TextStyle get h5 => GoogleFonts.syne(
        fontSize: AppFontSize.lg,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
      );

  /// Outfit 16sp w500 — prominent body copy, step labels.
  static TextStyle get bodyLarge => GoogleFonts.outfit(
        fontSize: AppFontSize.md,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.5,
      );

  /// Outfit 14sp w400 — standard body copy, descriptions.
  static TextStyle get body => GoogleFonts.outfit(
        fontSize: AppFontSize.sm,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      );

  /// Outfit 14sp w600 — button labels, tab labels, chips.
  static TextStyle get label => GoogleFonts.outfit(
        fontSize: AppFontSize.sm,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.2,
      );

  /// Outfit 12sp w400 — timestamps, helper text, metadata.
  static TextStyle get caption => GoogleFonts.outfit(
        fontSize: AppFontSize.xs,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.4,
      );
}
