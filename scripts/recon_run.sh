#!/usr/bin/env bash
set -euo pipefail
INPUT="$1"
JOB_ID="$(date +%y%m%d_%H%M%S)"
JOB_DIR="/opt/omni/jobs/$JOB_ID"
mkdir -p "$JOB_DIR/pentest_raw"
cp -f "$INPUT" "$JOB_DIR/input.txt"

# Subdomain → all_subs.txt (optional jika INPUT sudah URL)
if command -v subfinder >/dev/null 2>&1; then
  subfinder -silent -dL "$JOB_DIR/input.txt" | sort -u > "$JOB_DIR/all_subs.txt" || true
else
  cp "$JOB_DIR/input.txt" "$JOB_DIR/all_subs.txt"
fi

# Probe → live_hosts.jsonl
cat "$JOB_DIR/all_subs.txt" | sed 's#^#https://#' | \
/opt/omni/tools/httpx -json -title -status-code -tech-detect -follow-redirects -timeout 10 -retries 1 \
  > "$JOB_DIR/live_hosts.jsonl"

# Sort → targets_*
/opt/omni/scripts/recon_sort.sh "$JOB_DIR"

echo "$JOB_DIR"
