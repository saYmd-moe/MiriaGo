# Third-Party Notices

This document records third-party assets that MiriaGo **vendors into the application** and
the ones it loads at runtime, so that (a) M3 offline reliability has a clear inventory and
(b) M6 CSP tightening has a basis. "Vendored" means the asset is committed in this
repository and ships inside `build/web/`; it does **not** require a network at runtime.

## Vendored assets

### MapLibre GL JS / CSS

| Field | Value |
| --- | --- |
| Component | MapLibre GL JS client-side bundle (`maplibre-gl.js`, `maplibre-gl.css`) |
| Version | `5.24.0` (pinned; latest on the v5 major line) |
| License | BSD 3-Clause (`web/vendor/maplibre-gl/LICENSE.txt`) |
| Upstream | <https://github.com/maplibre/maplibre-gl-js> |
| Local path | `web/vendor/maplibre-gl/` |
| SHA-256 | see `web/vendor/maplibre-gl/README.md` |
| Used by | `maplibre_web` (Flutter package `maplibre` 0.3.5) binds to the global `maplibregl` object for the Flutter Web / Tauri (Linux/macOS/Windows WebView) map component. |
| Upgrade | `node tool/update_maplibre_vendor.mjs` — see `web/vendor/maplibre-gl/README.md`. |

Why local: `web/index.html` previously loaded
a runtime public CDN.
Those two runtime CDN references were removed and replaced with local relative paths under
`$FLUTTER_BASE_HREF`. The Flutter web build copies the whole `web/` tree into `build/web/`,
so the map engine is always available locally (offline app shell + map component work; only
basemap *tiles* need a network).

## Runtime (non-vendored) network resources

These are fetched at runtime and require a network. They are intentionally **not** vendored
because they are per-user or traffic-heavy; failures degrade gracefully (see below).

| Purpose | Host / pattern | Notes |
| --- | --- | --- |
| Default basemap style (MapLibre) | `https://tiles.openfreemap.org/styles/{liberty,bright,positron,dark,fiord}` | Replaceable in settings. |
| OpenStreetMap raster tiles | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | Replaceable in settings. |
| Custom XYZ / MapLibre style | user-configured URL | Optional. |
| Reference images (Anitabi) | configured Anitabi image base URL | Cached locally; see cache management. |
| Anitabi static data / Bangumi | configured base URLs | Used for search metadata. |

Offline behavior: because the MapLibre JS/CSS ship locally, a network outage does **not**
white-screen the app or the map component. Basemap tiles simply fail to load; the map screen
surfaces a non-blocking "底图不可用" notice (see `lib/map/`). Plans, records and cached
reference images remain usable.

## Cache/asset directories (safety inventory)

These live under the application data directory root (`seichi_junrei.sqlite` at the root).

| Directory | Contents | Cleanup policy |
| --- | --- | --- |
| `reference_full` | Downloaded full-size reference images (re-fetchable). | Safe to clear (M3 cleanup entry); never touches user data. |
| `reference_thumbnails` | Downloaded thumbnail cache (re-fetchable). | Optional to clear; kept by default for speed. |
| `imported_plan_assets` | Assets restored from imported `.sjhplan` packages. | **Never** auto-cleared (not re-fetchable). |
| `user_reference_images`, `user_references` | User-provided photos / references. | **Never** cleared. |
| `visit_record_images`, `graded_photos` | User photos and graded renders for visit records. | **Never** cleared. |
| `seichi_junrei.sqlite` | Main SQLite database (plans, records, settings). | **Never** cleared. |
