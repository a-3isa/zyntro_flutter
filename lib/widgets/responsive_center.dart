import 'package:flutter/material.dart';

/// A widget that limits the max width of its child content on larger screens
/// and centers it, useful for web/tablet responsive layouts.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? scrollPhysics;
  final bool maxContentWidth;
  final AlignmentGeometry alignment;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding = EdgeInsets.zero,
    this.scrollPhysics,
    this.maxContentWidth = false,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
