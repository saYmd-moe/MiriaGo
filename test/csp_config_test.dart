import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/config/csp_config.dart';
import 'package:miriago/map/map_tile_config.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

/// Splits a CSP string into directive-name → source-list.
Map<String, Set<String>> _parseCsp(String csp) {
  final result = <String, Set<String>>{};
  for (final part in csp.split(';')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final space = trimmed.indexOf(' ');
    if (space < 0) {
      result[trimmed] = const {};
      continue;
    }
    final directive = trimmed.substring(0, space);
    final sources = trimmed
        .substring(space + 1)
        .split(RegExp(r'\s+'))
        .where((source) => source.isNotEmpty)
        .toSet();
    result[directive] = sources;
  }
  return result;
}

void main() {
  group('MiriaGoCsp.desktopPolicy', () {
    final csp = _parseCsp(MiriaGoCsp.desktopPolicy);

    test('is a well-formed non-empty policy', () {
      expect(csp, isNotEmpty);
      for (final directive in [
        'default-src',
        'script-src',
        'style-src',
        'img-src',
        'connect-src',
        'font-src',
        'worker-src',
        'object-src',
        'base-uri',
        'frame-src',
      ]) {
        expect(csp.containsKey(directive), isTrue, reason: '$directive missing');
      }
    });

    test('locks down scripting surfaces', () {
      expect(csp['object-src'], {'none'});
      expect(csp['base-uri'], {'self'});
      expect(csp['frame-src'], {'self'});
      expect(csp['default-src'], {'self'});

      final scripts = csp['script-src']!;
      expect(scripts.contains('self'), isTrue);
      expect(scripts.contains("'unsafe-inline'"), isFalse);
      expect(scripts.contains("'unsafe-eval'"), isFalse);
      expect(scripts.contains('data:'), isFalse);
    });

    test('allows default map and Anitabi sources', () {
      final connects = csp['connect-src']!;
      expect(connects.contains('self'), isTrue);
      // Default and user-configured https map/image sources stay reachable.
      expect(connects.contains('https:'), isTrue);
      expect(connects.contains('http:'), isFalse);

      final images = csp['img-src']!;
      for (final host in [
        'self',
        'data:',
        'blob:',
        'https://image.anitabi.cn',
        'https://img-tc.anitabi.cn',
      ]) {
        expect(images.contains(host), isTrue, reason: '$host should be allowed');
      }
    });

    test('supports the vendored map engine via same-origin only', () {
      // After M3 vendors MapLibre locally the policy still works with just
      // 'self' — it must not hard-depend on the transitional CDN host.
      final scripts = csp['script-src']!;
      final styles = csp['style-src']!;
      expect(scripts.contains('self'), isTrue);
      expect(styles.contains('self'), isTrue);
      // Unpkg is a removable transitional entry, not a load-bearing one.
      final withoutCdn = MiriaGoCsp.desktopPolicy
          .replaceAll('https://unpkg.com', '');
      expect(_parseCsp(withoutCdn)['script-src']!.contains('self'), isTrue);
      expect(_parseCsp(withoutCdn)['style-src']!.contains('self'), isTrue);
    });
  });

  group('customMapSourceCspNotice', () {
    test('is null for default map sources', () {
      expect(customMapSourceCspNotice(const AppSettings()), isNull);
      expect(
        customMapSourceCspNotice(
          const AppSettings(mapTileProvider: MapTileProvider.openStreetMap),
        ),
        isNull,
      );
    });

    test('is null for secure https custom sources', () {
      expect(
        customMapSourceCspNotice(
          const AppSettings(
            mapTileProvider: MapTileProvider.customXyz,
            customXyzTileUrl: 'https://tiles.example.com/{z}/{x}/{y}.png',
          ),
        ),
        isNull,
      );
      expect(
        customMapSourceCspNotice(
          const AppSettings(
            mapTileProvider: MapTileProvider.customMapLibreStyle,
            customMapLibreStyleUrl: 'https://tiles.example.com/style.json',
          ),
        ),
        isNull,
      );
    });

    test('reports a clear error for insecure http custom sources', () {
      final xyz = customMapSourceCspNotice(
        const AppSettings(
          mapTileProvider: MapTileProvider.customXyz,
          customXyzTileUrl: 'http://tiles.example.com/{z}/{x}/{y}.png',
        ),
      );
      expect(xyz, isNotNull);
      expect(xyz, contains('http'));
      expect(xyz, contains('https'));

      final style = customMapSourceCspNotice(
        const AppSettings(
          mapTileProvider: MapTileProvider.customMapLibreStyle,
          customMapLibreStyleUrl: 'http://tiles.example.com/style.json',
        ),
      );
      expect(style, isNotNull);
      expect(style, contains('https'));
      expect(
        mapSourceConfigurationMessage(
          const AppSettings(
            mapTileProvider: MapTileProvider.customXyz,
            customXyzTileUrl: 'http://tiles.example.com/{z}/{x}/{y}.png',
          ),
        ),
        xyz,
      );
    });

    test('every validated map source is CSP-consumable', () {
      const httpsXyz = AppSettings(
        mapTileProvider: MapTileProvider.customXyz,
        customXyzTileUrl: 'https://tiles.example.com/{z}/{x}/{y}.png',
      );
      const httpsStyle = AppSettings(
        mapTileProvider: MapTileProvider.customMapLibreStyle,
        customMapLibreStyleUrl: 'https://tiles.example.com/style.json',
      );
      expect(isValidMapSourceConsumedByCsp(httpsXyz), isTrue);
      expect(isValidMapSourceConsumedByCsp(httpsStyle), isTrue);
    });
  });

  test('map tile default hosts match the CSP manifest domains', () {
    // The audit: the URLs the app hardcodes must be covered by the policy.
    for (final url in [
      openFreeMapStyleUrl,
      openStreetMapTileUrl,
      ...openFreeMapStyleOptions.map((option) => option.styleUrl),
    ]) {
      final host = Uri.parse(url).host;
      expect(
        defaultMapTileHosts.contains(host),
        isTrue,
        reason: '$host should be listed in defaultMapTileHosts',
      );
    }
    expect(defaultMapTileHosts.contains('tiles.openfreemap.org'), isTrue);
  });
}
