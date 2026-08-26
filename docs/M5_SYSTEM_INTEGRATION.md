# M5 系统集成实现记录

本分支实现了一个不依赖窗口状态插件的最小切片：

- `src-tauri/src/window_state.rs` 使用 Tauri 2 core window/monitor API 保存尺寸、位置和最大化状态。恢复前检查当前显示器矩形；没有交集时保留默认窗口位置，避免窗口落在已断开的显示器上。
- `tauri-plugin-single-instance` 将第二次启动的参数交给现有实例，并激活窗口。Rust 只转交实际存在且扩展名为 `.sjhplan` 的文件；通过 Tauri event 直接通知 Flutter，启动阶段只执行一次 pending queue drain，不使用永久轮询；事件到达与启动 drain 的竞态由 Flutter 去重。
- Linux desktop entry 和 Tauri bundle 注册 `application/x-miriago-sjhplan`，命令行使用 `%F`，路径不经过 shell 拼接，因此支持空格和 Unicode。
- `desktop_diagnostics` 只返回固定字段和脱敏路径；设置页支持复制和导出。它是当前 M5 对现有 M0 诊断规划的临时复用入口，后续必须合并到同一诊断模型/入口，禁止保留两套诊断实现。当前没有持久化“最近错误”日志，输出明确标记为 `not-collected`，也不伪造 WebKitGTK/Portal 版本状态。
- `notify_desktop_task` 使用官方通知插件。前端仅在 Flutter 生命周期不是 `resumed` 时调用，且 Rust/Flutter 均将通知失败视为非致命；当前已接入数据导出和完整参考图缓存完成通知。

限制与人工验证：

- 窗口最大化没有独立的 Tauri `Maximized` 事件；实现通过尺寸/位置事件读取 `is_maximized()`，并以 500ms debounce 写入状态，关闭请求时立即保存，因此需在 KDE/Wayland 上手工验证拖动、最大化、重启和显示器热插拔。
- Flutter SDK 不在系统 PATH；本环境使用 `/tmp/miriago-flutter-3.44.0/flutter/bin/flutter` 验证。若该临时 SDK 不存在，Flutter 检查属于外部阻塞。
- Dolphin/Portal 的真实双击行为、通知服务可用性和多显示器热插拔不能由无桌面 CI 完整模拟，需在 KDE Plasma Wayland/X11 手工验收。
