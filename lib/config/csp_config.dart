import '../map/map_tile_config.dart';
import '../plan/pilgrimage_models.dart';

/// Single source of truth for MiriaGo's web Content Security Policy (CSP).
///
/// The Rust/Tauri desktop shell applies `MiriaGoCsp.desktopPolicy` through
/// `src-tauri/tauri.conf.json` → `app.security.csp`.  Keeping the policy in
/// one place (plus a Rust test that reads `tauri.conf.json`) makes it
/// regression-testable without a live browser or CDN.
///
/// This module documents the resource types and hosts the app actually talks
/// to, so tightening the policy can be reasoned about in one place.
/// Hosts the MapLibre renderer fetches style documents and raster/vector
/// tiles from for the default map sources.
///
/// - `tiles.openfreemap.org` serves both the MapLibre style JSON and its
///   tiles for the default OpenFreeMap presets.
/// - `tile.openstreetmap.org` is the default XYZ raster source.
///
/// Custom user-configured map sources are not enumerated here by design: they
/// are arbitrary `https` endpoints supplied by the user, so the enforced
/// policy allows `https:` for `connect-src` and reports a clear notice for any
/// `http:` custom source instead of silently blocking it.
const defaultMapTileHosts = <String>[
  'tiles.openfreemap.org',
  'tile.openstreetmap.org',
];

/// Hosts used to display remote reference / cover images (`img-src`).
///
/// MiriaGo renders remote reference images with `Image.network` through
/// [AnitabiNetworkImage], so the policy must allow these two image CDNs.
/// Bangumi subject covers and user-supplied reference URLs come from other
/// hosts the app cannot enumerate ahead of time; the policy therefore also
/// allows `https:` for `img-src`.
const anitabiImageHostsForCsp = <String>[
  'https://image.anitabi.cn',
  'https://img-tc.anitabi.cn',
];

/// Builds the MiriaGo desktop CSP.
///
/// Design intent ("minimal usable policy"):
/// - Scripting surfaces are locked down: only same-origin scripts plus
///   CanvasKit WASM. No arbitrary remote scripts, no inline script execution,
///   no objects, no frames.
/// - Data channels (`connect-src`, `img-src`) allow `https:` so the
///   user-configurable map/image sources keep working; plain `http` and other
///   schemes are blocked, and [customMapSourceCspNotice] surfaces a clear
///   error when an active custom source would otherwise be affected.
abstract final class MiriaGoCsp {
  /// Entries for `script-src`.
  static const List<String> scriptSources = <String>[
    "'self'",
    "'wasm-unsafe-eval'", // CanvasKit/WASM renderer
  ];

  /// Entries for `style-src`. Flutter injects inline styles.
  static const List<String> styleSources = <String>[
    "'self'",
    "'unsafe-inline'",
  ];

  /// Entries for `img-src`: local, `data:`/`blob:` (desktop local assets and
  /// rendered canvas textures) plus remote image hosts and arbitrary https
  /// reference/cover images.
  static const List<String> imageSources = <String>[
    "'self'",
    'data:',
    'blob:',
    ...anitabiImageHostsForCsp,
    'https:',
  ];

  /// Entries for `connect-src`: same-origin plus https for map styles/tiles,
  /// the Bangumi API and user-configured https sources.
  static const List<String> connectSources = <String>["'self'", 'https:'];

  /// The complete policy delivered to the Tauri webview. Keep in sync with
  /// `src-tauri/tauri.conf.json` (asserted by both Rust and Dart tests).
  static final String desktopPolicy = ''
      "default-src 'self'; "
      "base-uri 'self'; "
      "object-src 'none'; "
      "frame-src 'self'; "
      "worker-src 'self' blob:; "
      "font-src 'self'; "
      'img-src ${imageSources.join(' ')}; '
      'style-src ${styleSources.join(' ')}; '
      'script-src ${scriptSources.join(' ')}; '
      "connect-src 'self' https:;";
}

/// Returns a user-facing notice (or `null`) describing a CSP limitation for
/// the *active* map source, so custom sources fail loudly instead of
/// silently.
///
/// The enforced policy only allows `https` for tile/style fetching.  A
/// user-configured `http:` custom source is therefore blocked by CSP; we tell
/// the user to use `https` rather than letting the map blank out silently.
String? customMapSourceCspNotice(AppSettings settings) {
  switch (settings.mapTileProvider) {
    case MapTileProvider.customXyz:
      final url = settings.customXyzTileUrl.trim();
      if (url.isEmpty || !_usesInsecureHttp(url)) {
        return null;
      }
      return '自定义 XYZ 使用了不安全的 http:// 地址，会被桌面安全策略（CSP）拦截。'
          '请改用 https:// 地址，或使用默认地图源。';
    case MapTileProvider.customMapLibreStyle:
      final url = settings.customMapLibreStyleUrl.trim();
      if (url.isEmpty || !_usesInsecureHttp(url)) {
        return null;
      }
      return '自定义 MapLibre 样式使用了不安全的 http:// 地址，会被桌面安全策略（CSP）拦截。'
          '请改用 https:// 地址，或使用默认的 OpenFreeMap 样式。';
    case MapTileProvider.openFreeMap:
    case MapTileProvider.openStreetMap:
      return null;
  }
}

bool _usesInsecureHttp(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.scheme == 'http';
}

/// Returns the first actionable map-source error for settings and security.
/// The map screen uses this as well as the settings screen, so an invalid or
/// CSP-incompatible custom source cannot silently look like the default map.
String? mapSourceConfigurationMessage(AppSettings settings) {
  return validateMapTileSettings(settings) ?? customMapSourceCspNotice(settings);
}

/// Whether every validated custom map source the user can configure is
/// already CSP-compatible (used by tests to assert we never silently break a
/// validated `https` source).
bool isValidMapSourceConsumedByCsp(AppSettings settings) {
  if (validateMapTileSettings(settings) != null) {
    return false;
  }
  return customMapSourceCspNotice(settings) == null;
}
