# zenbook-duo-2023-ux8402v-linux

> **Note**: If you forked this repository and want to detach it from the fork relationship, see [DETACHING_FROM_FORK.md](DETACHING_FROM_FORK.md) for guidance.

Features:
* brightness sync (any)
* battery limiter (any)
* touch/pen panels mapping (GNOME-specific, requires GNOME 46 or a backported Mutter patch)
* automatic bottom screen on/off (GNOME-specific)

## tested on
- product: Zenbook UX8402VU_UX8402VU 
- system_v: 1.0       
- bios_v: UX8402VU.300
- bios_release: 04/27/2023
- Ubuntu 25.10
- GNOME 49 (Wayland)
- Kernel 6.17.0-14-generic
- Top panel: eDP-1 (SDC 0x4190) 2880x1800
- Bottom panel: DP-1 (BOE 0x0a8d) 2880x864
- GNOME scaling: scaling-factor=0, text-scaling-factor=1.0
- Mutter experimental features: scale-monitor-framebuffer, xwayland-native-scaling

## panel mapping

`duo set-tablet-mapping` sets GNOME per-device mappings (touch + stylus) for the top and bottom panels.

On GNOME Wayland, the mapping is only honored if Mutter includes the tablet mapping MR https://gitlab.gnome.org/GNOME/mutter/-/merge_requests/3556 and libwacom includes https://github.com/linuxwacom/libwacom/pull/640 . If mappings are written but ignored, update Mutter/libwacom.

## bottom screen toggle on GNOME

Make sure usbutils and inotify-tools are installed; the script relies on the `lsusb` and `inotifywait` commands from them.

If `gnome-monitor-config` is available it will be used for display changes. Otherwise the script falls back to a Mutter DBus helper (`duo_mutter.py`) that uses PyGObject.

Before the next steps, you may need or want to change the scaling settings or change the config at the top of `duo` based on the version of the duo that you have (1080p vs 3k display models)

For automatic screen management run `duo watch-displays` somewhere at the start of your GNOME session.

For manual screen management there are `duo top`, `duo bottom`, `duo both` and `duo toggle` (toggles between top and both) commands.

In addition there's also `duo toggle-bottom-touch` to toggle touch for the bottom screen, so you can draw with a pen while resting your hand on the screen.

### bottom touchpad gestures

The bottom panel exposes a separate touchpad-capable device, so GNOME enables gestures there. To disable gestures only for the bottom panel while keeping the main touchpad working, add a libinput quirk:

```
sudo mkdir -p /etc/libinput
sudo tee /etc/libinput/local-overrides.quirks >/dev/null <<'EOF'
[ELAN9009 Touchpad Quirk]
MatchName=ELAN9009:00 04F3:2F2A Touchpad
MatchUdevType=touchpad
AttrEventCodeDisable=BTN_TOOL_FINGER;BTN_TOOL_DOUBLETAP;BTN_TOOL_TRIPLETAP;BTN_TOOL_QUADTAP;BTN_TOOL_QUINTTAP
EOF
```

Reboot to apply the quirk.

### second display button (Ubuntu 25.10)

If the Asus WMI hotkey still reports `KEY_UNKNOWN`, you can use a small listener that watches the hotkey device and runs `duo toggle` directly. It relies on `python3-evdev` and requires access to `/dev/input`.

Install dependency:

```
sudo apt install python3-evdev
```

Add your user to the `input` group and re-login:

```
sudo usermod -aG input $USER
```

Copy the service file and edit paths:

```
mkdir -p ~/.config/systemd/user
cp /path/to/repo/duo-button.service ~/.config/systemd/user/
sed -i "s|%h/CHANGE/THIS/PATH|/path/to/repo|g" ~/.config/systemd/user/duo-button.service
```

Enable and start the service:

```
systemctl --user daemon-reload
systemctl --user enable --now duo-button.service
```

## brightness sync

Brightness control requires root permissions. After configuring sudo, you can run `duo sync-backlight` once or `duo watch-backlight` at login to keep syncing brightness from the top display to the bottom one.

For UX8402V (2023) the bottom backlight is usually `asus_screenpad`. The script now auto-detects the target backlight, so you should not need to change it manually.

For most linux distros there is an included systemd service file: `brightness-sync.service` that just needs `/path/to/duo` changed before moving it to `/etc/systemd/system` to enable brightness sync in the background.

## battery limiter

Requires same sudo setup as for the brightness sync. You can use safe/full modes or a custom percentage:

```
duo bat-safe
duo bat-full
duo bat-limit 75
```

`duo bat-limit` defaults to safe (80%).

## keyboard backlight control

Requires python3 and pyusb installed. `duo set-kb-backlight <0|1|2|3>` configures keyboard backlight, with 0 meaning off and 3 meaning max brightness.


