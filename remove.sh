#!/usr/bin/env bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo: sudo ./remove.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/share/zenbook-duo"
RUN_USER="${SUDO_USER:-$(id -un)}"

systemctl disable --now brightness-sync.service >/dev/null 2>&1 || true
systemctl disable --now duo-button.service >/dev/null 2>&1 || true

rm -f /etc/systemd/system/brightness-sync.service
rm -f /etc/systemd/system/duo-button.service
systemctl daemon-reload

rm -f /etc/udev/hwdb.d/90-zenbook-duo.hwdb
rm -f /etc/systemd/hwdb.d/90-zenbook-duo.hwdb
rm -f /etc/udev/rules.d/99-asus-wmi-input.rules
rm -f /etc/udev/rules.d/99-zenbook-duo-dp.rules
rm -f /etc/udev/rules.d/99-zenbook-duo-backlight.rules

systemd-hwdb update
udevadm control --reload-rules
udevadm trigger --subsystem-match=input --action=add
udevadm trigger --subsystem-match=backlight --action=add
udevadm trigger --subsystem-match=drm --action=add

rm -f /usr/local/bin/duo
rm -f /usr/local/bin/duo_button_listener.py
rm -rf "$INSTALL_DIR"

sudo -u "$RUN_USER" systemctl --user disable --now duo-button.service >/dev/null 2>&1 || true

if [ -f "$REPO_DIR/remove-batter-limiter.sh" ]; then
  read -r -p "Remove Argos fully? [y/N] " remove_argos
  if [[ "$remove_argos" =~ ^[Yy]$ ]]; then
    bash "$REPO_DIR/remove-batter-limiter.sh" --remove-argos
  else
    bash "$REPO_DIR/remove-batter-limiter.sh"
  fi
fi

echo "Removed zenbook-duo system changes. Reboot if DP-1 state is stuck."
