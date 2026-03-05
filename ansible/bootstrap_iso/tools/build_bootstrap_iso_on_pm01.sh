#!/usr/bin/env bash
set -euo pipefail

# Build on Proxmox host (pm01)
# Usage:
#   ./build_bootstrap_iso_on_pm01.sh /root/lab-bootstrap-src /var/lib/vz/template/iso/LAB_BOOTSTRAP.iso

SRC_DIR="${1:-/root/lab-bootstrap-src}"
OUT_ISO="${2:-/var/lib/vz/template/iso/LAB_BOOTSTRAP.iso}"
LABEL="LAB_BOOTSTRAP"

if ! command -v mkisofs >/dev/null 2>&1; then
  apt-get update
  apt-get install -y genisoimage
fi

mkisofs -V "$LABEL" -J -R -o "$OUT_ISO" "$SRC_DIR"
ls -lh "$OUT_ISO"
