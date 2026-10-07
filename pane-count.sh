#!/bin/bash
# Print the number of panes for the next Hollywood layout.
#
# The entrypoint runs this script at the start, and the Hollywood launcher runs it
# again for every layout rebuild. The maximum is the number of terminal cells
# divided by HOLLYWOOD_CELLS_PER_PANE, limited to two panes per CPU and to the
# number of widgets. The script picks a random count from 2 up to that maximum,
# unless HOLLYWOOD_RANDOM_PANES is 0.
#
# With a tmux session name as the first argument, the script measures the tmux
# window. Without it, the script measures the terminal.

CELLS_PER_PANE=${HOLLYWOOD_CELLS_PER_PANE:-1400}
WIDGET_DIR=/usr/lib/hollywood

terminal_cells() {
	local rows cols
	if [ -n "$1" ]; then
		read -r cols rows < <(tmux display -p -t "$1" '#{window_width} #{window_height}' 2>/dev/null)
	fi
	if [ -z "$rows" ]; then
		read -r rows cols < <(stty size 2>/dev/null)
	fi
	rows=${rows:-${LINES:-24}}
	cols=${cols:-${COLUMNS:-80}}
	echo $((rows * cols))
}

panes=$(($(terminal_cells "$1") / CELLS_PER_PANE))
cpu_cap=$(($(nproc 2>/dev/null || echo 2) * 2))
widget_cap=$(ls "$WIDGET_DIR" | wc -l)
[ "$panes" -gt "$cpu_cap" ] && panes=$cpu_cap
[ "$panes" -gt "$widget_cap" ] && panes=$widget_cap
# The launcher always creates at least 2 panes, even with -s 1.
[ "$panes" -lt 2 ] && panes=2
if [ "${HOLLYWOOD_RANDOM_PANES:-1}" != 0 ]; then
	panes=$((2 + RANDOM % (panes - 1)))
fi
echo "$panes"
