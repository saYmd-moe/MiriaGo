import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cache_management.dart';

const _fullDirectoryName = 'reference_full';
const _thumbnailDirectoryName = 'reference_thumbnails';

/// Whether cache stats/clear are available on this platform.
///
/// On native (io) platforms this is always true. See
/// `cache_management_stub.dart` for the Tauri/web variant.
bool get isCacheManagementAvailable => true;

class _DirectoryTotals {
  const _DirectoryTotals({required this.bytes, required this.count});

  final int bytes;
  final int count;
}

Future<ReferenceCacheStats> loadReferenceCacheStats() async {
  final root = await _documentsRoot();
  if (root == null) {
    return ReferenceCacheStats.empty;
  }
  final full = await _directoryTotals(
    Directory(p.join(root.path, _fullDirectoryName)),
  );
  final thumbs = await _directoryTotals(
    Directory(p.join(root.path, _thumbnailDirectoryName)),
  );
  return ReferenceCacheStats(
    fullBytes: full.bytes,
    fullCount: full.count,
    thumbnailBytes: thumbs.bytes,
    thumbnailCount: thumbs.count,
  );
}

Future<ReferenceCacheClearResult> clearReferenceCache({
  required bool includeThumbnails,
}) async {
  final root = await _documentsRoot();
  if (root == null) {
    return const ReferenceCacheClearResult(
      outcome: CacheClearOutcome.unavailable,
      fullFreedBytes: 0,
      fullFreedCount: 0,
      thumbnailFreedBytes: 0,
      thumbnailFreedCount: 0,
      message: '缓存目录不可用',
    );
  }

  final full = await _clearDirectory(
    Directory(p.join(root.path, _fullDirectoryName)),
  );
  final thumb = includeThumbnails
      ? await _clearDirectory(
          Directory(p.join(root.path, _thumbnailDirectoryName)),
        )
      : const _DirectoryTotals(bytes: 0, count: 0);

  return ReferenceCacheClearResult(
    outcome: CacheClearOutcome.cleared,
    fullFreedBytes: full.bytes,
    fullFreedCount: full.count,
    thumbnailFreedBytes: thumb.bytes,
    thumbnailFreedCount: thumb.count,
  );
}

Future<Directory?> _documentsRoot() async {
  try {
    return await getApplicationDocumentsDirectory();
  } catch (_) {
    return null;
  }
}

/// Sums byte size and count of immediate regular files in [directory].
///
/// Subdirectories and hidden entries are ignored. Files are read for their length
/// without being opened/loaded, so this is safe for large caches.
Future<_DirectoryTotals> _directoryTotals(Directory directory) async {
  if (!directory.existsSync()) {
    return const _DirectoryTotals(bytes: 0, count: 0);
  }
  var bytes = 0;
  var count = 0;
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    try {
      final length = await entity.length();
      if (length > 0) {
        bytes += length;
        count += 1;
      }
    } catch (_) {
      // Ignore files that cannot be stat'ed.
    }
  }
  return _DirectoryTotals(bytes: bytes, count: count);
}

/// Deletes immediate regular files in [directory] and returns freed totals.
Future<_DirectoryTotals> _clearDirectory(Directory directory) async {
  if (!directory.existsSync()) {
    return const _DirectoryTotals(bytes: 0, count: 0);
  }
  var bytes = 0;
  var count = 0;
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    try {
      final length = await entity.length();
      await entity.delete();
      if (length > 0) {
        bytes += length;
        count += 1;
      }
    } catch (_) {
      // Best-effort: skip files that cannot be deleted.
    }
  }
  return _DirectoryTotals(bytes: bytes, count: count);
}
