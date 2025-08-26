#!/bin/bash

set -euo pipefail

# Memastikan JOB_DIR dipilih dari input
if [[ -z "$1" ]]; then
  echo "[ERROR] Harap masukkan path JOB_DIR."
  exit 1
fi

JOB_DIR="$1"
echo "[INFO] Memulai recon untuk $JOB_DIR"

# Cek jika JOB_DIR sudah ada
if [[ ! -d "$JOB_DIR" ]]; then
  echo "[ERROR] Direktori $JOB_DIR tidak ditemukan!"
  exit 1
fi

# Pastikan berada di $JOB_DIR, jangan sampai keluar dari folder yang salah
cd "$JOB_DIR"

# Buat folder pentest_raw jika belum ada
mkdir -p "$JOB_DIR/pentest_raw"

# Pastikan input.txt sudah ada di JOB_DIR
if [[ ! -f "$JOB_DIR/input.txt" ]]; then
  echo "[ERROR] File input.txt tidak ditemukan di $JOB_DIR"
  exit 1
fi

echo "[INFO] File input.txt ditemukan di $JOB_DIR"

# =========================
# 1. Run Recon Live (Probe)
echo "[INFO] Running recon live..."
/opt/omni/scripts/recon_live.sh "$JOB_DIR/input.txt"

# =========================
# 2. Run WP Recon untuk mendeteksi WordPress dan file upload
echo "[INFO] Running WP recon..."
/opt/omni/scripts/recon_wp.sh "$JOB_DIR"

# =========================
# 3. Run Exposure Recon untuk mencari file backup, .env, logs
echo "[INFO] Running Exposure recon..."
/opt/omni/scripts/recon_exposure.sh "$JOB_DIR"

# =========================
# 4. Run Takeover Recon untuk mencari potensi domain takeover
echo "[INFO] Running Takeover recon..."
/opt/omni/scripts/recon_takeover.sh "$JOB_DIR"

# =========================
# 5. Verifikasi hasil recon
echo "[INFO] Verifying results..."
ls -l "$JOB_DIR/pentest_raw"
for f in targets_upload.txt targets_exposure.txt targets_takeover.txt; do
  echo "--- $f ($(wc -l < "$JOB_DIR/pentest_raw/$f") lines)"
  sed -n '1,10p' "$JOB_DIR/pentest_raw/$f" || true
done

# =========================
# 6. Run Pentest Wrapper
echo "[INFO] Running Pentest Wrapper..."
RL=30 CONCURRENCY=30 /opt/omni/scripts/run_pentest_wrapper.sh \
  --input "$JOB_DIR/input.txt" \
  --profile extended

echo "[INFO] Pentest selesai. Lihat hasil di $JOB_DIR/pentest_raw"
