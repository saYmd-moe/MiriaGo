import '../desktop/tauri_bridge.dart' as tauri;
import 'cache_management.dart';

/// Whether cache stats/clear are available on this platform.
///
/// On the web (including the Tauri launcher) this becomes true only when the Tauri
/// launcher is actually present; otherwise the cache lives in the browser and there
/// is no safe shared cache directory to manage.
bool get isCacheManagementAvailable => tauri.isTauriLauncherAvailable;

Future<ReferenceCacheStats> loadReferenceCacheStats() async {
  if (!tauri.isTauriLauncherAvailable) {
    return ReferenceCacheStats.empty;
  }
  try {
    final stats = await tauri.loadDesktopReferenceCacheStats();
    if (stats == null) {
      return ReferenceCacheStats.empty;
    }
    return ReferenceCacheStats(
      fullBytes: stats.fullBytes,
      fullCount: stats.fullCount,
      thumbnailBytes: stats.thumbnailBytes,
      thumbnailCount: stats.thumbnailCount,
    );
  } on Object {
    return ReferenceCacheStats.empty;
  }
}

Future<ReferenceCacheClearResult> clearReferenceCache({
  required bool includeThumbnails,
}) async {
  if (!tauri.isTauriLauncherAvailable) {
    return const ReferenceCacheClearResult(
      outcome: CacheClearOutcome.unavailable,
      fullFreedBytes: 0,
      fullFreedCount: 0,
      thumbnailFreedBytes: 0,
      thumbnailFreedCount: 0,
      message: '当前环境不支持清除参考图缓存',
    );
  }
  try {
    final result = await tauri.clearDesktopReferenceCache(
      includeThumbnails: includeThumbnails,
    );
    if (result == null) {
      return const ReferenceCacheClearResult(
        outcome: CacheClearOutcome.unavailable,
        fullFreedBytes: 0,
        fullFreedCount: 0,
        thumbnailFreedBytes: 0,
        thumbnailFreedCount: 0,
        message: '清除参考图缓存时遇到问题',
      );
    }
    return ReferenceCacheClearResult(
      outcome: CacheClearOutcome.cleared,
      fullFreedBytes: result.fullFreedBytes,
      fullFreedCount: result.fullFreedCount,
      thumbnailFreedBytes: result.thumbnailFreedBytes,
      thumbnailFreedCount: result.thumbnailFreedCount,
    );
  } on Object {
    return const ReferenceCacheClearResult(
      outcome: CacheClearOutcome.unavailable,
      fullFreedBytes: 0,
      fullFreedCount: 0,
      thumbnailFreedBytes: 0,
      thumbnailFreedCount: 0,
      message: '清除参考图缓存时遇到问题',
    );
  }
}
