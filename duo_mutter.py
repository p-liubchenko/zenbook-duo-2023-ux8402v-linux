#!/usr/bin/env python3

import os
import sys

import gi
from gi.repository import Gio, GLib


DISPLAY_CONFIG_DEST = "org.gnome.Mutter.DisplayConfig"
DISPLAY_CONFIG_PATH = "/org/gnome/Mutter/DisplayConfig"
DISPLAY_CONFIG_IFACE = "org.gnome.Mutter.DisplayConfig"


def get_proxy():
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    return Gio.DBusProxy.new_sync(
        bus,
        Gio.DBusProxyFlags.NONE,
        None,
        DISPLAY_CONFIG_DEST,
        DISPLAY_CONFIG_PATH,
        DISPLAY_CONFIG_IFACE,
        None,
    )


def get_state(proxy):
    result = proxy.call_sync("GetCurrentState", None, Gio.DBusCallFlags.NONE, -1, None)
    serial, monitors, logical_monitors, properties = result.unpack()
    return serial, monitors, logical_monitors, properties


def normalize_monitors(monitors):
    normalized = []
    for ident, modes, props in monitors:
        connector, vendor, product, serial = ident
        normalized.append(
            {
                "connector": connector,
                "vendor": vendor,
                "product": product,
                "serial": serial,
                "modes": modes,
                "props": props,
                "display_name": props.get("display-name", ""),
                "is_builtin": bool(props.get("is-builtin", False)),
            }
        )
    return normalized


def pick_preferred_mode_id(monitor):
    preferred = None
    current = None
    for mode in monitor["modes"]:
        mode_id = mode[0]
        mode_props = mode[-1]
        if mode_props.get("is-preferred"):
            preferred = mode_id
        if mode_props.get("is-current"):
            current = mode_id
    if preferred:
        return preferred
    if current:
        return current
    return monitor["modes"][0][0]


def pick_current_mode_id(monitor):
    for mode in monitor["modes"]:
        mode_id = mode[0]
        mode_props = mode[-1]
        if mode_props.get("is-current"):
            return mode_id
    return None


def parse_mode_height(mode_id):
    try:
        size = mode_id.split("@")[0]
        height = int(size.split("x")[1])
        return height
    except Exception:
        return None


def format_hex(value, width):
    if isinstance(value, str):
        return value
    try:
        return f"0x{int(value):0{width}x}"
    except Exception:
        return str(value)


def guess_top_bottom(monitors):
    env_top = os.environ.get("DUO_TOP_CONNECTOR")
    env_bottom = os.environ.get("DUO_BOTTOM_CONNECTOR")

    by_connector = {m["connector"]: m for m in monitors}
    top = by_connector.get(env_top) if env_top else None
    bottom = by_connector.get(env_bottom) if env_bottom else None

    if not top:
        for monitor in monitors:
            if monitor["is_builtin"]:
                top = monitor
                break

    if not bottom:
        non_builtin = [m for m in monitors if not m["is_builtin"]]
        if len(non_builtin) == 1:
            bottom = non_builtin[0]
        else:
            for monitor in non_builtin:
                name = monitor["display_name"].lower()
                if "screenpad" in name or "boe" in name or "13" in name:
                    bottom = monitor
                    break
            if not bottom and non_builtin:
                bottom = non_builtin[0]

    return top, bottom


def logical_on_connectors(logical_monitors):
    active = set()
    for logical in logical_monitors:
        monitors = logical[5]
        for ident in monitors:
            active.add(ident[0])
    return active


def find_logical_for_connector(logical_monitors, connector):
    for logical in logical_monitors:
        monitors = logical[5]
        for ident in monitors:
            if ident[0] == connector:
                return logical
    return None


def get_scale_and_offset(logical_monitors, top, bottom, mode_top):
    env_scale = os.environ.get("DUO_UI_SCALE")
    env_offset = os.environ.get("DUO_Y_OFFSET")

    scale = float(env_scale) if env_scale else None
    y_offset = int(float(env_offset)) if env_offset else None

    if top:
        logical_top = find_logical_for_connector(logical_monitors, top["connector"])
        if logical_top:
            scale = float(logical_top[2])

    if y_offset is None and bottom:
        logical_bottom = find_logical_for_connector(logical_monitors, bottom["connector"])
        if logical_bottom:
            y_offset = int(round(float(logical_bottom[1])))

    if y_offset is None:
        mode_height = parse_mode_height(mode_top)
        if mode_height and scale:
            y_offset = int(round(mode_height / scale))

    if scale is None:
        scale = 1.0
    if y_offset is None:
        y_offset = 0

    return scale, y_offset


