#!/usr/bin/env bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo: sudo ./remove-batter-limiter.sh"
  exit 1
fi

RUN_USER="${SUDO_USER:-$(id -un)}"
ARGOS_SRC="/usr/local/share/argos-src"
ARGOS_EXT_DIR="/home/$RUN_USER/.local/share/gnome-shell/extensions"
ARGOS_EXT_PATH="$ARGOS_EXT_DIR/argos@pew.worldwidemann.com"
ARGOS_PLUGIN_DIR="/home/$RUN_USER/.config/argos"
PLUGIN_DST="$ARGOS_PLUGIN_DIR/duo-status-for-argos.3s.sh"
REMOVE_ARGOS="${1:-}"

if [ -f "$PLUGIN_DST" ]; then
  sudo -u "$RUN_USER" rm -f "$PLUGIN_DST"
fi

if [ "$REMOVE_ARGOS" = "--remove-argos" ]; then
  if command -v gnome-extensions >/dev/null 2>&1; then
    sudo -u "$RUN_USER" gnome-extensions disable argos@pew.worldwidemann.com >/dev/null 2>&1 || true
  fi
  rm -rf "$ARGOS_EXT_PATH"
  rm -rf "$ARGOS_SRC"
fi

echo "Battery limiter tray integration removed for $RUN_USER."
