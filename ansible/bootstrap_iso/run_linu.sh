#!/usr/bin/env bash
set -euo pipefail

MNT=/mnt/labiso
for dev in /dev/sr0 /dev/sr1 /dev/cdrom; do
  if [ -b "$dev" ]; then
    mkdir -p "$MNT"
    if mount "$dev" "$MNT" 2>/dev/null; then
      chmod +x "$MNT/bootstra.sh"
      "$MNT/bootstra.sh"
      umount "$MNT"
      exit 0
    fi
  fi
done

echo "Bootstrap ISO not mounted/found" >&2
exit 2