def build_logical_entry(x, y, scale, transform, primary, connector, mode_id):
    return (x, y, scale, transform, primary, [(connector, mode_id, {})])


def apply_layout(proxy, serial, layout, layout_mode):
    props = {"layout-mode": GLib.Variant("u", int(layout_mode))}
    last_error = None
    for method in (1, 0):
        args = GLib.Variant("(uua(iiduba(ssa{sv}))a{sv})", (serial, method, layout, props))
        try:
            proxy.call_sync("ApplyMonitorsConfig", args, Gio.DBusCallFlags.NONE, -1, None)
            return
        except GLib.GError as exc:
            last_error = exc

    if last_error:
        raise last_error


def get_primary_choice():
    value = os.environ.get("DUO_PRIMARY", "top").strip().lower()
    if value in {"top", "bottom"}:
        return value
    return "top"


def main():
    if len(sys.argv) < 2:
        print("Usage: duo_mutter.py <action>")
        return 2

    action = sys.argv[1]
    proxy = get_proxy()
    serial, monitors, logical_monitors, properties = get_state(proxy)
    layout_mode = properties.get("layout-mode", 1)
    monitors = normalize_monitors(monitors)
    top, bottom = guess_top_bottom(monitors)

    if action in {"status-internal", "active-external-displays", "external-display-connected"}:
        active = logical_on_connectors(logical_monitors)
        if action == "status-internal":
            top_on = top and top["connector"] in active
            bottom_on = bottom and bottom["connector"] in active
            if top_on and bottom_on:
                print("both")
            elif top_on:
                print("top")
            elif bottom_on:
                print("bottom")
            else:
                print("none")
            return 0

        internal = {m["connector"] for m in (top, bottom) if m}
        external = [m["connector"] for m in monitors if m["connector"] not in internal]
        external_on = [conn for conn in external if conn in active]

        if action == "active-external-displays":
            for conn in external_on:
                print(conn)
            return 0

        if action == "external-display-connected":
            print("yes" if external_on else "no")
            return 0

    if action == "monitor-ids":
        for role, monitor in (("top", top), ("bottom", bottom)):
            if not monitor:
                continue
            connector = monitor["connector"]
            vendor = monitor["vendor"]
            product = format_hex(monitor["product"], 4)
            serial = format_hex(monitor["serial"], 8)
            print(f"{role} {connector} {vendor} {product} {serial}")
        return 0

    if not top or not bottom:
        print("Could not determine top/bottom monitors", file=sys.stderr)
        return 1

    mode_top = pick_preferred_mode_id(top)
    mode_bottom = pick_current_mode_id(bottom) or pick_preferred_mode_id(bottom)
    scale, y_offset = get_scale_and_offset(logical_monitors, top, bottom, mode_top)

    if action == "top":
        layout = [build_logical_entry(0, 0, scale, 0, True, top["connector"], mode_top)]
        apply_layout(proxy, serial, layout, layout_mode)
        return 0

    if action == "bottom":
        layout = [build_logical_entry(0, 0, scale, 0, True, bottom["connector"], mode_bottom)]
        apply_layout(proxy, serial, layout, layout_mode)
        return 0

    if action == "both":
        primary_choice = get_primary_choice()
        top_primary = primary_choice == "top"
        bottom_primary = primary_choice == "bottom"
        layout = [
            build_logical_entry(0, 0, scale, 0, top_primary, top["connector"], mode_top),
            build_logical_entry(0, y_offset, scale, 0, bottom_primary, bottom["connector"], mode_bottom),
        ]
        apply_layout(proxy, serial, layout, layout_mode)
        return 0

    if action == "left-up":
        layout = [
            build_logical_entry(0, 0, scale, 1, True, bottom["connector"], mode_bottom),
            build_logical_entry(y_offset, 0, scale, 1, False, top["connector"], mode_top),
        ]
        apply_layout(proxy, serial, layout, layout_mode)
        return 0

    if action == "right-up":
        layout = [
            build_logical_entry(0, 0, scale, 3, True, top["connector"], mode_top),
            build_logical_entry(y_offset, 0, scale, 3, False, bottom["connector"], mode_bottom),
        ]
        apply_layout(proxy, serial, layout, layout_mode)
        return 0

    print(f"Unknown action: {action}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
