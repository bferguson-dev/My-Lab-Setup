#!/usr/bin/env bash
set -euo pipefail

LOG_DIR=/var/log/labsetup
LOG_FILE="$LOG_DIR/bootstrap-linux.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date -Iseconds)] Starting Linux bootstrap"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "Run as root" >&2
  exit 1
fi

if command -v dnf >/dev/null 2>&1; then
  echo "Detected dnf-based distro"
  dnf -y install qemu-guest-agent openssh-server
  dnf -y upgrade qemu-guest-agent
  systemctl enable --now qemu-guest-agent
  systemctl enable --now sshd
  systemctl disable --now dnf-automatic.timer 2>/dev/null || true
  systemctl disable --now dnf-makecache.timer 2>/dev/null || true
  dnf -y remove dnf-automatic 2>/dev/null || true
elif command -v apt-get >/dev/null 2>&1; then
  echo "Detected apt-based distro"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y qemu-guest-agent openssh-server
  apt-get install -y --only-upgrade qemu-guest-agent
  systemctl enable --now qemu-guest-agent
  systemctl enable --now ssh
  systemctl disable --now unattended-upgrades 2>/dev/null || true
  systemctl disable --now apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
  systemctl mask apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
  cat >/etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
else
  echo "Unsupported distro (no dnf or apt-get found)" >&2
  exit 2
fi

echo "Verifying services"
systemctl is-active qemu-guest-agent
systemctl is-enabled qemu-guest-agent
systemctl is-active sshd 2>/dev/null || systemctl is-active ssh

echo "[$(date -Iseconds)] Linux bootstrap complete"
