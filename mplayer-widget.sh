#!/bin/bash
# Hollywood "mplayer" widget: play the sound-wave video in the pane.
#
# This script replaces the widget that comes with Hollywood, which draws the
# video with libcaca. That output is a mix of random letters that change on every
# frame, and the picture is thin and flickers. Here mplayer scales the video to
# the pane and sends the raw frames to soundwave-render.py. The renderer draws
# each cell as a half block, so every cell shows two pixels in true color.
#
#   HOLLYWOOD_MPLAYER_SPEED    playback speed, 1 is normal (default 0.75)
#   HOLLYWOOD_MPLAYER_FILTERS  video filter that crops the video to the rows
#                              where the waveform is (default crop=128:64:0:16)
#
# Based on the widget of the same name in Hollywood
# (https://github.com/dustinkirkland/hollywood), Copyright 2014 Dustin Kirkland,
# licensed under the Apache License 2.0. The changes are by the docker-hollywood
# project and are licensed under the MIT license. See LICENSE and THIRD-PARTY.md.

command -v mplayer >/dev/null 2>&1 || exit 1
command -v python3 >/dev/null 2>&1 || exit 1
trap "pkill -f -9 lib/hollywood/ >/dev/null 2>&1; exit" INT

PKG=hollywood
dir="$(dirname "$0")/../../share/$PKG"
speed=${HOLLYWOOD_MPLAYER_SPEED:-0.75}
crop=${HOLLYWOOD_MPLAYER_FILTERS:-crop=128:64:0:16}

while true; do
	started=$SECONDS
	cols=$(($(tput cols 2>/dev/null || echo 80) / 2 * 2))
	rows=$(tput lines 2>/dev/null || echo 24)
	mplayer -really-quiet -noconsolecontrols -nosound -loop 0 -ss $((RANDOM % 100)) \
		-speed "$speed" -vf "$crop,scale=$cols:$((rows * 2))" \
		-vo yuv4mpeg:file=/dev/stdout "$dir/soundwave.mp4" 2>/dev/null |
		/usr/local/bin/hollywood-soundwave-render
	# Status 3 means the pane changed size: start again at the new size. Wait
	# a second when a run ends at once, so a failure cannot use up the CPU.
	[ "${PIPESTATUS[1]}" = 3 ] && [ $((SECONDS - started)) -ge 1 ] || sleep 1
done
