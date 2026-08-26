# M0 性能基线与数据规模定义

本文是里程碑 M0（基线、测试矩阵与诊断准备）的一部分，对应主工作树中的
`docs/LINUX_UX_OPTIMIZATION_PLAN.md` 第 7 节。

内容：可重复的 Linux 启动与核心页面性能测量方法，以及空 / 中 / 大数据规模
定义，用于为后续（M3 性能优化）建立回归基线。

## 1. 测量原则

- 测量必须**可重复**：同一环境、同一二进制、同一数据规模下多次运行应得到
  接近的结果。
- 每次测量**记录环境**（会话类型、桌面环境、显示协议、缩放、数据规模），
  否则数字无法跨环境比较。
- **不伪造数字**：外部不可测的项目（例如进入地图页的真实耗时）在没有应用内
  Flutter trace 插桩前记为 `NOT_MEASURED`，而不是给出估计值。
- 所有测量对外部真实环境只读，不修改用户数据或系统状态。

## 2. 启动性能测量

### 2.1 工具

脚本 `scripts/measure-linux-performance.sh` 提供可重复的启动测量：

```bash
MIRIAGO_BIN=src-tauri/target/release/miriago-desktop \
  ./scripts/measure-linux-performance.sh
```

该脚本外部测量：

- **冷启动**：使用隔离的 `XDG_DATA_HOME` 启动，记录「进程启动 → 窗口首次
  出现」的墙钟时间。
- **热启动**：复用已准备的数据目录重新启动，记录同样的墙钟时间。

窗口检测说明：

- X11 下优先用 `xdotool search --sync --onlyvisible`。
- Wayland 下没有统一的窗口检测工具；当检测器不可用时，脚本将结果记为
  `NOT_MEASURED`，**不会**给出估计值。在 KDE Plasma Wayland 上可临时为
  该项目补齐对应合成器的检测（见脚本内 `detect_window_tool`）。

### 2.2 目前无法外部自动测量的项目

- **进入地图页耗时**：需要应用内 Flutter 插桩记录「主页面 → 地图页首帧」。
- **大型计划加载耗时**：需要应用内插桩记录「点选计划 → 列表/地图就绪」。

这两项属于 M3 性能优化范围（增加 trace 插桩）。在此之前使用下面的手工协议，
并在记录中明确标注为手工测量，而不是自动基线。

### 2.3 手工测量协议（地图页 / 大型计划）

在没有插桩时，用手表和固定的操作脚本测量，每个场景做 3 次取中位数：

1. 用 `scripts/inspect-plan-scale.sh` 记录当前数据规模（空/中/大），填入
   记录。
2. 冷启动应用（隔离 `XDG_DATA_HOME`），计时「出现首屏 → 进入地图页首帧」。
3. 打开指定规模的计划，计时「计划打开 → 地图与点位聚合完成可见」。
4. 记录桌面向导、显示协议、缩放，以及是否联网。

每次结果写入 `docs/linux/benchmarks/` 下的 Markdown，带时间戳与 commit。

## 3. 数据规模定义

`scripts/inspect-plan-scale.sh` 只读统计数据库中的数量，并输出规模分类。
规模定义如下（按点位与巡礼记录数划分）：

| 规模 | plans | works | points | visit_records | cached refs | 用途 |
| --- | --- | --- | --- | --- | --- | --- |
| empty（空） | 0 | 0 | 0 | 0 | 0 | 全新数据库，检查空态与首次启动 |
| small（小） | ≥1 | ≤5 | <50 | <10 | <50 | 日常小计划 |
| medium（中） | ≥1 | 5–20 | 50–999 | 10–99 | 50–499 | 常见完整计划 |
| large（大） | ≥1 | >20 | ≥1000 | ≥100 | ≥500 | 压力/回归测试 |

说明：

- `cached refs` 指 `points.reference_full_image_path` 非空的完整参考图数量。
- large 门槛（≥1000 点位或 ≥100 巡礼记录）用于触发聚合、增量渲染等 M3 优化
  路径，并作为「不超过 10% 无解释退化」的回归基准规模。

### 3.1 使用示例

针对默认数据目录：

```bash
./scripts/inspect-plan-scale.sh
# database: /home/you/.local/share/MiriaGo/miriago.sqlite
# points: 1240
# scale_class: large
```

针对指定数据库：

```bash
./scripts/inspect-plan-scale.sh /tmp/miriago-cold/run-1/MiriaGo/miriago.sqlite
```

## 4. 验收对照

| 验收项 | 状态 |
| --- | --- |
| 可重复的启动测量方法 | 见 `scripts/measure-linux-performance.sh` 与 2.1 |
| 可重复的核心页面手册测量方法 | 见 2.3（插桩前为手工协议，属 M3） |
| 空/中/大定义 | 见第 3 节 |
| 测量记录可追溯到环境与规模 | 每次记录写入 `docs/linux/benchmarks/` |

## 5. 现状记录（M0 落地时）

- 本机环境 `flutter` 与窗口检测工具（`xdotool`/`wmctrl`）不可用，因此本节所
  述的冷/热启动与地图页耗时的**实际数值**尚未采集，属环境阻塞，记为
  `blocked`，不伪造数据。
- 脚本与定义本身已通过 shell 语法检查；启动测量需在具备图形会话与 release
  二进制的 Linux 桌面上执行。
- 后续 M3 增加 Flutter trace 插桩后，将把地图页/大型计划从手工协议升级为
  自动测量。
