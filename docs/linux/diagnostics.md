# 只读环境 / 版本诊断基础（M0）

对应 M0（第 7.1 节）「在关于或诊断信息中规划以下只读信息」。M0 只落地
**只读的数据来源**，不实现完整诊断 UI（那是 M5「系统集成」的诊断入口，见
`LINUX_UX_OPTIMIZATION_PLAN.md` 12.4）。

## 1. 提供的只读诊断

新增 Tauri 命令 `runtime_diagnostics`，返回 `RuntimeDiagnostics` 快照，字段：

| 字段 | 含义 |
| --- | --- |
| `appVersion` | MiriaGo 版本 |
| `tauriVersion` | Tauri 版本 |
| `webkitgtkVersion` | WebKitGTK 版本（Linux，`pkg-config` 探测；不可得为 `null`）|
| `sessionType` | `XDG_SESSION_TYPE`（wayland / x11）|
| `sessionDesktop` | `XDG_SESSION_DESKTOP` |
| `currentDesktop` | `XDG_CURRENT_DESKTOP`（如 KDE）|
| `display` | `DISPLAY`（X11）|
| `waylandDisplay` | `WAYLAND_DISPLAY`（Wayland）|
| `gtkUsePortal` | `GTK_USE_PORTAL` 配置 |
| `portalBackend` | 由配置推导的 portal 后端提示：`kde` / `gtk` / `unknown` |
| `dataDir` / `logsDir` | 数据目录与日志目录 |

特性：

- **只读**：只读取环境变量、目录与版本信息，不修改任何状态。
- **不发起网络或特权查询**：`portalBackend` 是基于启动时配置的提示，不是实时
  D-Bus 连通性探测——实时 portal 探测属于 M5。
- WebKitGTK 探测通过只读运行 `pkg-config --modversion`，工具或包缺失时返回
  `null` 而非报错。

## 2. 调用方式

前端通过 Tauri bridge 调用 `invoke('runtime_diagnostics')` 获取 JSON。M0 阶段
尚未接入「关于」页 UI（属 M5），命令只作为数据来源与手工验证入口。

Rust 侧可在命令行/调试中调用：

```bash
# 在具备 cargo 的环境中单元测试覆盖字段与脱敏规则：
cargo test --manifest-path src-tauri/Cargo.toml diagnostics
```

## 3. 与 M5 的边界

| 能力 | M0（本文） | M5（系统集成） |
| --- | --- | --- |
| 只读环境/版本快照 | ✅ 已提供 | 补充展示 |
| 完整「复制诊断 / 导出诊断包」UI | — | M5 实现 |
| 实时 D-Bus portal 后端探测 | — | M5 评估 |
| 日志脱敏原语 | ✅ 已提供并有测试 | 接入日志写入路径 |

M0 刻意**不**实现诊断 UI 或实时 portal 探测，避免与 M5 重复。

## 4. 验收

- ✅ 提供指定只读字段（版本、会话、数据目录、portal 提示）。
- ✅ 脱敏规则有单元测试（`diagnostics::tests`）。
- ✅ 对外部环境只读、无副作用。
