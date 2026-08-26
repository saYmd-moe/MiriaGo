import 'cache_management_io.dart'
    if (dart.library.js_interop) 'cache_management_stub.dart'
    as impl;

/// Size snapshot of the re-fetchable reference-image caches.
class ReferenceCacheStats {
  const ReferenceCacheStats({
    required this.fullBytes,
    required this.fullCount,
    required this.thumbnailBytes,
    required this.thumbnailCount,
  });

  final int fullBytes;
  final int fullCount;
  final int thumbnailBytes;
  final int thumbnailCount;

  bool get isEmpty => fullCount == 0 && thumbnailCount == 0;

  static const empty = ReferenceCacheStats(
    fullBytes: 0,
    fullCount: 0,
    thumbnailBytes: 0,
    thumbnailCount: 0,
  );
}

/// Result of a reference-cache clear operation.
class ReferenceCacheClearResult {
  const ReferenceCacheClearResult({
    required this.outcome,
    required this.fullFreedBytes,
    required this.fullFreedCount,
    required this.thumbnailFreedBytes,
    required this.thumbnailFreedCount,
    this.message,
  });

  final CacheClearOutcome outcome;
  final int fullFreedBytes;
  final int fullFreedCount;
  final int thumbnailFreedBytes;
  final int thumbnailFreedCount;
  final String? message;
}

enum CacheClearOutcome { cleared, unavailable }

Future<ReferenceCacheStats> loadReferenceCacheStats() {
  return impl.loadReferenceCacheStats();
}

Future<ReferenceCacheClearResult> clearReferenceCache({
  required bool includeThumbnails,
}) {
  return impl.clearReferenceCache(includeThumbnails: includeThumbnails);
}

bool get isReferenceCacheManagementAvailable => impl.isCacheManagementAvailable;
