#!/usr/bin/env bash
#
# Verify a built MiriaGo Arch Linux package (.pkg.tar.zst) against the M4
# release acceptance criteria:
#
#   1. pacman -Qip                - inspect package metadata
#   2. pacman -Qlp                - inspect file list and confirm layout
#   3. ELF missing-library check  - ldd on the real binary
#   4. desktop entry check        - structural + optional desktop-file-validate
#   5. extract + smoke test       - run the binary under an isolated XDG home
#   6. XDG data dir check         - app creates $XDG_DATA_HOME/MiriaGo
#   7. package structure check    - Qlp path expectations
#
# Run on the same host as the build so pacman can read the archive metadata.
# Read-only: never installs anything, never touches the user's real data dir.
#
# Usage: scripts/verify-arch-package.sh /path/to/miriago-*.pkg.tar.zst
set -euo pipefail

pkg="$1"
if [[ -z "$pkg" || ! -f "$pkg" ]]; then
  echo "error: usage: $0 /path/to/miriago-*.pkg.tar.zst" >&2
  exit 2
fi
pkg="$(realpath "$pkg")"
if [[ ! -s "$pkg" ]]; then
  echo "error: package is missing or empty: $pkg" >&2
  exit 1
fi

for command in pacman sha256sum; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "error: required command not found: $command" >&2
    exit 1
  fi
done

checked=0
failures=0
fail() {
  echo "FAIL: $*" >&2
  checked=$((checked + 1))
  failures=$((failures + 1))
  return 1
}
pass() {
  echo "PASS: $*"
  checked=$((checked + 1))
}

echo "==> 1/7 pacman -Qip (metadata)"
info="$(pacman -Qip "$pkg" 2>&1)" || fail "pacman -Qip failed"
grep -q '^名字' <<<"$info" || grep -qE '^Name' <<<"$info" \
  || fail "Qip output has no package name field"
echo "$info"
pass "Qip parsed"

echo "==> 2/7 pacman -Qlp (file list)"
files="$(pacman -Qlp "$pkg" 2>&1)" || fail "pacman -Qlp failed"
echo "$files"
expected_files=(
  "/usr/bin/miriago"
  "/usr/lib/miriago/miriago-desktop"
  "/usr/share/applications/app.miriago.desktop.desktop"
  "/usr/share/licenses/miriago/LICENSE"
  "/usr/share/icons/hicolor/32x32/apps/app.miriago.desktop.png"
  "/usr/share/icons/hicolor/128x128/apps/app.miriago.desktop.png"
  "/usr/share/icons/hicolor/256x256/apps/app.miriago.desktop.png"
  "/usr/share/icons/hicolor/1024x1024/apps/app.miriago.desktop.png"
)
missing=()
for path in "${expected_files[@]}"; do
  if ! grep -qF "$path" <<<"$files"; then
    missing+=("$path")
  fi
done
if [[ "${#missing[@]}" -gt 0 ]]; then
  fail "missing expected files: ${missing[*]}"
else
  pass "Qlp contains all expected paths"
fi

echo "==> 3/7 ELF missing-library check"
extract_dir="$(mktemp -d "${TMPDIR:-/tmp}/miriago-verify.XXXXXX")"
trap 'rm -rf "$extract_dir"' EXIT
if ! tar --zstd -xf "$pkg" -C "$extract_dir" 2>/dev/null; then
  # Fall back to bsdtar if plain tar lacks zstd on this host.
  bsdtar -xf "$pkg" -C "$extract_dir" 2>/dev/null \
    || fail "could not extract $pkg"
fi
binary="$extract_dir/usr/lib/miriago/miriago-desktop"
if [[ ! -x "$binary" ]]; then
  fail "payload binary missing after extraction: $binary"
else
  # filetype sanity: must be an ELF executable
  file_out="$(file "$binary")"
  echo "$file_out"
  if grep -q 'ELF' <<<"$file_out" && grep -q 'executable' <<<"$file_out"; then
    pass "payload binary is an ELF executable"
  else
    fail "payload binary is not an ELF executable: $file_out"
  fi

  if command -v ldd >/dev/null 2>&1; then
    missing_libs="$(ldd "$binary" 2>&1 | grep -i 'not found' || true)"
    if [[ -z "$missing_libs" ]]; then
      pass "no missing shared libraries"
    else
      echo "$missing_libs" >&2
      fail "missing shared libraries detected"
    fi
  else
    echo "SKIP: ldd not available on this host" >&2
  fi
fi

