#!/usr/bin/env bash
# M0: read-only plan scale inspector.
#
# Reports the data scale of a MiriaGo desktop database (miriago.sqlite) so
# baseline measurements can be tagged as empty / medium / large per
# docs/linux/benchmark-scale.md. Run before every performance/regression run
# so results are comparable.
#
# This script only reads the database; it never writes or migrates state.
#
# Usage:
#   ./scripts/inspect-plan-scale.sh [PATH_TO_miriago.sqlite]
#
# When no path is given, it uses $XDG_DATA_HOME/MiriaGo/miriago.sqlite
# (default ~/.local/share/MiriaGo/miriago.sqlite).

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "error: sqlite3 CLI is required but not installed" >&2
  exit 1
fi

db="${1:-}"
if [[ -z "$db" ]]; then
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  db="$data_home/MiriaGo/miriago.sqlite"
fi
if [[ ! -f "$db" ]]; then
  echo "error: database not found: $db" >&2
  exit 1
fi

q() { sqlite3 -readonly "$db" "$1"; }

plans="$(q "SELECT COUNT(*) FROM plans;")"
works="$(q "SELECT COUNT(*) FROM works;")"
points="$(q "SELECT COUNT(*) FROM points;")"
groups="$(q "SELECT COUNT(*) FROM plan_groups;")"
records="$(q "SELECT COUNT(*) FROM visit_records;")"
cached_refs="$(q "SELECT COUNT(*) FROM points WHERE reference_full_image_path IS NOT NULL AND reference_full_image_path != '';")"
schema="$(q "SELECT value FROM app_meta WHERE key='schema_version';")"

echo "database:   $db"
echo "schema:     $schema"
echo "plans:      $plans"
echo "works:      $works"
echo "groups:     $groups"
echo "points:     $points"
echo "visit_records: $records"
echo "cached_full_reference_images: $cached_refs"

class="empty"
if (( plans > 0 )); then
  if (( points >= 1000 || records >= 100 )); then
    class="large"
  elif (( points >= 50 || records >= 10 )); then
    class="medium"
  else
    class="small"
  fi
fi
echo "scale_class: $class   (see docs/linux/benchmark-scale.md)"
