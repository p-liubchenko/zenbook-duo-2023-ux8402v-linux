#!/usr/bin/env bash

URL="github.com/p-e-w/argos"

if [ -x /usr/local/bin/duo ]; then
	DUO_BIN="/usr/local/bin/duo"
elif [ -x /usr/local/share/zenbook-duo/duo ]; then
	DUO_BIN="/usr/local/share/zenbook-duo/duo"
else
	DUO_BIN="$(cd "$(dirname "$0")" && pwd)/duo"
fi

if command -v pkexec >/dev/null 2>&1; then
	BAT_CMD="pkexec $DUO_BIN"
elif command -v sudo >/dev/null 2>&1; then
	BAT_CMD="sudo -n $DUO_BIN"
else
	BAT_CMD="$DUO_BIN"
fi

bat_limit="$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)"
if [ -n "$bat_limit" ]; then
	echo "${bat_limit}%"
else
	"$DUO_BIN" status
fi
echo "---"
echo "battery: safe (80%) | terminal=false bash='$BAT_CMD bat-safe'"
echo "battery: full (100%) | terminal=false bash='$BAT_CMD bat-full'"
echo "battery: set 90% | terminal=false bash='$BAT_CMD bat-limit 90'"
echo "---"
echo "top    | terminal=false bash='$DUO_BIN top'"
echo "both   | terminal=false bash='$DUO_BIN both'"
echo "bottom | terminal=false bash='$DUO_BIN bottom'"
echo "---"
echo "$URL | iconName=help-faq-symbolic href='https://$URL'"

