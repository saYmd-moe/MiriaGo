#!/usr/bin/env bash
# Verify that a Flutter Web build is self-contained for the Tauri desktop shell.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bootstrap="build/web/flutter_bootstrap.js"
local_canvaskit="build/web/canvaskit/canvaskit.js"
if [[ ! -s "$bootstrap" ]]; then
  echo "error: missing or empty $bootstrap" >&2
  exit 1
fi
if [[ ! -s "$local_canvaskit" ]]; then
  echo "error: missing or empty $local_canvaskit" >&2
  exit 1
fi
if ! grep -Fq 'canvaskit.js' "$bootstrap"; then
  echo "error: Flutter bootstrap does not reference local canvaskit.js" >&2
  exit 1
fi
if ! grep -Fq 'useLocalCanvasKit":true' "$bootstrap"; then
  echo "error: Flutter build config does not select local CanvasKit" >&2
  exit 1
fi

printf 'Flutter Web resources are local: %s and %s\n' "$bootstrap" "$local_canvaskit"
