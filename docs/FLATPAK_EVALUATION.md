# Flatpak 独立评估（不阻塞 M4）

Flatpak 不属于本次 Arch pacman 发布门禁。后续评估应单独验证：

- WebKitGTK 与 Portal 在沙箱中的启动和文件选择。
- 网络权限与外链 `xdg-open` 行为。
- `.sjhplan` 导入/导出和用户图片访问权限。
- `$XDG_DATA_HOME/MiriaGo` 在沙箱中的实际路径、备份和迁移。
- KDE Plasma、Wayland、主题和分数缩放。

评估产物应包括 manifest、权限解释、最小可运行包和手工回归结果；在权限边界、数据迁移和维护成本明确前，不将 Flatpak 加入正式发行矩阵。
