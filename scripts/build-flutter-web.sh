#!/usr/bin/env bash
# Build Flutter Web for Tauri with local CanvasKit resources.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

flutter_args=("$@")
has_local_resources_flag=0
for arg in "${flutter_args[@]}"; do
  if [[ "$arg" == "--no-web-resources-cdn" ]]; then
    has_local_resources_flag=1
    break
  fi
done
if [[ "$has_local_resources_flag" == 0 ]]; then
  flutter_args+=(--no-web-resources-cdn)
fi
flutter build web "${flutter_args[@]}"
bash scripts/verify-flutter-web-resources.sh
