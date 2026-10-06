#!/bin/bash
# Hollywood "btop" widget: show btop, a monitor for the CPU, memory, network and processes.
#
# btop needs a pane of at least 80 columns by 24 lines to show all four of its boxes.
# In a smaller pane, down to 60 by 8, this widget shows only the CPU box. When the
# pane changes size across that edge, the widget starts btop again with the boxes
# that fit.
#
#   HOLLYWOOD_BTOP_UPDATE_MS  milliseconds between updates of btop (default 100)
#
# This widget was written for hollywood-directors-cut and is licensed under the MIT
# license. It follows the pattern of the widgets in Hollywood. See LICENSE and
# THIRD-PARTY.md.

command -v btop >/dev/null 2>&1 || exit 1

# btop updates every 2000 ms unless told otherwise, which is slow to watch. Use the
# fastest rate that btop allows, 100 ms. It does not accept less.
update=${HOLLYWOOD_BTOP_UPDATE_MS:-100}
case "$update" in '' | *[!0-9]*) update=100 ;; esac
[ "$update" -lt 100 ] && update=100

# btop does not clean up when it is stopped with TERM, which is how the widget guard
# stops a widget. Put the terminal back the way it was: mouse reporting off, leave the
# alternate screen, show the cursor, reset the colors.
restore_terminal() {
	printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?1049l\033[?25h\033[0m'
}

trap "pkill -f -9 lib/hollywood/ >/dev/null 2>&1; exit" INT
trap 'kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; restore_terminal; exit 0' TERM HUP

# btop keeps its settings in $XDG_CONFIG_HOME/btop. Use a folder of our own, so the
# boxes can be chosen for each start and nothing is left behind.
config=$(mktemp -d /tmp/hollywood-btop.XXXXXX)
trap 'rm -rf "$config"' EXIT
mkdir -p "$config/btop"

# Print "all" if the pane has room for every box, and "cpu" if it has room for only one.
size_class() {
	local rows cols
	read -r rows cols < <(stty size 2>/dev/null)
	if [ "${cols:-0}" -ge 80 ] && [ "${rows:-0}" -ge 24 ]; then
		echo all
	else
		echo cpu
	fi
}

restarted=
while true; do
	class=$(size_class)
	if [ "$class" = all ]; then
		printf 'shown_boxes = "cpu mem net proc"\n' >"$config/btop/btop.conf"
	else
		printf 'shown_boxes = "cpu"\n' >"$config/btop/btop.conf"
	fi
	started=$SECONDS
	# "<&0" keeps the terminal as stdin; bash would otherwise use /dev/null.
	XDG_CONFIG_HOME=$config btop -u "$update" <&0 &
	pid=$!
	restarted=
	while kill -0 "$pid" 2>/dev/null; do
		sleep 1
		if [ "$(size_class)" != "$class" ]; then
			restarted=1
			kill "$pid" 2>/dev/null
			break
		fi
	done
	wait "$pid" 2>/dev/null
	# If btop stops at once and the pane did not change size, give up. This avoids a
	# loop that uses up the CPU, and the widget guard picks another widget.
	[ -z "$restarted" ] && [ $((SECONDS - started)) -lt 2 ] && exit 1
done
