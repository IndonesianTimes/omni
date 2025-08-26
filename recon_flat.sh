#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE=""
OUT_DIR="/opt/omni/out/recon"
MODE="cli_venv"   # karena kamu pakai venv lokal
OMNI_DIR="/opt/omni/omnisci3nt"
VENV_BIN="$OMNI_DIR/venv/bin"
JOBS=1

while getopts ":i:o:j:" opt; do
  case "$opt" in
    i) INPUT_FILE="$OPTARG" ;;
    o) OUT_DIR="$OPTARG" ;;
    j) JOBS="$OPTARG" ;;
    *) echo "Unknown option -$OPTARG"; exit 2 ;;
  esac
done

if [[ -z "${INPUT_FILE}" || ! -f "${INPUT_FILE}" ]]; then
  echo "ERROR: file input tidak ditemukan (-i domains.txt)"
  exit 2
fi

mkdir -p "$OUT_DIR"
RUNNER="$VENV_BIN/python -m omnisci3nt.omnisci3nt"

run_one() {
  local domain="$1"
  [[ -z "$domain" || "$domain" =~ ^# ]] && return 0
  echo "=== [$domain] ==="

  $RUNNER -whois "$domain"     | tee "$OUT_DIR/${domain}_whois.txt"      >/dev/null
  $RUNNER -dns "$domain"       | tee "$OUT_DIR/${domain}_dns.txt"        >/dev/null
  $RUNNER -subdomains "$domain"| tee "$OUT_DIR/${domain}_subdomains.txt" >/dev/null
  $RUNNER -headers "$domain"   | tee "$OUT_DIR/${domain}_headers.txt"    >/dev/null
  $RUNNER -tech "$domain"      | tee "$OUT_DIR/${domain}_tech.txt"       >/dev/null
  $RUNNER -wayback "$domain"   | tee "$OUT_DIR/${domain}_wayback.txt"    >/dev/null
  $RUNNER -crawl "$domain"     | tee "$OUT_DIR/${domain}_crawl.txt"      >/dev/null
  $RUNNER -portscan "$domain"  | tee "$OUT_DIR/${domain}_ports.txt"      >/dev/null
}

export -f run_one
export RUNNER OUT_DIR

mapfile -t DOMAINS < <(grep -v -E '^\s*(#|$)' "$INPUT_FILE")

for d in "${DOMAINS[@]}"; do
  run_one "$d"
done

echo "Selesai. Output di $OUT_DIR"

