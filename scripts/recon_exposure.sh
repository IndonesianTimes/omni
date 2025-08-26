#!/usr/bin/env bash
set -euo pipefail
JOB_DIR="${1:-}"; [[ -f "$JOB_DIR/live.txt" ]] || { echo "[ERR] usage: $0 <JOB_DIR>"; exit 2; }
RAW="$JOB_DIR/pentest_raw"; mkdir -p "$RAW"
: > "$RAW/targets_exposure.txt"
grep -Ei '/(\.env|backup|backups|logs?|debug|\.git|\.svn|\.DS_Store|\.bak)(/|$)' \
  "$JOB_DIR/live.txt" | sort -u >> "$RAW/targets_exposure.txt" || true
echo "[OK] exposure -> $RAW/targets_exposure.txt ($(wc -l < "$RAW/targets_exposure.txt") lines)"
