import 'package:flutter/widgets.dart';

/// Decode-size hints for [CachedNetworkImage] (Z-PERF-003).
///
/// Passing [memCacheWidth]/[memCacheHeight] keeps decoded bitmaps near the
/// on-screen size instead of full-resolution camera photos.
class ImageDecodeBudget {
  ImageDecodeBudget._();

  static int? memCacheWidthFor(BuildContext context, double logicalWidth) {
    if (logicalWidth <= 0) return null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (logicalWidth * dpr).round().clamp(48, 2048);
  }

  static int? memCacheHeightFor(BuildContext context, double logicalHeight) {
    if (logicalHeight <= 0) return null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (logicalHeight * dpr).round().clamp(48, 2048);
  }
}
