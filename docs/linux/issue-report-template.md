# Linux 故障记录模板

用于报告 MiriaGo Linux 桌面端问题。填满本模板即可满足 M0 验收要求中的
「发现问题时能够提供版本、桌面环境、显示协议、缩放和日志信息」。

> 粘贴前请先按 `log-redaction.md` 脱敏，不要包含 Token、私密 URL 参数、
> 照片内容或不必要的完整用户路径。诊断信息中的路径建议用 `~` 缩写。

---

## 标题

一句话，包含问题现象与所在页面/流程。

## 环境

| 项 | 值 |
| --- | --- |
| MiriaGo 版本 | _{来自下载/打包版本，非页面展示推测}_ |
| 提交 SHA | _{发生问题的 commit;若有}_ |
| 构建类型 | AppImage / deb / pacman / `tauri dev` |
| 操作系统 / 发行版 | 例：Arch Linux, kernel 6.x |
| 桌面环境 | KDE Plasma 6.x / GNOME / 其他 |
| 显示协议 | Wayland / X11 |
| 缩放 | 100% / 125% / 150% / 200% / 分数缩放 |
| 显示器 | 单 / 双（含不同缩放组合）|
| 输入法 | fcitx5 / ibus / 无 |
| 显卡 | Intel / AMD / NVIDIA 型号与驱动 |
| WebKitGTK 版本 | _{来自 `runtime_diagnostics`}_ |
| Tauri 版本 | _{来自 `runtime_diagnostics`}_ |

## 数据规模

粘贴 `scripts/inspect-plan-scale.sh` 输出（plans/works/points/records/
scale_class）。

## 操作步骤

1. ...
2. ...
3. ...

## 预期行为

...

## 实际行为

- 现象描述。
- 是否可复现：必现 / 偶发（概率） / 无法复现。
- 首次出现时间（可选）。

## 日志与错误

- 应用日志（脱敏后）。日志目录见 `runtime_diagnostics.logsDir`。
- 相关 `dmesg` / `journalctl` 片段（脱敏后）。
- 控制台或崩溃信息，若有。

## 诊断信息

粘贴 `runtime_diagnostics` 返回的只读快照（脱敏后）。获取方式：见
`docs/linux/diagnostics.md`。

## 影响与优先级

- 影响范围：启动 / 地图 / 导入导出 / 输入法 / 文件对话框 / 其他。
- 严重度：阻断 / 高 / 中 / 低；是否影响数据安全（是/否）。

## 检查清单

- [ ] 已在脱敏后提交日志与诊断。
- [ ] 已记录桌面环境、显示协议、缩放。
- [ ] 已确认数据规模。
- [ ] 未包含 Token、私密 URL 参数、照片内容。
