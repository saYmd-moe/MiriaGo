# Arch Linux 发布与 CI（M4）

`.github/workflows/arch-package.yml` 在干净的 `archlinux/archlinux:base-devel` 容器中执行构建。工作流会记录构建时的 Arch 包版本，检查 Cargo、Tauri、Flutter pubspec 与 PKGBUILD 版本一致，并复用：

```bash
./scripts/build-arch-package.sh
./scripts/verify-arch-package.sh dist/arch/miriago-*.pkg.tar.zst
```

构建脚本会清理 `dist/arch`，生成唯一的 `.pkg.tar.zst` 和 `SHA256SUMS`。当前 PKGBUILD 与 CI 仅声明并构建 `x86_64`；在取得真实 aarch64 构建证据前不会宣称支持 aarch64。缺失、空产物、版本漂移或验证失败都会使 job 失败。验证包括 `pacman -Qip`、`pacman -Qlp`、ELF `ldd` 缺库检查、desktop entry、提取后启动烟测、XDG 数据目录和包结构检查。CI 使用 Xvfb；本地验证不安装包、不执行 `pacman -U`。

本地只读/静态检查：

```bash
bash -n scripts/*.sh
shellcheck -x scripts/*.sh
./scripts/test-arch-package.sh
```

本地构建需要 Arch 的 `base-devel`、Flutter、Node/Tauri 依赖。桌面构建统一经 `scripts/build-flutter-web.sh` 使用 `--no-web-resources-cdn`，并由 `scripts/verify-flutter-web-resources.sh` 确认活动构建配置使用仓库内 CanvasKit；Flutter loader 中可能保留未选中的 gstatic fallback 字面量，不作为失败条件。安装或卸载包属于人工操作，不应由测试脚本自动 `sudo`。

## Artifact 与 Release

CI artifact 和 tag Release 附件包含：

- `miriago-*.pkg.tar.zst`
- `SHA256SUMS`
- 可选的 `.sig`

发布前可用 `sha256sum -c SHA256SUMS` 校验。Release 附件只在 `v*` tag 上传；普通 push 只产生 Actions artifact。

## 可选 GPG 签名

签名默认关闭。维护者若在 GitHub Secrets 中同时配置 `MIRIAGO_GPG_PRIVATE_KEY` 和 `MIRIAGO_GPG_FINGERPRINT`，CI 才会启用签名。脚本将私钥导入临时 `GNUPGHOME`，生成包和 `SHA256SUMS` 的 ASCII-armored detached signature，然后在退出时删除临时目录。私钥不会写入仓库、日志或 artifact；不要在本地测试中提供真实私钥。只配置其中一个 secret 会明确失败，而不是生成未声明的签名。

正式启用前应在专用维护者流程中确认指纹、备份、轮换和撤销策略；本分支不生成或操作真实密钥。

## 当前限制

Arch CI 使用官方日期标签 `archlinux/archlinux:base-devel-20260824.0.579059` 作为固定的干净构建基线，避免使用 rolling `base-devel` 标签；每次 CI 仍保存 `arch-package-baseline.txt` 作为实际工具链和仓库包版本证据。本次仅固定日期标签，不声称已验证 registry digest。若项目需要位级可复现构建，应由维护者另行验证并提交镜像 digest，或引入 Arch Linux Archive 快照。

真实图形 WebKitGTK 启动、KDE/Wayland、Portal、升级/卸载后用户数据保留仍需 CI 之外的环境验证。CI 不安装 pacman 包到 runner，也不测试真实用户数据目录。
