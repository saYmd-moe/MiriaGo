# 日志脱敏规则

对应 M0（第 7.1 节）「明确日志脱敏规则，不记录 Token、私密 URL 参数、照片内容
或不必要的完整用户路径」。

本文定义的规则同时是 `src-tauri/src/diagnostics.rs` 中 `redact_for_log`
的实现依据，并配有 Rust 单元测试。未来所有写入日志的输出都必须经过脱敏。

## 1. 必须脱敏的内容

| 类别 | 示例 | 处理 |
| --- | --- | --- |
| URL 用户信息（凭据） | `https://user:pass@host/...` | 替换为 `https://***@host/...` |
| 敏感查询参数 | `?token=abc123&key=xyz` | 值替换为 `[REDACTED]` |
| 私有网络 / 内部主机 | `localhost`、`10.x`、`192.168.x` | 仅供诊断时提示，不记录完整 URL |
| 完整用户主目录路径 | `/home/alice/.local/share/MiriaGo` | 缩写为 `~/.local/share/MiriaGo` |
| 照片 / 图片内容 | 图片二进制、base64 | 一律不写入日志 |
| 访问令牌 / 密钥 | API key、client secret | 值替换为 `[REDACTED]` |

## 2. 敏感参数键名

以下键的取值在查询串或参数中一律脱敏（大小写不敏感）：

`token`、`access_token`、`refresh_token`、`api_key`、`apikey`、`key`、
`password`、`passwd`、`pwd`、`secret`、`authorization`、`signature`、
`sig`、`client_secret`。

## 3. 路径处理

- 应用内数据目录在诊断信息中允许以 `~` 缩写形式展示（用于定位问题），但
  **不**写入错误日志的完整形式之外的部分。
- 用户照片、导入资源的绝对路径不应出现在日志正文；必要时应只保留“目录 + 相对
  文件名”。

## 4. 网络信息

- 地图瓦片、图片请求是常规网络行为，可能暴露 IP、地图源域名；这些在诊断中
  可做一般性说明，但**不**记录带凭据的完整 URL。
- 私密或带参数的 URL（含会话/令牌）必须按第 2 节脱敏。

## 5. 实现与测试

- 实现：`src-tauri/src/diagnostics.rs::redact_for_log`（及其
  `redact_for_log_with_home` 确定性变体）。
- 测试覆盖：URL 凭据、查询参数、password/api_key、主目录缩写。
- 规则维护：新增敏感键名时同步更新 `SENSITIVE_PARAMS` 与本文第 2 节，并补充
  单元测试。

## 6. 未来接入

M0 阶段脱敏原语已就绪但尚未被日志写入路径调用（避免与 M5 诊断入口重叠）。
后续里程碑接入日志系统时：

1. 所有写入点先调用 `redact_for_log`。
2. 日志系统默认不记录照片内容与完整用户路径。
3. 完善后为本文件增加「已接入模块」清单。
