#!/usr/bin/env bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo: sudo ./setup.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/share/zenbook-duo"
RUN_USER="${SUDO_USER:-$(id -un)}"

if [ ! -f "$REPO_DIR/duo" ]; then
  echo "duo script not found in $REPO_DIR"
  exit 1
fi

if [ ! -f "$REPO_DIR/duo_button_listener.py" ]; then
  echo "duo_button_listener.py not found in $REPO_DIR"
  exit 1
fi

if [ ! -f "$REPO_DIR/duo-button-root.service" ]; then
  echo "duo-button-root.service not found in $REPO_DIR"
  exit 1
fi

if [ ! -f "$REPO_DIR/brightness-sync.service" ]; then
  echo "brightness-sync.service not found in $REPO_DIR"
  exit 1
fi

if [ ! -f "$REPO_DIR/add-battery-limiter.sh" ]; then
  echo "add-battery-limiter.sh not found in $REPO_DIR"
  exit 1
fi

echo "Installing packages..."
apt-get update
apt-get install -y inotify-tools python3-evdev python3-gi usbutils

echo "Installing scripts to $INSTALL_DIR..."
install -d "$INSTALL_DIR"
install -m 0755 "$REPO_DIR/duo" "$INSTALL_DIR/duo"
install -m 0755 "$REPO_DIR/duo_button_listener.py" "$INSTALL_DIR/duo_button_listener.py"
install -m 0644 "$REPO_DIR/duo_mutter.py" "$INSTALL_DIR/duo_mutter.py"
install -m 0644 "$REPO_DIR/bk.py" "$INSTALL_DIR/bk.py" 2>/dev/null || true

ln -sf "$INSTALL_DIR/duo" /usr/local/bin/duo
ln -sf "$INSTALL_DIR/duo_button_listener.py" /usr/local/bin/duo_button_listener.py

mkdir -p /etc/udev/hwdb.d /etc/systemd/hwdb.d

cat > /etc/udev/hwdb.d/90-zenbook-duo.hwdb <<'EOF'
evdev:input:b0019v0000p0000e0000-*
 KEYBOARD_KEY_9c=switchvideomode
 KEYBOARD_KEY_6a=displaytoggle

input:b0019v0000p0000e0000-*
 KEYBOARD_KEY_9c=switchvideomode
 KEYBOARD_KEY_6a=displaytoggle
EOF

cp /etc/udev/hwdb.d/90-zenbook-duo.hwdb /etc/systemd/hwdb.d/90-zenbook-duo.hwdb

cat > /etc/udev/rules.d/99-asus-wmi-input.rules <<'EOF'
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="Asus WMI hotkeys", MODE="0660", GROUP="users", TAG+="uaccess"
EOF

cat > /etc/udev/rules.d/99-zenbook-duo-dp.rules <<'EOF'
SUBSYSTEM=="drm", KERNEL=="card*-DP-*", MODE="0660", GROUP="users", TAG+="uaccess"
EOF

cat > /etc/udev/rules.d/99-zenbook-duo-backlight.rules <<'EOF'
SUBSYSTEM=="backlight", KERNEL=="asus_screenpad", TAG+="uaccess", \
  RUN+="/bin/chgrp users /sys/class/backlight/asus_screenpad/brightness", \
  RUN+="/bin/chgrp users /sys/class/backlight/asus_screenpad/bl_power", \
  RUN+="/bin/chmod g+w /sys/class/backlight/asus_screenpad/brightness", \
  RUN+="/bin/chmod g+w /sys/class/backlight/asus_screenpad/bl_power"
EOF

echo "Applying udev and hwdb rules..."
systemd-hwdb update
udevadm control --reload-rules
udevadm trigger --subsystem-match=input --action=add
udevadm trigger --subsystem-match=backlight --action=add
udevadm trigger --subsystem-match=drm --action=add

BRIGHTNESS_SERVICE="/etc/systemd/system/brightness-sync.service"
cp "$REPO_DIR/brightness-sync.service" "$BRIGHTNESS_SERVICE"

BUTTON_SERVICE="/etc/systemd/system/duo-button.service"
cp "$REPO_DIR/duo-button-root.service" "$BUTTON_SERVICE"
sed -i "s|/path/to/repo|$INSTALL_DIR|g" "$BUTTON_SERVICE"
# Leave auto user selection for Mutter DBus calls.

systemctl daemon-reload
systemctl enable --now brightness-sync.service
systemctl enable --now duo-button.service

# Best-effort: disable user service if it exists.
sudo -u "$RUN_USER" systemctl --user disable --now duo-button.service >/dev/null 2>&1 || true

echo "Installing battery limiter tray integration..."
bash "$REPO_DIR/add-battery-limiter.sh"

echo "Done. If the bottom display is missing, reboot once to re-enumerate DP-1."
