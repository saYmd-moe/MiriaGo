#!/usr/bin/env bash
#
# Build the Arch Linux pacman package for MiriaGo and generate the SHA-256
# manifest. Verification is performed by scripts/verify-arch-package.sh.
#
# Reuse this script from CI and from local releases so that the packager has a
# single source of truth (see .github/workflows/arch-package.yml). By default
# it performs a clean npm install, Flutter Web release build and Rust/Tauri
# release compile, then invokes makepkg. Set MIRIAGO_SKIP_BUILD=1 to package an
# already-built release binary without rebuilding.
#
# Optional signing (strictly opt-in): set MIRIAGO_SIGN=1 together with
# MIRIAGO_GPG_PRIVATE_KEY and MIRIAGO_GPG_FINGERPRINT to produce a detached
# .sig for the package and the SHA256SUMS manifest. The private key is imported
# into an ephemeral GNUPGHOME that is destroyed on exit and is never written to
# the repository, logs or artifact. See docs/ARCH_LINUX_RELEASE.md.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in makepkg sha256sum tar; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "error: required command not found: $command" >&2
    exit 1
  fi
done

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/miriago-makepkg.XXXXXX")"

signing=0
if [[ "${MIRIAGO_SIGN:-0}" != 0 ]]; then
  signing=1
  if [[ -z "${MIRIAGO_GPG_PRIVATE_KEY:-}" || -z "${MIRIAGO_GPG_FINGERPRINT:-}" ]]; then
    echo "error: MIRIAGO_SIGN=1 requires MIRIAGO_GPG_PRIVATE_KEY and MIRIAGO_GPG_FINGERPRINT" >&2
    exit 1
  fi
  if ! command -v gpg >/dev/null 2>&1; then
    echo "error: MIRIAGO_SIGN=1 requires gpg on PATH" >&2
    exit 1
  fi
  gnupg_home="$(mktemp -d "${TMPDIR:-/tmp}/miriago-gnupg.XXXXXX")"
  chmod 700 "$gnupg_home"
  export GNUPGHOME="$gnupg_home"
  printf '%s' "$MIRIAGO_GPG_PRIVATE_KEY" | gpg --batch --import >/dev/null 2>&1 \
    || { echo "error: failed to import GPG private key" >&2; exit 1; }
else
  gnupg_home=""
fi

trap 'rm -rf "$work_dir" "${gnupg_home:-}"' EXIT

pkgver="$(awk -F '"' '/^version = "/ { print $2; exit }' src-tauri/Cargo.toml)"
pkgbuild_ver="$(awk -F= '/^pkgver=/ { print $2; exit }' packaging/arch/PKGBUILD)"
pkgrel="$(awk -F= '/^pkgrel=/ { print $2; exit }' packaging/arch/PKGBUILD)"
pubspec_ver="$(awk '/^version:/ { sub(/^version:[[:space:]]*/, ""); sub(/\+.*/, ""); print; exit }' pubspec.yaml)"
tauri_ver="$(awk -F '"' '/^[[:space:]]*"version"[[:space:]]*:/ { print $4; exit }' src-tauri/tauri.conf.json)"
if [[ -z "$pkgver" || "$pkgver" != "$pkgbuild_ver" || "$pkgver" != "$pubspec_ver" || "$pkgver" != "$tauri_ver" ]]; then
  echo "error: version drift: Cargo=$pkgver PKGBUILD=$pkgbuild_ver pubspec=$pubspec_ver Tauri=$tauri_ver" >&2
  exit 1
fi
if [[ -z "$pkgrel" ]]; then
  echo "error: pkgrel is missing from packaging/arch/PKGBUILD" >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64) carch=x86_64 ;;
  *)
    echo "error: this Arch package currently supports x86_64 only (host: $(uname -m))" >&2
    exit 1
    ;;
esac

if [[ "${MIRIAGO_SKIP_BUILD:-0}" != 1 ]]; then
  command -v flutter >/dev/null 2>&1 || {
    echo "error: flutter is required (set MIRIAGO_SKIP_BUILD=1 to package an existing release binary)" >&2
    exit 1
  }
  command -v npm >/dev/null 2>&1 || {
    echo "error: npm is required for the Tauri build" >&2
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

payload_dir="$work_dir/payload"
rm -rf "$repo_root/dist/arch"
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

# Generate the SHA-256 manifest next to the package. CI uploads both, and a
# signed release also carries a detached signature for this manifest.
package_base="$(basename "$package_path")"
(
  cd "$repo_root/dist/arch"
  sha256sum "$package_base" > SHA256SUMS
)

printf 'Arch package: %s\n' "$package_path"
printf 'SHA256 manifest: %s\n' "$repo_root/dist/arch/SHA256SUMS"

if [[ "$signing" == 1 ]]; then
  # Detached signatures. The key lives only in the ephemeral GNUPGHOME
  # imported above; only the .sig files leave this script.
  gpg --batch --yes --armor --detach-sign \
    --local-user "$MIRIAGO_GPG_FINGERPRINT" \
    --output "$package_path.sig" "$package_path"
  gpg --batch --yes --armor --detach-sign \
    --local-user "$MIRIAGO_GPG_FINGERPRINT" \
    --output "$repo_root/dist/arch/SHA256SUMS.sig" \
    "$repo_root/dist/arch/SHA256SUMS"
  printf 'Signature: %s\n' "$package_path.sig"
  printf 'Signature: %s\n' "$repo_root/dist/arch/SHA256SUMS.sig"
fi

printf 'Install with: sudo pacman -U %q\n' "$package_path"
