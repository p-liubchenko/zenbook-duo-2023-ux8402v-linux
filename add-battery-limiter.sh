#!/usr/bin/env bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo: sudo ./add-battery-limiter.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_USER="${SUDO_USER:-$(id -un)}"
ARGOS_SRC="/usr/local/share/argos-src"
ARGOS_EXT_DIR="/home/$RUN_USER/.local/share/gnome-shell/extensions"
ARGOS_EXT_PATH="$ARGOS_EXT_DIR/argos@pew.worldwidemann.com"
ARGOS_PLUGIN_DIR="/home/$RUN_USER/.config/argos"
PLUGIN_SRC="$REPO_DIR/duo-status-for-argos.3s.sh"
PLUGIN_DST="$ARGOS_PLUGIN_DIR/duo-status-for-argos.3s.sh"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required to install Argos. Install it and re-run."
  exit 1
fi

if [ ! -f "$PLUGIN_SRC" ]; then
  echo "Argos plugin script not found: $PLUGIN_SRC"
  exit 1
fi

echo "Installing Argos extension source to $ARGOS_SRC..."
if [ ! -d "$ARGOS_SRC/.git" ]; then
  rm -rf "$ARGOS_SRC"
  git clone https://github.com/p-e-w/argos "$ARGOS_SRC"
else
  git -C "$ARGOS_SRC" pull --ff-only
fi

echo "Linking Argos extension for user $RUN_USER..."
sudo -u "$RUN_USER" mkdir -p "$ARGOS_EXT_DIR"
rm -rf "$ARGOS_EXT_PATH"
ln -s "$ARGOS_SRC/argos@pew.worldwidemann.com" "$ARGOS_EXT_PATH"

sudo -u "$RUN_USER" mkdir -p "$ARGOS_PLUGIN_DIR"
sudo -u "$RUN_USER" install -m 0755 "$PLUGIN_SRC" "$PLUGIN_DST"

cat <<EOF
Argos installed and plugin deployed for $RUN_USER.

Enable the extension (if not already) with:
  gnome-extensions enable argos@pew.worldwidemann.com

If GNOME does not see it yet, log out and log back in.
EOF
