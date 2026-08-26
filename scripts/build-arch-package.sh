#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in makepkg npm sha256sum tar; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "error: required command not found: $command" >&2
    exit 1
  fi
done

pkgver="$(awk -F '"' '/^version = "/ { print $2; exit }' src-tauri/Cargo.toml)"
pkgbuild_ver="$(awk -F= '/^pkgver=/ { print $2; exit }' packaging/arch/PKGBUILD)"
pkgrel="$(awk -F= '/^pkgrel=/ { print $2; exit }' packaging/arch/PKGBUILD)"
if [[ -z "$pkgver" || "$pkgver" != "$pkgbuild_ver" ]]; then
  echo "error: Cargo version ($pkgver) and PKGBUILD version ($pkgbuild_ver) differ" >&2
  exit 1
fi
if [[ -z "$pkgrel" ]]; then
  echo "error: pkgrel is missing from packaging/arch/PKGBUILD" >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64) carch=x86_64 ;;
  aarch64) carch=aarch64 ;;
  *)
    echo "error: unsupported Arch package architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

if [[ "${MIRIAGO_SKIP_BUILD:-0}" != 1 ]]; then
  command -v flutter >/dev/null 2>&1 || {
    echo "error: flutter is required (set MIRIAGO_SKIP_BUILD=1 to package an existing release binary)" >&2
    exit 1
  }
  npm ci
  npm run tauri -- build --no-bundle
fi

binary="src-tauri/target/release/miriago-desktop"
if [[ ! -x "$binary" ]]; then
  echo "error: release binary not found: $binary" >&2
  exit 1
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/miriago-makepkg.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
payload_dir="$work_dir/payload"
mkdir -p "$payload_dir" "$repo_root/dist/arch"

install -Dm755 "$binary" "$payload_dir/miriago-desktop"
install -Dm755 packaging/linux/miriago "$payload_dir/miriago"
install -Dm644 packaging/linux/app.miriago.desktop.desktop \
  "$payload_dir/app.miriago.desktop.desktop"
install -Dm644 LICENSE "$payload_dir/LICENSE"
install -Dm644 src-tauri/icons/32x32.png "$payload_dir/icon-32.png"
install -Dm644 src-tauri/icons/128x128.png "$payload_dir/icon-128.png"
install -Dm644 src-tauri/icons/128x128@2x.png "$payload_dir/icon-256.png"
install -Dm644 src-tauri/icons/icon.png "$payload_dir/icon-1024.png"

archive="$work_dir/MiriaGo-${pkgver}.tar.gz"
tar --sort=name \
  --mtime="@${SOURCE_DATE_EPOCH:-0}" \
  --owner=0 --group=0 --numeric-owner \
  -czf "$archive" -C "$payload_dir" .

cp packaging/arch/PKGBUILD "$work_dir/PKGBUILD"
payload_sha256="$(sha256sum "$archive" | awk '{ print $1 }')"
sed -i "s/sha256sums=('SKIP')/sha256sums=('${payload_sha256}')/" "$work_dir/PKGBUILD"

(
  cd "$work_dir"
  PKGDEST="$repo_root/dist/arch" makepkg --clean --cleanbuild --force --noconfirm
)

package_path="$(find "$repo_root/dist/arch" -maxdepth 1 -type f \
  -name "miriago-${pkgver}-${pkgrel}-${carch}.pkg.tar.*" ! -name '*.sig' -print -quit)"
if [[ -z "$package_path" ]]; then
  echo "error: makepkg completed but no package was found" >&2
  exit 1
fi

printf 'Arch package: %s\nInstall with: sudo pacman -U %q\n' \
  "$package_path" "$package_path"
