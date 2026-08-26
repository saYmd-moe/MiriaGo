#!/usr/bin/env bash
# M0: repeatable Linux startup / core-page performance measurement.
#
# Measured here (externally, repeatably):
#   - cold start: launch with an isolated XDG_DATA_HOME, wall time until the
#     window first appears when a supported detector is available.
#   - warm start: relaunch reusing a prepared data dir.
#   - when no detector is available, window_ready is NOT_MEASURED; this script
#     does not substitute process-alive time for a UI-ready measurement.
#
# Not measured automatically (see docs/linux/benchmark-scale.md):
#   - "time to map page" and "large-plan load" need in-app Flutter trace
#     instrumentation that does not exist yet (tracked under M3). This script
#     records them as NOT_MEASURED rather than fabricating numbers.
#
# Usage:
#   MIRIAGO_BIN=src-tauri/target/release/miriago-desktop \
#     ./scripts/measure-linux-performance.sh
#
# Environment:
#   MIRIAGO_BIN        path to a release binary (required).
#   MIRIAGO_APP_NAME   window title to detect (default: MiriaGo).
#   MIRIAGO_RUNS       cold+warm iterations (default: 3 each).
#   Keep the default XDG_DATA_HOME unless you want isolation testing.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

binary="${MIRIAGO_BIN:-}"
if [[ -z "$binary" ]]; then
  candidate="src-tauri/target/release/miriago-desktop"
  if [[ -x "$candidate" ]]; then binary="$candidate"; fi
fi
if [[ -z "$binary" ]] || [[ ! -x "$binary" ]]; then
  echo "error: release binary not found/executable." >&2
  echo "  Build with MIRIAGO_SKIP_BUILD=0 ./scripts/build-arch-package.sh, then" >&2
  echo "  re-run with MIRIAGO_BIN=<binary> or export MIRIAGO_BIN=<binary>" >&2
  exit 1
fi

app_name="${MIRIAGO_APP_NAME:-MiriaGo}"
runs="${MIRIAGO_RUNS:-3}"

now_ms() { date +%s%3N; }

# --- window detection ------------------------------------------------------
# Sets WINDOW_READY_MS to the wall time (ms) until the app window is mapped,
# or leaves it empty when no detector is available. Detection is best on X11
# (xdotool) and compositor-specific on Wayland.
detect_window_tool() {
  if command -v xdotool >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
    echo "xdotool"
    return 0
  fi
  if command -v wmctrl >/dev/null 2>&1; then echo "wmctrl"; return 0; fi
  echo "none"
}
window_tool="$(detect_window_tool)"

wait_for_window() {
  local t0 now
  t0="$(now_ms)"
  case "$window_tool" in
    xdotool)
      if timeout 30s xdotool search --sync --onlyvisible --name "$app_name" >/dev/null 2>&1; then
        now="$(now_ms)"; echo $((now - t0)); return 0
      fi
      ;;
    wmctrl)
      local i
      for i in $(seq 1 200); do
        if wmctrl -l 2>/dev/null | grep -q "$app_name"; then
          now="$(now_ms)"; echo $((now - t0)); return 0
        fi
        sleep 0.05
      done
      ;;
    none)
      # No reliable detector on this session/compositor. Report honestly as
      # not measured instead of guessing.
      echo ""
      return 2
      ;;
  esac
  echo ""
  return 1
}

launch_then_measure() {
  # $1 = XDG_DATA_HOME to use. Returns window_ms (may be empty) and ensures
  # app is cleaned up.
  local data_home="$1" window_ms
  export XDG_DATA_HOME="$data_home"
  "$binary" >/dev/null 2>&1 &
  local pid=$!
  window_ms="$(wait_for_window || true)"
  # Give it a moment to confirm it stays alive; then clean up.
  sleep 2
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  echo "$window_ms"
}

cold_ms=()
warm_ms=()
cold_dir="$(mktemp -d "${TMPDIR:-/tmp}/miriago-cold.XXXXXX")"
warm_dir="$(mktemp -d "${TMPDIR:-/tmp}/miriago-warm.XXXXXX")"
trap 'rm -rf "$cold_dir" "$warm_dir"; kill $(jobs -p) 2>/dev/null || true' EXIT

echo "=== MiriaGo Linux performance baseline ($(date -Is)) ==="
echo "binary:      $binary"
printf "session:     XDG_SESSION_TYPE=%s XDG_CURRENT_DESKTOP=%s\n" \
  "${XDG_SESSION_TYPE:-none}" "${XDG_CURRENT_DESKTOP:-none}"
printf "display:     DISPLAY=%s WAYLAND_DISPLAY=%s\n" \
  "${DISPLAY:-none}" "${WAYLAND_DISPLAY:-none}"
echo "window tool: $window_tool"
echo "runs:        $runs cold + $runs warm"
echo

echo "--- cold start (isolated XDG_DATA_HOME) ---"
for i in $(seq 1 "$runs"); do
  run_dir="$cold_dir/run-$i"
  mkdir -p "$run_dir"
  r="$(launch_then_measure "$run_dir")"
  if [[ -n "$r" ]]; then
    cold_ms+=("$r"); echo "run $i: window_ready=${r}ms"
  else
    cold_ms+=("NOT_MEASURED"); echo "run $i: window_ready=NOT_MEASURED (no detector)"
  fi
done

echo
echo "--- warm start (shared data dir) ---"
for i in $(seq 1 "$runs"); do
  r="$(launch_then_measure "$warm_dir")"
  if [[ -n "$r" ]]; then
    warm_ms+=("$r"); echo "run $i: window_ready=${r}ms"
  else
    warm_ms+=("NOT_MEASURED"); echo "run $i: window_ready=NOT_MEASURED (no detector)"
  fi
done

echo
echo "--- summary ---"
echo "cold window_ready (ms): ${cold_ms[*]}"
echo "warm window_ready (ms): ${warm_ms[*]}"
echo "NOTE: 'time to map page' and 'large-plan load' are NOT_MEASURED here;"
echo "      they require in-app Flutter trace instrumentation (M3). See"
echo "      docs/linux/benchmark-scale.md for the manual protocol."
