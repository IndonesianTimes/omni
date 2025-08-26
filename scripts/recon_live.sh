#!/usr/bin/env bash
set -euo pipefail
INPUT="${1:-}"
[[ -f "$INPUT" ]] || { echo "[ERR] usage: $0 <input.txt>"; exit 2; }

JOB_ID="$(date +%y%m%d_%H%M%S)"
JOB_DIR="/opt/omni/jobs/$JOB_ID"
RAW="$JOB_DIR/pentest_raw"; mkdir -p "$RAW"
cp -f "$INPUT" "$JOB_DIR/input.txt"

# Normalisasi → semua baris jadi https://host
awk 'NF{u=$0;if(u!~/^https?:\/\//)u="https://"u;print u}' "$JOB_DIR/input.txt" | sort -u > "$JOB_DIR/all_urls.txt"

# Probe (title/status/tech)
httpx -silent -json -title -status-code -tech-detect -follow-redirects -timeout 10 -retries 1 \
  -l "$JOB_DIR/all_urls.txt" > "$JOB_DIR/live_hosts.jsonl"

# List URL hidup & techmap (duplikasi minimal)
jq -r 'select(.url) | .url' "$JOB_DIR/live_hosts.jsonl" | sort -u > "$JOB_DIR/live.txt"
cp -f "$JOB_DIR/live_hosts.jsonl" "$JOB_DIR/techmap.jsonl"

# CSV ringkas untuk inspeksi
jq -r '[.url, (.status_code|tostring), (.title|tostring), (.tech|tostring)]|@csv' \
  "$JOB_DIR/live_hosts.jsonl" > "$JOB_DIR/recon_hosts.csv" || true

echo "$JOB_DIR"
