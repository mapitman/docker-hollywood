#!/bin/bash
# Size the Hollywood pane count to the terminal, then start Hollywood.
#
# Docker passes the terminal size in character cells, not pixels. The pane
# count is the number of cells divided by HOLLYWOOD_CELLS_PER_PANE, limited to
# two panes per CPU and to the number of widgets, and at least 2. A 161x37 terminal (about
# 1920x1080 with a typical font) gives 4 panes with the default of 1400 cells per pane.
#
#   HOLLYWOOD_CELLS_PER_PANE  cells per pane (default 1400)
#   HOLLYWOOD_DELAY           seconds before all panes are replaced (default 60)
#
# Any -s/--splits or -d/--delay argument overrides the values computed here.
#
# On exit the script resets the terminal (cursor, screen mode, mouse reporting).
# This cannot run if the container is stopped with "docker kill".

HOLLYWOOD=/usr/games/hollywood
WIDGET_DIR=/usr/lib/hollywood
CELLS_PER_PANE=${HOLLYWOOD_CELLS_PER_PANE:-1400}
DELAY=${HOLLYWOOD_DELAY:-60}

terminal_cells() {
	local rows cols
	read -r rows cols < <(stty size 2>/dev/null)
	rows=${rows:-${LINES:-24}}
	cols=${cols:-${COLUMNS:-80}}
	echo $((rows * cols))
}

pane_count() {
	local panes=$(($(terminal_cells) / CELLS_PER_PANE))
	local cpu_cap=$(($(nproc 2>/dev/null || echo 2) * 2))
	local widget_cap
	widget_cap=$(ls "$WIDGET_DIR" | wc -l)
	[ "$panes" -gt "$cpu_cap" ] && panes=$cpu_cap
	[ "$panes" -gt "$widget_cap" ] && panes=$widget_cap
	# The launcher always creates at least 2 panes, even with -s 1.
	[ "$panes" -lt 2 ] && panes=2
	echo "$panes"
}

has_splits=
has_delay=
for arg in "$@"; do
	case "$arg" in
		-s|--splits) has_splits=1 ;;
		-d|--delay) has_delay=1 ;;
	esac
done

args=()
[ -z "$has_splits" ] && args+=(-s "$(pane_count)")
[ -z "$has_delay" ] && args+=(-d "$DELAY")

# Run Hollywood as a child, not with exec, so this script can restore the
# terminal after it exits. cmatrix and mplayer hide the cursor, switch to the
# alternate screen and turn on mouse reporting, and they cannot undo that when
# they are stopped. Docker stop and ctrl-c reach this script, which passes them on.
restore_terminal() {
	[ -t 1 ] || return 0
	# Mouse reporting off, leave the alternate screen, show the cursor,
	# reset colors, normal keypad.
	printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?1049l\033[?25h\033[0m\033>'
	stty sane 2>/dev/null
}
trap restore_terminal EXIT

# "<&0" keeps the terminal as stdin; bash would otherwise use /dev/null.
"$HOLLYWOOD" "${args[@]}" "$@" <&0 &
child=$!
trap 'kill -TERM "$child" 2>/dev/null' TERM INT HUP

wait "$child"
status=$?
# A trapped signal ends "wait" early; keep waiting until Hollywood is gone.
while kill -0 "$child" 2>/dev/null; do
	wait "$child"
	status=$?
done
exit "$status"
