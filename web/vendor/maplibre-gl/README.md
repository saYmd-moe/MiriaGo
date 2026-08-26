# Vendored MapLibre GL JS/CSS

These files are **committed** copies of the public MapLibre GL JS distribution so that
MiriaGo's Flutter Web and Tauri (Linux/macOS/Windows WebView) builds do not depend on a
runtime public CDN (previously `https://unpkg.com/maplibre-gl@^5.0/dist/...`) to load the
app shell or the map component. With the assets bundled into `build/web/`, the app and map
component load and render even with no network connection; only actual basemap tiles (from
OpenFreeMap/OSM etc.) require a network and degrade gracefully.

## Pinned version

| File | Version | SHA-256 |
| --- | --- | --- |
| `maplibre-gl.js` | `5.24.0` | `45a9b07a9189ce56054c620a947ccf41e291e58c95e9b61533b740aaa65ee5cb` |
| `maplibre-gl.css` | `5.24.0` | `ab1e70d59ec40465bae7e7030da2f3ccf28133fd502e62bd598eefbadfd7a732` |
| `LICENSE.txt` | `5.24.0` | `ee5fc05a0677eaf69601d2c7db0d9ecd6cc27c3abc1d0733bc9ed34707cf8ef2` |

The `maplibre` Flutter package (0.3.5, via `maplibre_web`) binds to the global `maplibregl`
object and is distributed against MapLibre GL JS v5 (`^5.0`). We pin the exact `5.24.0`
release (the latest v5 line) and deliberately stay on the v5 major line; MapLibre GL JS v6+
is a new major that is not yet validated against `maplibre_web` 0.3.5.

## License

MapLibre GL JS is licensed under the **BSD 3-Clause License**. The full text is kept in
`LICENSE.txt` (sourced from `https://unpkg.com/maplibre-gl@5.24.0/LICENSE.txt`). See also
the project home: <https://github.com/maplibre/maplibre-gl-js>.

## How these files were produced

Run the reproducible download + checksum verification script:

```bash
node tool/update_maplibre_vendor.mjs
```

It downloads `maplibre-gl@5.24.0` JS/CSS/License from unpkg, verifies each file's SHA-256
against the checksums above (and prints an error on mismatch), and fails instead of silently
overwriting the committed assets. The script writes into `web/vendor/maplibre-gl/`.

## Upgrade procedure

1. Pick the new target version T (stay on the same major line as `maplibre_web` unless an
   upgrade of the `maplibre` package is validated first).
2. Update the `VERSION` constant and the SHA-256 checksums in
   `tool/update_maplibre_vendor.mjs` with the real hashes of `https://unpkg.com/maplibre-gl@T/...`.
3. Run `node tool/update_maplibre_vendor.mjs` and commit the regenerated files and this
   README's table.
4. Verify with `flutter build web --release` and an offline smoke test of the map page.

## Runtime wiring

`web/index.html` references both files via relative paths under `$FLUTTER_BASE_HREF`:

```html
<link href="vendor/maplibre-gl/maplibre-gl.css" rel="stylesheet"/>
<script src="vendor/maplibre-gl/maplibre-gl.js" defer></script>
```

Flutter's web build copies the entire `web/` tree (including `vendor/`) into `build/web/`,
so the assets ship with the application.
