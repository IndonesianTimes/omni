#!/usr/bin/env bash
set -euo pipefail

ARG="${1:-}"
[[ -n "$ARG" ]] || { echo "[ERR] usage: $0 <input.txt | JOB_DIR>"; exit 2; }

# Jika file → buat job baru, jika folder → pakai job tsb
if [[ -f "$ARG" ]]; then
  INPUT="$(readlink -f "$ARG")"
  JOB_ID="$(date +%y%m%d_%H%M%S)"
  JOB_DIR="/opt/omni/jobs/$JOB_ID"
  mkdir -p "$JOB_DIR/pentest_raw"
  cp -f "$INPUT" "$JOB_DIR/input.txt"
elif [[ -d "$ARG" ]]; then
  JOB_DIR="$(readlink -f "$ARG")"
  [[ -f "$JOB_DIR/input.txt" ]] || { echo "[ERR] $JOB_DIR/input.txt missing"; exit 2; }
  mkdir -p "$JOB_DIR/pentest_raw"
else
  echo "[ERR] usage: $0 <input.txt | JOB_DIR>"
  exit 2
fi

RAW="$JOB_DIR/pentest_raw"

# ====== Subdomain (opsional) ======
if command -v subfinder >/dev/null 2>&1; then
  # Ekstrak host dari input (bisa domain/URL campur)
  sed 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#/.*##' "$JOB_DIR/input.txt" \
    | awk 'NF' | sort -u > "$JOB_DIR/seed_hosts.txt"
  subfinder -silent -dL "$JOB_DIR/seed_hosts.txt" | sort -u > "$JOB_DIR/all_subs.txt" || true
else
  # fallback: pakai input.txt apa adanya
  awk 'NF' "$JOB_DIR/input.txt" | sort -u > "$JOB_DIR/all_subs.txt"
fi

# Buat daftar URL yg bisa diprobe
awk 'NF{u=$0;if(u!~/^https?:\/\//)u="https://"u;print u}' "$JOB_DIR/all_subs.txt" \
  | sort -u > "$JOB_DIR/all_urls.txt"

# ====== Probe → live_hosts.jsonl ======
httpx -silent -json -title -status-code -tech-detect -follow-redirects -timeout 10 -retries 1 \
  -l "$JOB_DIR/all_urls.txt" > "$JOB_DIR/live_hosts.jsonl"

# ====== Live list & CSV ======
jq -r 'select(.url) | .url' "$JOB_DIR/live_hosts.jsonl" | sort -u > "$JOB_DIR/live.txt"
cp -f "$JOB_DIR/live_hosts.jsonl" "$JOB_DIR/techmap.jsonl"
jq -r '[.url, (.status_code|tostring), (.title|tostring), (.tech|tostring)]|@csv' \
  "$JOB_DIR/live_hosts.jsonl" > "$JOB_DIR/recon_hosts.csv" || true

# ====== Sort → targets_* (kalau ada) ======
if [[ -x /opt/omni/scripts/recon_sort.sh ]]; then
  /opt/omni/scripts/recon_sort.sh "$JOB_DIR" || true
fi

echo "$JOB_DIR"
