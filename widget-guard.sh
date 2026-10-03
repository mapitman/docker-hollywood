#!/bin/bash
# Run a Hollywood widget only while its pane is large enough for it.
#
# The image replaces each file in /usr/lib/hollywood with a symlink to this
# script. The script runs the real widget from /opt/hollywood. If the pane is
# too small at start, or becomes too small after a resize, it stops the widget
# and starts a different widget that fits in the same pane.
#
# Each running widget also holds a claim in $CLAIM_DIR, so no two panes run the
# same widget. A claim is a symlink whose target is the PID of the guard that
# owns it. Creating a symlink is atomic, so two guards cannot claim one widget.

REAL_DIR=/opt/hollywood/lib/hollywood
CLAIM_DIR=/tmp/hollywood-claims

# Minimum pane size per widget. Widgets that are not listed have no minimum.
declare -A MIN_COLS=([atop]=60 [bmon]=48 [figlet]=57 [sshart]=20)
declare -A MIN_ROWS=([atop]=24 [figlet]=7 [sshart]=12)

# Minimum rows for widget $1 in a pane $2 columns wide.
min_rows() {
	case "$1" in
		# bmon shows its graphs in 18 rows when it is 141 or more columns wide,
		# and in 26 rows otherwise. Below that it asks you to enlarge the window.
		bmon) [ "$2" -ge 141 ] && echo 18 || echo 26 ;;
		*) echo "${MIN_ROWS[$1]:-1}" ;;
	esac
}

fits() {
	local cols rows
	cols=$(tput cols)
	rows=$(tput lines)
	[ "$cols" -ge "${MIN_COLS[$1]:-1}" ] && [ "$rows" -ge "$(min_rows "$1" "$cols")" ]
}

# Widgets that run the same program share one claim.
declare -A GROUP=([map]=jp2a)

claim_key() {
	echo "${GROUP[$1]:-$1}"
}

# Succeed if the claim at $1 belongs to a guard that is still running.
claim_is_live() {
	local pid
	pid=$(readlink "$1") || return 1
	[ -r "/proc/$pid/cmdline" ] && grep -qa hollywood "/proc/$pid/cmdline"
}

# Claim widget $1 for this guard. Fail if another live guard holds it.
claim() {
	local link="$CLAIM_DIR/$(claim_key "$1")"
	mkdir -p "$CLAIM_DIR"
	ln -s "$$" "$link" 2>/dev/null && return 0
	[ "$(readlink "$link")" = "$$" ] && return 0
	claim_is_live "$link" && return 1
	# The owner is gone: replace its stale claim.
	rm -f "$link"
	ln -s "$$" "$link" 2>/dev/null
}

release() {
	local link="$CLAIM_DIR/$(claim_key "$1")"
	[ "$(readlink "$link" 2>/dev/null)" = "$$" ] && rm -f "$link"
}

# Print and claim the preferred widget if it fits and is free. Otherwise print
# and claim a random widget that fits and is free. Widgets listed in $2 are
# skipped (they exited early). If no free widget fits, print nothing and fail.
pick() {
	local preferred=$1 skip=$2 w
	if [ -n "$preferred" ] && fits "$preferred" && claim "$preferred"; then
		echo "$preferred"
		return
	fi
	for w in $(ls "$REAL_DIR" | sort -R); do
		case " $skip " in *" $w "*) continue ;; esac
		fits "$w" && claim "$w" && { echo "$w"; return; }
	done
	return 1
}

kill_tree() {
	local pid=$1 child
	for child in $(pgrep -P "$pid" 2>/dev/null); do
		kill_tree "$child"
	done
	kill "$pid" 2>/dev/null
}

cleanup() {
	[ -n "$child" ] && kill_tree "$child"
	[ -n "$widget" ] && release "$widget"
	exit 0
}
trap cleanup HUP INT TERM
# Wake "wait" on resize so the size can be checked.
trap : WINCH

preferred=$(basename "$0")
failed=
while true; do
	# With no free widget that fits, close this pane instead of repeating one.
	widget=$(pick "$preferred" "$failed") || exit 0
	preferred=
	started=$SECONDS
	"$REAL_DIR/$widget" <&0 &
	child=$!
	# Keep waiting while the widget runs and still fits.
	while kill -0 "$child" 2>/dev/null && fits "$widget"; do
		wait "$child" 2>/dev/null
	done
	if kill -0 "$child" 2>/dev/null; then
		# Pane too small now: stop this widget and pick another.
		kill_tree "$child"
	elif [ $((SECONDS - started)) -lt 5 ]; then
		# Exited right away (for example, a missing tool): do not pick it again.
		failed="$failed $widget"
	fi
	wait "$child" 2>/dev/null
	child=
	release "$widget"
done
