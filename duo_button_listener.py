#!/usr/bin/env python3

import os
import subprocess
import sys
import time

try:
    from evdev import InputDevice, ecodes, list_devices
except Exception as exc:
    print(f"python-evdev is required: {exc}", file=sys.stderr)
    raise SystemExit(1)

DEFAULT_DEVICE = "/dev/input/by-path/platform-asus-nb-wmi-event"
DEFAULT_SCANCODE = 0x6A
DEFAULT_KEYCODE = 240
DEBOUNCE_SECONDS = 0.5
SESSION_REFRESH_SECONDS = 2.0


def find_device():
    path = os.environ.get("DUO_BUTTON_DEVICE", DEFAULT_DEVICE)
    if os.path.exists(path):
        return path

    for dev_path in list_devices():
        dev = InputDevice(dev_path)
        if dev.name == "Asus WMI hotkeys":
            return dev.path

    return None


def get_int_env(name, default):
    value = os.environ.get(name)
    if not value:
        return default
    try:
        return int(value, 0)
    except ValueError:
        return default


def get_active_user():
    try:
        sessions = subprocess.run(
            ["loginctl", "list-sessions", "--no-legend"],
            check=False,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except Exception:
        return None

    for line in sessions.splitlines():
        if not line.strip():
            continue
        session_id = line.split()[0]
        info = subprocess.run(
            [
                "loginctl",
                "show-session",
                session_id,
                "-p",
                "Active",
                "-p",
                "Seat",
                "-p",
                "Name",
            ],
            check=False,
            capture_output=True,
            text=True,
        ).stdout
        data = dict(
            line.split("=", 1) for line in info.splitlines() if "=" in line
        )
        if data.get("Active") == "yes" and data.get("Seat") == "seat0":
            return data.get("Name")

    return None


def main():
    path = find_device()
    if not path:
        print("Asus WMI hotkeys device not found.", file=sys.stderr)
        return 1

    scancode = get_int_env("DUO_BUTTON_SCANCODE", DEFAULT_SCANCODE)
    keycode = get_int_env("DUO_BUTTON_KEYCODE", DEFAULT_KEYCODE)

    duo_path = os.environ.get("DUO_SCRIPT")
    if not duo_path:
        duo_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), "duo")

    last_fire = 0.0
    last_session_check = 0.0
    active_user = os.environ.get("DUO_RUN_AS_USER")
    if active_user == "auto":
        active_user = None
    device = InputDevice(path)
    for event in device.read_loop():
        now = time.monotonic()
        if now - last_session_check > SESSION_REFRESH_SECONDS:
            if os.geteuid() == 0 and not active_user:
                active_user = get_active_user()
            last_session_check = now

        if event.type == ecodes.EV_MSC and event.code == ecodes.MSC_SCAN:
            if event.value == scancode:
                if now - last_fire > DEBOUNCE_SECONDS:
                    env = os.environ.copy()
                    if os.geteuid() == 0 and active_user:
                        env["DUO_RUN_AS_USER"] = active_user
                    subprocess.run([duo_path, "toggle"], check=False, env=env)
                    last_fire = now
        elif event.type == ecodes.EV_KEY and event.code == keycode and event.value == 1:
            if now - last_fire > DEBOUNCE_SECONDS:
                env = os.environ.copy()
                if os.geteuid() == 0 and active_user:
                    env["DUO_RUN_AS_USER"] = active_user
                subprocess.run([duo_path, "toggle"], check=False, env=env)
                last_fire = now

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
