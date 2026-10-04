#!/bin/bash
# Make all panes the same size when there is an even number of them.
#
# The Hollywood launcher splits random panes, so the sizes come out uneven. After
# the launcher builds the panes, it runs this script. For an even pane count, the
# script arranges the panes in a grid of columns by rows with columns * rows equal
# to the count. Each pane gets the same size, give or take one cell. An odd count
# keeps the random layout.

session=${1:-hollywood}
panes=($(tmux list-panes -t "$session" -F '#{pane_id}' 2>/dev/null | tr -d '%'))
n=${#panes[@]}
[ "$n" -ge 2 ] && [ $((n % 2)) -eq 0 ] || exit 0
read -r W H < <(tmux display -p -t "$session" '#{window_width} #{window_height}')

# Print the sizes of $2 panes that share $1 cells, with one cell between panes.
split_sizes() {
	local avail=$(($1 - ($2 - 1))) i
	for ((i = 0; i < $2; i++)); do
		echo $((avail / $2 + (i < avail % $2 ? 1 : 0)))
	done
}

# Choose the grid whose panes are closest to 2.5 times wider than tall. A text
# cell is about twice as tall as it is wide, so these panes look close to square
# but a little wide, like a typical terminal.
cols=1
best=
for ((c = 1; c <= n; c++)); do
	[ $((n % c)) -eq 0 ] || continue
	r=$((n / c))
	pw=$(((W - (c - 1)) / c))
	ph=$(((H - (r - 1)) / r))
	[ "$pw" -ge 1 ] && [ "$ph" -ge 1 ] || continue
	aspect=$((pw * 1000 / ph))
	if [ "$aspect" -gt 2500 ]; then score=$((aspect * 1000 / 2500)); else score=$((2500 * 1000 / aspect)); fi
	if [ -z "$best" ] || [ "$score" -lt "$best" ]; then best=$score; cols=$c; fi
done
rows=$((n / cols))

widths=($(split_sizes "$W" "$cols"))
heights=($(split_sizes "$H" "$rows"))
join() { local IFS=,; echo "$*"; }

# Build the tmux layout string: rows stacked with [], panes in a row side by side with {}.
idx=0
y=0
row_strings=()
for ((r = 0; r < rows; r++)); do
	h=${heights[r]}
	x=0
	cells=()
	for ((c = 0; c < cols; c++)); do
		w=${widths[c]}
		cells+=("${w}x${h},${x},${y},${panes[idx]}")
		idx=$((idx + 1))
		x=$((x + w + 1))
	done
	if [ "$cols" -eq 1 ]; then
		row_strings+=("${cells[0]}")
	else
		row_strings+=("${W}x${h},0,${y}{$(join "${cells[@]}")}")
	fi
	y=$((y + h + 1))
done
if [ "$rows" -eq 1 ]; then
	layout=${row_strings[0]}
else
	layout="${W}x${H},0,0[$(join "${row_strings[@]}")]"
fi

# tmux wants a 16-bit checksum of the layout string in front of it.
sum=0
for ((i = 0; i < ${#layout}; i++)); do
	printf -v ch '%d' "'${layout:i:1}"
	sum=$((((sum >> 1) + ((sum & 1) << 15) + ch) & 0xffff))
done
printf -v checksum '%04x' "$sum"

tmux select-layout -t "$session" "$checksum,$layout" 2>/dev/null || tmux select-layout -t "$session" tiled 2>/dev/null
