#!/usr/bin/env bash
set -euo pipefail

# Mode:
#  - Jika argumen adalah file => buat JOB_DIR baru, copy sebagai input.txt
#  - Jika argumen adalah direktori => harus berisi input.txt dan dipakai apa adanya
ARG="${1:-}"
[[ -n "$ARG" ]] || { echo "[ERR] usage: $0 <input.txt | JOB_DIR>"; exit 2; }

if [[ -f "$ARG" ]]; then
  # file input
  INPUT="$(readlink -f "$ARG")"
  JOB_ID="$(date +%y%m%d_%H%M%S)"
  JOB_DIR="/opt/omni/jobs/$JOB_ID"
  mkdir -p "$JOB_DIR/pentest_raw"
  cp -f "$INPUT" "$JOB_DIR/input.txt"
elif [[ -d "$ARG" ]]; then
  # job dir existing
  JOB_DIR="$(readlink -f "$ARG")"
  [[ -f "$JOB_DIR/input.txt" ]] || { echo "[ERR] $JOB_DIR/input.txt missing"; exit 2; }
  mkdir -p "$JOB_DIR/pentest_raw"
else
  echo "[ERR] usage: $0 <input.txt | JOB_DIR>"
  exit 2
fi

RAW="$JOB_DIR/pentest_raw"

# Normalisasi → semua baris jadi https://host (kalau belum ada skema)
awk 'NF{u=$0;if(u!~/^https?:\/\//)u="https://"u;print u}' "$JOB_DIR/input.txt" \
  | sed 's/[[:space:]]\+$//' | sort -u > "$JOB_DIR/all_urls.txt"

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
