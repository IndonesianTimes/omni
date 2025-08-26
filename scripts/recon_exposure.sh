#!/usr/bin/env bash
set -euo pipefail

JOB_DIR="${1:-}"
[[ -n "$JOB_DIR" && -f "$JOB_DIR/live.txt" ]] || { echo "[ERR] usage: $0 <JOB_DIR>"; exit 2; }

RAW="$JOB_DIR/pentest_raw"
mkdir -p "$RAW"
OUT="$RAW/targets_exposure.txt"
: > "$OUT"

# 1) ambil origin (scheme://host[:port]) dari live.txt
#    kemudian generate kandidat path yang sering “bocor”
CAND="$(mktemp)"
awk -F/ 'BEGIN{OFS="/"} NF{print $1"//"$3}' "$JOB_DIR/live.txt" | sort -u > "$CAND.origins"

# daftar kandidat minimal (bisa kamu tambah sesuai kebutuhan)
read -r -d '' PATHS <<'EOF' || true
/.env
/.env.backup
/.env.bak
/.git/config
/.git/HEAD
/.svn/entries
/backup.zip
/backup.tar
/backup.tar.gz
/backup.sql
/database.sql
/dump.sql
/debug.log
/wp-content/debug.log
/wp-config.php.bak
/.DS_Store
EOF

# generate URL kandidat
while read -r ORI; do
  while read -r P; do
    printf "%s%s\n" "$ORI" "$P"
  done <<<"$PATHS"
done < "$CAND.origins" | sort -u > "$CAND.urls"

# 2) optional probe agar hanya yang “hidup” yang disimpan
if command -v httpx >/dev/null 2>&1; then
  httpx -silent -status-code -no-color -follow-redirects -l "$CAND.urls" \
    | awk '$2 ~ /^(200|204|206|301|302|307|308|401|403)$/ {print $1}' \
    | sort -u >> "$OUT"
else
  # tanpa httpx, simpan seluruh kandidat (lebih “noisy”)
  cat "$CAND.urls" >> "$OUT"
fi

rm -f "$CAND" "$CAND.origins" "$CAND.urls" 2>/dev/null || true
echo "[OK] exposure -> $OUT ($(wc -l < "$OUT") lines)"
