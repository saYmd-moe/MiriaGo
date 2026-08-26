# MiriaGo Linux M0：基线、测试矩阵与诊断准备

本目录记录里程碑 M0 的产物与基线状态，对应主工作树中的
`docs/LINUX_UX_OPTIMIZATION_PLAN.md` 第 7 节。
后续里程碑（M1–M6）以此为基线。

## 目录

| 文档 | 内容 |
| --- | --- |
| [`benchmark-scale.md`](benchmark-scale.md) | 可重复的启动/核心页面测量方法与空/中/大数据规模定义 |
| [`manual-test-matrix.md`](manual-test-matrix.md) | Linux 手工测试矩阵（必测组合 + 检查项 + 回归流程）|
| [`issue-report-template.md`](issue-report-template.md) | 故障记录模板（版本/桌面/协议/缩放/日志）|
| [`log-redaction.md`](log-redaction.md) | 日志脱敏规则 |
| [`diagnostics.md`](diagnostics.md) | 只读环境/版本诊断基础（M0 范围与 M5 边界）|

## 脚本

| 脚本 | 用途 | 状态 |
| --- | --- | --- |
| [`scripts/measure-linux-performance.sh`](../../scripts/measure-linux-performance.sh) | 可重复启动测量（冷/热启动）| 结构就绪，环境阻塞 |
| [`scripts/inspect-plan-scale.sh`](../../scripts/inspect-plan-scale.sh) | 只读统计数据规模 | 就绪 |
| 源码 [`src-tauri/src/diagnostics.rs`](../../src-tauri/src/diagnostics.rs) | 只读诊断 + 日志脱敏原语 | 已实现并有测试 |

## M0 验收对照

| 验收标准 | 结果 |
| --- | --- |
| 可重复的启动与核心页面性能测量方法 | ✅ 启动脚本；地图页测量为手工协议（插桩归 M3）|
| 测试矩阵每个必测组合有 通过/失败/阻塞 状态 | ✅ 结构与状态约定；当前全部为未测/阻塞（环境阻塞）|
| 发现问题时能提供版本、桌面环境、协议、缩放、日志 | ✅ issue 模板 + `runtime_diagnostics` |
| 后续性能目标以基线为依据，无 >10% 无解释退化 | ✅ 基线方法与规模定义就绪；数值待图形环境采集 |

## 基线状态与风险

- **数值基线尚未采集（blocked）**：编写提交所用环境无图形会话、无 KDE、无窗口
  检测工具、无 Flutter，因此冷/热启动与地图页耗时的实际数值未生成，未伪造数据。
- 需在有图形桌面的 Linux 机（首选 KDE Plasma Wayland）执行
  `measure-linux-performance.sh` 并在有交互会话时逐项更新测试矩阵。
- 地图页/大型计划耗时的自动化依赖 M3 的 Flutter trace 插桩，在此之前为手工
  协议。
- 实时 portal D-Bus 探测与完整诊断 UI 归 M5，M0 不实现（避免重叠）。
