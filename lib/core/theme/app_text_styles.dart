import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Centralised type scale for Zyntro.
///
/// Body and UI use Bricolage Grotesque. Session stats use Barlow Condensed.
/// All getters are colour-agnostic — apply colour at the call site via
/// `.copyWith(color: AppColors.textV2Primary)` or let [AppTheme.textTheme]
/// provide it through the Material theme.
///
/// Text scaling is clamped at 2.0× app-wide via [MediaQuery.withClampedTextScaling]
/// so OS accessibility text size up to 200% (WCAG 1.4.4) is honored (Z-A11Y-003).
/// in [ZyntroApp.builder] — individual styles do not need to handle it.
class AppTextStyles {
  AppTextStyles._();

  /// Barlow Condensed 48sp w800 — wordmark, hero numbers.
  static TextStyle get display => GoogleFonts.barlowCondensed(
    fontSize: AppFontSize.hero,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.05,
  );

  /// Barlow Condensed 80sp w800 — live rep/timer figures.
  static TextStyle get sessionStat => GoogleFonts.barlowCondensed(
    fontSize: 80,
    fontWeight: FontWeight.w800,
    letterSpacing: -2,
    height: 0.95,
  );

  /// Barlow Condensed wordmark — feed/social headers.
  static TextStyle get wordmark => GoogleFonts.barlowCondensed(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.4,
    height: 1.0,
  );

  /// Bricolage Grotesque 40sp w700 — screen-level page titles.
  static TextStyle get h1 => GoogleFonts.bricolageGrotesque(
    fontSize: AppFontSize.display,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.15,
  );

  /// Bricolage Grotesque 32sp w600 — section titles.
  static TextStyle get h2 => GoogleFonts.bricolageGrotesque(
    fontSize: AppFontSize.xxxl,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
  );

  /// Bricolage Grotesque 24sp w600 — card headings, modal titles.
  static TextStyle get h3 => GoogleFonts.bricolageGrotesque(
    fontSize: AppFontSize.xxl,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.25,
  );

  /// Bricolage Grotesque 20sp w600 — list item headings, tab titles.
  static TextStyle get h4 => GoogleFonts.bricolageGrotesque(
    fontSize: AppFontSize.xl,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  /// Bricolage Grotesque 18sp w600 — AppBar titles, section labels.
  static TextStyle get h5 => GoogleFonts.bricolageGrotesque(
    fontSize: AppFontSize.lg,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  /// Bricolage Grotesque 16sp w500 — prominent body copy, step labels.
  static TextStyle get bodyLarge => GoogleFonts.bricolageGrotesque(
    fontSize: AppFontSize.md,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Bricolage Grotesque 14sp w400 — standard body copy, descriptions.
  static TextStyle get body => GoogleFonts.bricolageGrotesque(
    fontSize: AppFontSize.sm,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Bricolage Grotesque 14sp w600 — button labels, tab labels, chips.
  static TextStyle get label => GoogleFonts.bricolageGrotesque(
    fontSize: AppFontSize.sm,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  /// Bricolage Grotesque 12sp w400 — timestamps, helper text, metadata.
  static TextStyle get caption => GoogleFonts.bricolageGrotesque(
    fontSize: AppFontSize.xs,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.4,
  );
}
