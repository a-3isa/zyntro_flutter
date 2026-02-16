import 'package:flutter/material.dart';
import '../core/constants/feature_flags.dart';
import 'coming_soon_dialog.dart';

/// A wrapper widget that conditionally enables/disables its child based on a [FeatureFlag].
///
/// If the feature is enabled, it renders the [child] normally.
/// If the feature is disabled, it wraps the child with an opacity effect (if [showDisabledState] is true)
/// and intercepts taps to show the [ComingSoonDialog].
///
/// [Visual Design]
/// - Disabled features are shown with 50% opacity (if [showDisabledState] is true)
///
/// [Usage Warning]
/// - DO NOT wrap core MVP features (Auth, Sessions, Feed, LocalLeaderboard)
/// - Only wrap Post-MVP features (Comments, Challenges, Payments, etc.)
class MVPFeatureWrapper extends StatelessWidget {
  /// The feature flag to check.
  final FeatureFlag feature;

  /// The widget to wrap (the feature's entry point).
  final Widget child;

  /// Display name of the feature for the "Coming Soon" dialog.
  final String featureName;

  /// Optional description for the "Coming Soon" dialog.
  final String? description;

  /// Whether to visually indicate the disabled state (e.g., lower opacity).
  /// Defaults to true.
  final bool showDisabledState;

  const MVPFeatureWrapper({
    super.key,
    required this.feature,
    required this.child,
    required this.featureName,
    this.description,
    this.showDisabledState = true,
  });

  @override
  Widget build(BuildContext context) {
    if (FeatureFlags.isFeatureEnabled(feature)) {
      return child;
    }

    // Feature is disabled
    final disabledChild = showDisabledState
        ? Opacity(
            opacity: 0.5,
            child: IgnorePointer(ignoring: true, child: child),
          )
        : IgnorePointer(ignoring: true, child: child);

    return GestureDetector(
      onTap: () {
        ComingSoonDialog.show(
          context,
          featureName: featureName,
          description: description,
        );
      },
      behavior: HitTestBehavior
          .opaque, // Ensure tap is caught even on transparent parts
      child: disabledChild,
    );
  }
}
