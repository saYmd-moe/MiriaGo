# Linux Tauri CSP 资源审计（M6）

本清单只覆盖 Flutter Web 在 Tauri WebView 中实际加载的资源；Rust `reqwest` 请求不受 WebView CSP 直接限制，但仍必须经过 Rust 校验。

| 类型 | 默认/已知来源 | 实际路径 | CSP 处理 |
| --- | --- | --- | --- |
| Flutter 应用脚本、构建资源 | 应用自身 | `flutter_bootstrap.js`、`build/web/assets/**` | `script-src 'self'`、`default-src 'self'` |
| Flutter WASM | 应用自身 | CanvasKit/Skwasm | `script-src 'wasm-unsafe-eval`；`worker-src 'self' blob:` |
| MapLibre JS/CSS（已 vendor） | 应用自身 | `web/vendor/maplibre-gl/`、`web/index.html` | `script-src 'self'`、`style-src 'self'` |
| OpenFreeMap style/tiles | `tiles.openfreemap.org` | 默认 MapLibre style URL 及 style 引用的 tiles/sprites/glyphs | `connect-src https:`，默认域名固定记录于 `lib/config/csp_config.dart` |
| OpenStreetMap XYZ | `tile.openstreetmap.org` | `TileLayer.urlTemplate` | `connect-src https:` |
| Bangumi API | `api.bgm.tv` | `BangumiApiClient` 的搜索 POST | `connect-src https:` |
| Anitabi 静态 JSON | `ww.anitabi.cn` 默认 | Tauri 下经 `fetch_anitabi_static_json` 由 Rust `reqwest` 获取；纯 Web 使用同源 proxy | Rust `safe_public_https_base_url`；不因 CSP 放宽任意脚本 |
| Anitabi 图片 | `image.anitabi.cn`、`img-tc.anitabi.cn` | `AnitabiNetworkImage` / `Image.network` | `img-src` 显式记录并允许 `data:`、`blob:` |
| Bangumi 封面、用户参考图 | API 返回或用户输入的 HTTPS URL | `Image.network`、导出/查看器网络读取 | `img-src https:`；不能静态枚举用户内容源 |
| 本地桌面图片 | 应用数据目录 | Tauri `read_asset` 返回 data URL | `img-src data:`；Rust 路径校验 |
| 外链 | Google Maps、Anitabi、OpenStreetMap 等 | `open_external_url` → `xdg-open` | 不在 WebView 导航；Rust 仅允许公开 HTTP(S) |

## Flutter Web 构建约束

Tauri 桌面开发、production、桌面 CI 和 Arch 打包统一调用 `scripts/build-flutter-web.sh`；该脚本固定使用 `--no-web-resources-cdn`，并在生成后执行 `scripts/verify-flutter-web-resources.sh`。Flutter 3.44 的 loader 代码可能在未选中的 fallback 分支中保留 `www.gstatic.com/flutter-canvaskit` 字面量；这不是活动资源路径，不应通过修改 Flutter 生成的 bootstrap 来消除。审计以活动 `builds` 配置的 `useLocalCanvasKit":true`、bootstrap 的本地 `canvaskit.js` 引用，以及非空 `build/web/canvaskit/canvaskit.js` 为准。这样不会放宽 Tauri CSP，也不会把普通 fetch 与 module import 混为一谈。

## 分阶段策略

1. **M6 当前阶段**：收紧脚本、对象、frame、base、worker、字体和 scheme；默认地图、Bangumi、Anitabi 图片可用。`connect-src`/`img-src` 允许 HTTPS，是因为自定义地图源和用户图片源是产品能力，无法用静态域名白名单覆盖。
2. **自定义地图源限制**：自定义 XYZ 和 MapLibre style 仍须是 `http(s)` 且格式有效；`http://` 在桌面 CSP 中会被拦截，设置页明确提示改用 `https://`，不会静默回退为默认源。无效 URL 继续显示已有格式错误。
3. **M3 已完成**：MapLibre JS/CSS 位于 `web/vendor/maplibre-gl/`。`script-src` 和 `style-src` 仅允许应用自身（另保留必要的 WASM 与 Flutter inline style）；不需要 CDN 可用性测试或网络依赖。
4. **后续进一步收紧**：若产品最终放弃任意 HTTPS 图片/地图源，可将 `https:` 改成显式 host 列表；在此之前这样做会静默破坏用户配置，因此不在 M6 强行执行。

## Tauri invoke 最小能力审计

`main.rs` 注册的 command 均对应 `tauri_bridge_web.dart` 的现有业务调用：启动/目录、SQLite 桌面状态、导入导出、资产读写、Anitabi 静态 JSON 和外链。没有新增命令或生命周期逻辑。`capabilities/default.json` 仅启用 `core:default`，没有 shell、fs、http 或任意窗口权限；外链和文件系统访问都走上述 Rust command 的显式校验。

## Rust 边界

- 外链：只允许公开 `http`/`https`，拒绝 `file:`、`javascript:`、认证信息、localhost、环回、私网、链路本地和 ULA 地址。
- Anitabi base URL：只允许无认证、无 query/fragment 的公开 HTTPS base URL；文件名和版本参数有格式限制。
- 资产导入/读写：只允许 `assets/` 下的相对路径，拒绝绝对路径、反斜杠、空段、`.`、`..`。
- 导出路径：沿用文件对话框结果和已有扩展名逻辑；后续可独立收紧为受控 exports 目录，不在本 M6 CSP 变更中扩大范围。
