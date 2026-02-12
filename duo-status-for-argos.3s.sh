#!/usr/bin/env bash

URL="github.com/p-e-w/argos"
DIR=$(dirname "$0")

bat_limit="$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)"
if [ -n "$bat_limit" ]; then
	echo "${bat_limit}%"
else
	$HOME/p/my-scripts/duo status
fi
echo "---"
echo "battery: safe (80%) | terminal=false bash='duo bat-safe'"
echo "battery: full (100%) | terminal=false bash='duo bat-full'"
echo "battery: set 90% | terminal=false bash='duo bat-limit 90'"
echo "---"
echo "top    | terminal=false bash='duo top'"
echo "both   | terminal=false bash='duo both'"
echo "bottom | terminal=false bash='duo bottom'"
echo "---"
echo "left   | terminal=false bash='duo left'"
echo "right  | terminal=false bash='duo right'"
echo "---"
echo "$URL | iconName=help-faq-symbolic href='https://$URL'"
echo "$DIR | iconName=folder-symbolic href='file://$DIR'"

