#!/usr/bin/env bash
# Build Flutter Web for Tauri with local CanvasKit resources.
# Flutter 3.44 still embeds a CDN fallback string in flutter_bootstrap.js even
# with --no-web-resources-cdn; normalize that generated fallback so the strict
# Tauri CSP cannot later select a remote engine URL.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

flutter build web "$@" --no-web-resources-cdn
bootstrap="build/web/flutter_bootstrap.js"
if [[ ! -f "$bootstrap" ]]; then
  echo "error: missing generated $bootstrap" >&2
  exit 1
fi
sed -i 's#https://www\.gstatic\.com/flutter-canvaskit#canvaskit#g' "$bootstrap"
bash scripts/verify-flutter-web-resources.sh
