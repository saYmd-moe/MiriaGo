import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/cache_management.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'stats and cleanup are limited to re-fetchable cache directories',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'miriago_cache_management_',
      );
      addTearDown(() async {
        if (root.existsSync()) {
          await root.delete(recursive: true);
        }
      });
      PathProviderPlatform.instance = _FakePathProviderPlatform(root.path);

      await Directory(
        p.join(root.path, 'reference_full'),
      ).create(recursive: true);
      await Directory(
        p.join(root.path, 'reference_thumbnails'),
      ).create(recursive: true);
      await Directory(
        p.join(root.path, 'imported_plan_assets', 'assets'),
      ).create(recursive: true);
      await Directory(
        p.join(root.path, 'user_reference_images'),
      ).create(recursive: true);
      await File(
        p.join(root.path, 'reference_full', 'network.jpg'),
      ).writeAsBytes(List<int>.filled(3, 1));
      await File(
        p.join(root.path, 'reference_thumbnails', 'network.jpg'),
      ).writeAsBytes(List<int>.filled(2, 1));
      final database = File(p.join(root.path, 'seichi_junrei.sqlite'));
      await database.writeAsString('database');
      final userPhoto = File(
        p.join(root.path, 'user_reference_images', 'photo.jpg'),
      );
      await userPhoto.writeAsString('user photo');
      final imported = File(
        p.join(root.path, 'imported_plan_assets', 'assets', 'kept.jpg'),
      );
      await imported.writeAsString('imported asset');

      final stats = await loadReferenceCacheStats();
      expect(stats.fullBytes, 3);
      expect(stats.fullCount, 1);
      expect(stats.thumbnailBytes, 2);
      expect(stats.thumbnailCount, 1);

      final fullOnly = await clearReferenceCache(includeThumbnails: false);
      expect(fullOnly.outcome, CacheClearOutcome.cleared);
      expect(fullOnly.fullFreedBytes, 3);
      expect(fullOnly.thumbnailFreedBytes, 0);
      expect(
        File(p.join(root.path, 'reference_full', 'network.jpg')).existsSync(),
        isFalse,
      );
      expect(
        File(
          p.join(root.path, 'reference_thumbnails', 'network.jpg'),
        ).existsSync(),
        isTrue,
      );
      expect(database.readAsStringSync(), 'database');
      expect(userPhoto.readAsStringSync(), 'user photo');
      expect(imported.readAsStringSync(), 'imported asset');

      final allCaches = await clearReferenceCache(includeThumbnails: true);
      expect(allCaches.thumbnailFreedBytes, 2);
      expect(
        File(
          p.join(root.path, 'reference_thumbnails', 'network.jpg'),
        ).existsSync(),
        isFalse,
      );
      expect(database.existsSync(), isTrue);
      expect(userPhoto.existsSync(), isTrue);
      expect(imported.existsSync(), isTrue);
    },
  );
}
