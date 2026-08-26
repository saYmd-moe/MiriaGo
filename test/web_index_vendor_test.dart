import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards M3 offline reliability: MapLibre GL JS/CSS must be vendored locally and
/// `web/index.html` must not load the MapLibre engine from a runtime public CDN.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('web/index.html loads MapLibre from local vendor, not a runtime CDN', () {
    final html = File('web/index.html').readAsStringSync();

    // No runtime public CDN references remain for the MapLibre engine.
    expect(
      html.contains('unpkg.com/maplibre-gl') ||
          html.contains('cdn.jsdelivr.net/maplibre-gl') ||
          html.contains('https://unpkg.com/maplibre'),
      isFalse,
      reason: 'MapLibre GL must be served locally, not from a public CDN.',
    );

    // The engine style and script are referenced via local relative paths so they
    // ship inside build/web/ and load without a network.
    expect(
      html.contains('href="vendor/maplibre-gl/maplibre-gl.css"'),
      isTrue,
      reason:
          'maplibre-gl.css should be referenced from the local vendor path.',
    );
    expect(
      html.contains('src="vendor/maplibre-gl/maplibre-gl.js"'),
      isTrue,
      reason: 'maplibre-gl.js should be referenced from the local vendor path.',
    );
  });

  test('vendored MapLibre assets are committed and non-empty', () {
    final jsFile = File('web/vendor/maplibre-gl/maplibre-gl.js');
    final cssFile = File('web/vendor/maplibre-gl/maplibre-gl.css');
    final licenseFile = File('web/vendor/maplibre-gl/LICENSE.txt');

    expect(
      jsFile.existsSync(),
      isTrue,
      reason: 'maplibre-gl.js must be vendored.',
    );
    expect(
      cssFile.existsSync(),
      isTrue,
      reason: 'maplibre-gl.css must be vendored.',
    );
    expect(
      licenseFile.existsSync(),
      isTrue,
      reason: 'MapLibre license must be vendored.',
    );

    // Sanity: the UMD bundle exposes the global maplibregl namespace.
    final js = jsFile.readAsStringSync();
    expect(js.length, greaterThan(100_000));
    expect(js.contains('maplibregl'), isTrue);
    expect(js.contains('3-Clause BSD'), isTrue);

    final css = cssFile.readAsStringSync();
    expect(css.length, greaterThan(1_000));
    expect(css.contains('.maplibregl-'), isTrue);
  });

  test('vendored MapLibre version matches the pinned commit record', () {
    final js = File('web/vendor/maplibre-gl/maplibre-gl.js').readAsStringSync();
    // The pinned release stamp is embedded in the banner.
    expect(
      js.contains('v5.24.0') || js.contains('5.24.0'),
      isTrue,
      reason: 'vendored maplibre-gl.js should be the pinned 5.24.0 release.',
    );
  });
}