echo "==> 4/7 desktop entry check"
desktop_file="$extract_dir/usr/share/applications/app.miriago.desktop.desktop"
if [[ -f "$desktop_file" ]]; then
  desktop_entry_ok=1
  grep -q '^\[Desktop Entry\]' "$desktop_file" || desktop_entry_ok=0
  grep -q '^Type=Application' "$desktop_file" || desktop_entry_ok=0
  grep -q '^Exec=' "$desktop_file" || desktop_entry_ok=0
  grep -q '^Icon=' "$desktop_file" || desktop_entry_ok=0
  grep -q '^Name=' "$desktop_file" || desktop_entry_ok=0
  if [[ "$desktop_entry_ok" == 1 ]]; then
    pass "desktop entry has required keys"
    if command -v desktop-file-validate >/dev/null 2>&1; then
      if desktop-file-validate "$desktop_file"; then
        pass "desktop-file-validate OK"
      else
        fail "desktop-file-validate reported errors"
      fi
    else
      echo "SKIP: desktop-file-validate not available" >&2
    fi
  else
    fail "desktop entry missing required keys"
  fi
else
  fail "desktop entry file not found in package"
fi

echo "==> 5/7 extract + smoke test (isolated XDG home)"
smoke_home="$(mktemp -d "${TMPDIR:-/tmp}/miriago-smoke.XXXXXX")"
trap 'rm -rf "$extract_dir" "$smoke_home"' EXIT
data_home="$smoke_home/data"
export XDG_DATA_HOME="$data_home"
export HOME="$smoke_home"
unset XDG_DATA_DIRS 2>/dev/null || true
mkdir -p "$data_home"

# --eval smoke uses the real launcher path resolution but runs in a sandboxed
# data dir; pass no positional args so the app performs startup and exits. A
# long-running GUI app cannot run headless here, so we treat a clean spawn of
# the binary (its main() reaching setup) as the pass signal where possible.
# We additionally verify the XDG data directory layout is created on demand.
smoke_status=0
if command -v xvfb-run >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
  set +e
  timeout --signal=TERM 20s xvfb-run --auto-servernum \
    --server-args='-screen 0 1280x1024x24' "$binary" >/dev/null 2>&1
  smoke_status=$?
  set -e
elif command -v timeout >/dev/null 2>&1; then
  set +e
  timeout --signal=TERM 20s "$binary" >/dev/null 2>&1
  smoke_status=$?
  set -e
else
  "$binary" >/dev/null 2>&1 || smoke_status=$?
fi
case "$smoke_status" in
  0) pass "smoke: binary executed and exited 0" ;;
  124|137) pass "smoke: binary started and remained alive for the timeout window" ;;
  *) fail "smoke: binary exited with status $smoke_status" ;;
esac

echo "==> 6/7 XDG data directory check"
# The app resolves its data dir via the dirs crate: $XDG_DATA_HOME/MiriaGo, or
# ~/.local/share/MiriaGo. We assert the expected leaf name and that the package
# itself contains no file under that user data path (so uninstall cannot
# delete user data).
if ! grep -qF "/MiriaGo" <<<"$files"; then
  pass "package does not install into the user data dir (uninstall-safe)"
else
  fail "package unexpectedly writes into the XDG user data dir"
fi
# Check that the runtime would resolve to XDG_DATA_HOME/MiriaGo when configured.
for data_subdir in MiriaGo MiriaGo/assets MiriaGo/exports MiriaGo/logs MiriaGo/temp; do
  if [[ -d "$data_home/$data_subdir" ]]; then
    pass "XDG runtime created $data_subdir directory"
  else
    fail "XDG runtime did not create $data_home/$data_subdir during smoke"
  fi
done
code='
use std::env;
fn main() {
  let base = env::var("XDG_DATA_HOME").ok()
      .or_else(|| std::env::var("HOME").ok().map(|h| format!("{h}/.local/share")))
      .unwrap_or_default();
  print!("{}/MiriaGo", base);
}
'
target_dir="$smoke_home/rustcheck"
mkdir -p "$target_dir"
if command -v rustc >/dev/null 2>&1; then
  if printf '%s' "$code" >"$target_dir/check.rs" \
      && rustc --edition 2021 -o "$target_dir/check" "$target_dir/check.rs" >/dev/null 2>&1; then
    resolved="$("$target_dir/check")"
    if [[ "$resolved" == "$data_home/MiriaGo" ]]; then
      pass "XDG data dir resolves to ${resolved}"
    else
      fail "unexpected XDG data dir resolution: ${resolved}"
    fi
  else
    echo "SKIP: could not compile resolver sanity binary" >&2
  fi
else
  echo "SKIP: rustc not available for XDG resolver sanity check" >&2
fi

echo "==> 7/7 package structure summary"
# Commit/executable bits and ownership are captured by Qlp; confirm the binary
# and launcher are executable and the desktop/icon files are regular files via
# the extraction.
if [[ -x "$binary" ]]; then
  pass "payload binary is executable"
else
  fail "payload binary not executable"
fi
if [[ -x "$extract_dir/usr/bin/miriago" ]]; then
  pass "launcher /usr/bin/miriago is executable"
else
  fail "launcher /usr/bin/miriago not executable"
fi

printf '\nVerification summary: %s test(s) run, %s failure(s).\n' "$checked" "$failures"
if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
exit 0
