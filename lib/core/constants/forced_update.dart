import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/auth/auth_providers.dart';
import 'feature_flags.dart';

/// Compare dotted numeric versions (`1.0.1`). Longer missing segments are 0.
int compareSemver(String a, String b) {
  List<int> parts(String v) =>
      v.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
  final left = parts(a);
  final right = parts(b);
  final len = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < len; i++) {
    final x = i < left.length ? left[i] : 0;
    final y = i < right.length ? right[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// True when [current] is strictly older than [minimum] (Z-ENH-042).
bool isForcedUpdateRequired({
  required String current,
  required String? minimum,
}) {
  if (minimum == null || minimum.trim().isEmpty) return false;
  return compareSemver(current, minimum.trim()) < 0;
}

/// Reads `config/featureFlags.minSupportedVersion` and compares to the running
/// app version. Missing/unreadable config → no force (fail open for offline).
final forcedUpdateRequiredProvider = FutureProvider<bool>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final snapshot = await ref
        .watch(authFirestoreProvider)
        .collection(kRuntimeFlagsCollection)
        .doc(kRuntimeFlagsDocument)
        .get();
    final minimum = snapshot.data()?['minSupportedVersion'] as String?;
    return isForcedUpdateRequired(
      current: info.version,
      minimum: minimum,
    );
  } catch (e) {
    debugPrint('[ForcedUpdate] check skipped: $e');
    return false;
  }
});
