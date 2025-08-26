#!/usr/bin/env bash
set -euo pipefail
JOB_DIR="$1"
RAW="$JOB_DIR/pentest_raw"
mkdir -p "$RAW"

# Prasyarat: live_hosts.jsonl (hasil httpx -json)
LH="$JOB_DIR/live_hosts.jsonl"
test -s "$LH" || { echo "[ERR] missing $LH"; exit 2; }

# Reset targets
: > "$RAW/targets_takeover.txt"
: > "$RAW/targets_upload.txt"
: > "$RAW/targets_exposure.txt"

# 1) Extract URL hidup (http/https)
jq -r 'select(.url) | .url' "$LH" | sort -u > "$JOB_DIR/live.txt"

# 2) WordPress & upload-ish hints
#    - tech: WordPress
#    - path hints: /wp-content/, /wp-admin/, /upload, /media
jq -r '
  select(.url) as $u
  | .tech as $t
  | [$u,
     ((($t|tostring|test("WordPress";"i")) or (.title|tostring|test("WordPress";"i"))) as $iswp),
     ($u|test("/(wp-admin|wp-content|upload|media)";"i"))] |
  select(.[1] or .[2]) | .[0]
' "$LH" | sort -u >> "$RAW/targets_upload.txt"

# 3) Exposure hints (open dir, logs, backups, config)
grep -Ei '/(\.env|backup|backups|logs?|debug|\.git|\.svn|\.DS_Store|\.bak)(/|$)' "$JOB_DIR/live.txt" \
  | sort -u >> "$RAW/targets_exposure.txt" || true

# 4) Takeover candidates (dangling CNAME/common providers) — fallback heuristik cepat
#    NB: idealnya pakai resolusi DNS + rule provider; minimal dulu dari httpx host hints
jq -r 'select(.host) | .host' "$LH" | sort -u | \
grep -Ei '\.(azurewebsites\.net|cloudfront\.net|github\.io|herokuapp\.com|amazonaws\.com|storage\.googleapis\.com|fastly\.net)$' \
  | sed 's#^#https://#' >> "$RAW/targets_takeover.txt" || true

# Pastikan file kosong tetap ada
for f in targets_takeover.txt targets_upload.txt targets_exposure.txt; do
  : > "$RAW/$f" && cat "$RAW/$f" >/dev/null
done

echo "[OK] recon sort -> $RAW/{targets_takeover.txt,targets_upload.txt,targets_exposure.txt}"
