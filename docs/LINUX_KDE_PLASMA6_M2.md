# KDE Plasma 6 / Linux M2 手工验证

本文件是可执行的手工矩阵，不是人工结果记录。每次候选构建都应在实际 KDE 会话中填写“结果”和证据路径；未执行的项目保持 `未执行`，不得推断为通过。

## 运行前记录

```bash
uname -a
printf 'session=%s desktop=%s desktop_session=%s\n' \
  "$XDG_SESSION_TYPE" "$XDG_CURRENT_DESKTOP" "$XDG_SESSION_DESKTOP"
command -v miriago
pkg-config --modversion gtk+-3.0 webkit2gtk-4.1
systemctl --user --no-pager status xdg-desktop-portal xdg-desktop-portal-kde xdg-desktop-portal-gtk
```

记录 Plasma、KWin、WebKitGTK、GTK、显卡驱动、显示器型号/分辨率/缩放和 fcitx5 版本。不要把完整私密路径、Token 或计划内容写入报告。

## 矩阵

每个组合至少覆盖一次核心流程：创建计划、地图、中文输入、打开/保存/取消文件对话框、Unicode 路径、外链和重启。

| 编号 | 会话 | 缩放/显示器 | 输入/主题 | 操作与预期 | 结果/证据 |
| --- | --- | --- | --- | --- | --- |
| A1 | Wayland | 单屏 100% | fcitx5 中文、Breeze 浅色 | 菜单启动；任务栏图标、窗口和 Alt+Tab 使用 MiriaGo 图标；搜索/表单/Markdown 组合输入和回车确认正常 | 未执行 |
| A2 | Wayland | 单屏 125% | 英文、Breeze 浅色 | 文本、图标、地图清晰；点击、滚轮、拖放无偏移 | 未执行 |
| A3 | Wayland | 单屏 150% | fcitx5 中文、Breeze 深色 | 候选窗跟随输入位置；输入焦点、快捷键、地图手势正常；界面和地图控件可读 | 未执行 |
| A4 | Wayland | 单屏 200% | 英文、Breeze 深色 | 启动、核心流程和文件对话框无裁切/模糊/偏移 | 未执行 |
| A5 | Wayland | 双屏：100% + 150% | 中文、浅色 | 将窗口在屏间来回移动；尺寸、点击坐标、地图手势和任务栏关联保持正确 | 未执行 |
| A6 | Wayland | 双屏：125% + 200% | 中文、深色 | 重复 A5，并最大化/还原；不得跳到已断开的显示器 | 未执行 |
| B1 | X11 | 单屏 100%/125% | 英文、浅色 | 重复启动、任务栏、Alt+Tab、窗口菜单和外链 | 未执行 |
| B2 | X11 | 单屏 150%/200% | 中文、深色 | 重复缩放、输入、地图和文件对话框检查 | 未执行 |
| C1 | Wayland/X11 | 任一 | 中文 | Portal 打开文件：选择含空格、中文、日文和特殊字符的 `.sjhplan`/图片路径；应用收到相同 Unicode 路径 | 未执行 |
| C2 | Wayland/X11 | 任一 | 中文 | Portal 保存文件；保存、覆盖确认、取消各执行一次；扩展名和 Unicode 文件名正确 | 未执行 |
| C3 | Wayland/X11 | 任一 | 中文 | 从 Dolphin/命令行打开外链；浏览器、地图应用由桌面默认关联处理，应用不崩溃 | 未执行 |
| C4 | Wayland/X11 | 任一 | 中文 | 重启应用并重复 C1/C2；确认数据目录未被覆盖 | 未执行 |

## 应用 ID、图标和 desktop entry 检查

代码配置的固定关联为：Tauri `identifier=app.miriago.desktop`、`enableGTKAppId=true`、desktop entry `StartupWMClass=app.miriago.desktop`、`Icon=app.miriago.desktop`。Tauri/tao 将 identifier 作为 GTK application ID；Arch 包安装同名 hicolor 图标。仍需在 A1/B1 通过任务栏/Alt+Tab 实际确认。

```bash
desktop-file-validate packaging/linux/app.miriago.desktop.desktop
# 构建 deb 后检查实际入口和图标名：
dpkg-deb -e path/to/*.deb /tmp/miriago-deb-control
sed -n '1,120p' /tmp/miriago-deb-control/*.desktop 2>/dev/null || true
```

## Portal、诊断和外部阻塞

`GTK_USE_PORTAL` 只在 KDE 且用户未显式设置时由应用设置为 `1`。`launcher_info` 只读取并返回 `XDG_CURRENT_DESKTOP`、`XDG_SESSION_TYPE` 和 `GTK_USE_PORTAL`；这些是环境诊断，不代表 Portal 服务已经成功完成一次对话框操作。Portal 可用性以 C1/C2 的实际结果为准。

如果缺少 KDE Plasma 会话、第二台不同缩放显示器、fcitx5、Portal 后端或特定显卡，应记录为外部阻塞，并附命令输出；不得将未执行项目写成通过。

## 非默认图形驱动规避

默认 `miriago` launcher、desktop entry、Tauri 配置和 CI **不**设置 `WEBKIT_DISABLE_DMABUF_RENDERER`。仅在确认 WebKitGTK/驱动 DMABUF 问题后显式运行：

```bash
miriago-legacy-drivers
# 或测试未安装的二进制：
MIRIAGO_LEGACY_BIN=/path/to/miriago-desktop miriago-legacy-drivers
```

该变量只存在于这个进程及其子进程。报告必须包含复现条件、GPU/驱动/WebKitGTK 版本、默认启动与 workaround 启动的对照结果；没有证据时不要使用该启动器。
