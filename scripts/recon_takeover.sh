#!/usr/bin/env bash
set -euo pipefail
JOB_DIR="${1:-}"; [[ -f "$JOB_DIR/live_hosts.jsonl" ]] || { echo "[ERR] usage: $0 <JOB_DIR>"; exit 2; }
RAW="$JOB_DIR/pentest_raw"; mkdir -p "$RAW"
: > "$RAW/targets_takeover.txt"

if command -v dnsx >/dev/null 2>&1; then
  jq -r 'select(.host)|.host' "$JOB_DIR/live_hosts.jsonl" | sort -u | \
  dnsx -cname -silent | awk -F'[ \t]+' '{print $1,$2}' | \
  grep -Ei '(azurewebsites\.net|cloudfront\.net|github\.io|herokuapp\.com|amazonaws\.com|fastly\.net|storage\.googleapis\.com)' | \
  awk '{print "https://" $1}' | sort -u >> "$RAW/targets_takeover.txt" || true
else
  jq -r 'select(.host)|.host' "$JOB_DIR/live_hosts.jsonl" | sort -u | \
  grep -Ei '\.(azurewebsites\.net|cloudfront\.net|github\.io|herokuapp\.com|amazonaws\.com|fastly\.net|storage\.googleapis\.com)$' | \
  sed 's#^#https://#' >> "$RAW/targets_takeover.txt" || true
fi

sort -u -o "$RAW/targets_takeover.txt" "$RAW/targets_takeover.txt"
echo "[OK] takeover -> $RAW/targets_takeover.txt ($(wc -l < "$RAW/targets_takeover.txt") lines)"
