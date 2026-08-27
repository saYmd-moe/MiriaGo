#!/usr/bin/env bash
# Static and negative-path checks for the Arch packaging helpers.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bash -n scripts/build-arch-package.sh scripts/verify-arch-package.sh
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x scripts/build-arch-package.sh scripts/verify-arch-package.sh
else
  echo "INFO: shellcheck not installed; CI installs/uses it when available" >&2
fi

cargo_ver="$(awk -F '"' '/^version = "/ { print $2; exit }' src-tauri/Cargo.toml)"
pkg_ver="$(awk -F= '/^pkgver=/ { print $2; exit }' packaging/arch/PKGBUILD)"
pubspec_ver="$(awk '/^version:/ { sub(/^version:[[:space:]]*/, ""); sub(/\+.*/, ""); print; exit }' pubspec.yaml)"
tauri_ver="$(awk -F '"' '/^[[:space:]]*"version"[[:space:]]*:/ { print $4; exit }' src-tauri/tauri.conf.json)"
[[ "$cargo_ver" == "$pkg_ver" && "$cargo_ver" == "$pubspec_ver" && "$cargo_ver" == "$tauri_ver" ]] \
  || { echo "version drift: Cargo=$cargo_ver PKGBUILD=$pkg_ver pubspec=$pubspec_ver Tauri=$tauri_ver" >&2; exit 1; }
grep -q "^arch=('x86_64')$" packaging/arch/PKGBUILD \
  || { echo "PKGBUILD must remain explicitly x86_64-only until aarch64 evidence exists" >&2; exit 1; }
grep -q 'flutter analyze --no-pub' .github/workflows/arch-package.yml
grep -q 'bash scripts/build-flutter-web.sh --release --no-pub' .github/workflows/desktop.yml
grep -q -- '--no-web-resources-cdn' scripts/build-flutter-web.sh
grep -q 'cargo clippy --manifest-path src-tauri/Cargo.toml --locked --all-targets -- -D warnings' .github/workflows/arch-package.yml
grep -q "xdotool search --onlyvisible --name '\\^MiriaGo\\$'" scripts/verify-arch-package.sh

# Missing and empty inputs must fail; no package installation is performed.
if scripts/verify-arch-package.sh "$repo_root/scripts/does-not-exist.pkg.tar.zst" >/dev/null 2>&1; then
  echo "verify script accepted a missing package" >&2
  exit 1
fi
empty_pkg="$(mktemp)"
trap 'rm -f "$empty_pkg"' EXIT
if scripts/verify-arch-package.sh "$empty_pkg" >/dev/null 2>&1; then
  echo "verify script accepted an empty package" >&2
  exit 1
fi

printf 'Arch packaging helper tests passed (version consistency, shell syntax, negative paths).\n'
