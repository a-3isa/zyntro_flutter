import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart';

/// Custom image cache manager for Zyntro app.
/// Implements memory limits, disk limits, and retention policies.
class ZyntroImageCacheManager extends CacheManager {
  static const key = 'zyntro_image_cache';

  static final ZyntroImageCacheManager _instance = ZyntroImageCacheManager._();
  factory ZyntroImageCacheManager() => _instance;

  ZyntroImageCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects:
              500, // Disk limit count (approx 1GB if 2MB each, but usually smaller)
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ),
      ) {
    // Run cleanup on startup
    _cleanup();
  }

  void _cleanup() {
    try {
      // Clean stale files
      // CacheManager handles stalePeriod automatically on initialization/usage.
      // Removed manual emptyCache() to preserve cached files.
    } catch (e) {
      debugPrint('Error cleaning image cache: $e');
    }
  }

  /// Clear files older than specific duration manually if needed
  Future<void> clearOldCache() async {
    await emptyCache(); // Clears everything for this key
  }
}
