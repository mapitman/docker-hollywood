#!/bin/bash
# Size the Hollywood pane count to the terminal, then start Hollywood.
#
# Docker passes the terminal size in character cells, not pixels. The pane
# maximum is the number of cells divided by HOLLYWOOD_CELLS_PER_PANE, limited to
# two panes per CPU and to the number of widgets. The script picks a random
# count from 2 up to that maximum, so fewer and larger panes appear some of
# the time, and the widgets that need a big pane can run. A 161x37 terminal
# (about 1920x1080 with a typical font) has a maximum of 4 panes with the
# default of 1400 cells per pane.
#
#   HOLLYWOOD_CELLS_PER_PANE  cells per pane (default 1400)
#   HOLLYWOOD_RANDOM_PANES    0 always uses the maximum (default 1)
#   HOLLYWOOD_DELAY           minimum seconds a pane keeps a widget (default 30)
#   HOLLYWOOD_REBUILD         seconds between layout rebuilds (default 600, 0 = never)
#
# Each pane keeps a widget for a random time from the delay to one and a half
# times the delay, so panes change at different moments. The widget guard does
# this. Every rebuild interval the Hollywood launcher keeps one pane, replaces
# the others and builds a new random layout.
#
# Any -s/--splits or -d/--delay argument overrides the values computed here.
#
# On exit the script resets the terminal (cursor, screen mode, mouse reporting).
# This cannot run if the container is stopped with "docker kill".

HOLLYWOOD=/usr/games/hollywood
WIDGET_DIR=/usr/lib/hollywood
CELLS_PER_PANE=${HOLLYWOOD_CELLS_PER_PANE:-1400}
DELAY=${HOLLYWOOD_DELAY:-30}

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
	if [ "${HOLLYWOOD_RANDOM_PANES:-1}" != 0 ]; then
		panes=$((2 + RANDOM % (panes - 1)))
	fi
	echo "$panes"
}

# The launcher replaces all panes but one every -d seconds, which builds a new
# random layout. Use that for the slow rebuild, and pass the per-pane delay to
# the widget guard. A rebuild interval of 0 gives the launcher a delay that never ends.
NO_REFRESH=2147483647

has_splits=
args=()
passthrough=()
while [ $# -gt 0 ]; do
	case "$1" in
		-d|--delay)
			[ $# -ge 2 ] && { DELAY=$2; shift; }
			;;
		-s|--splits)
			has_splits=1
			passthrough+=("$1")
			[ $# -ge 2 ] && { passthrough+=("$2"); shift; }
			;;
		*)
			passthrough+=("$1")
			;;
	esac
	shift
done
case "$DELAY" in ''|*[!0-9]*) DELAY=30 ;; esac
[ "$DELAY" -lt 2 ] && DELAY=2
export HOLLYWOOD_DELAY=$DELAY

REBUILD=${HOLLYWOOD_REBUILD:-600}
case "$REBUILD" in ''|*[!0-9]*) REBUILD=600 ;; esac
[ "$REBUILD" -eq 0 ] && REBUILD=$NO_REFRESH

[ -z "$has_splits" ] && args+=(-s "$(pane_count)")
args+=(-d "$REBUILD")

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
"$HOLLYWOOD" "${args[@]}" "${passthrough[@]}" <&0 &
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
