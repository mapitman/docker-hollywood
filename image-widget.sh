#!/bin/bash
# Hollywood "jp2a" widget: show the JPEG pictures under /usr, one after another.
# The map widget shows the map, so the map picture is left out here.
#
# This script replaces the widget that comes with Hollywood, which draws each
# picture as letters in the eight basic terminal colors and changes pictures twice
# a second. Here image-render.py draws each picture with half blocks in 256 colors,
# so every cell shows two pixels, and each picture stays for a few seconds.
#
#   HOLLYWOOD_IMAGE_SECONDS  seconds to show each picture (default 3)
#
# Based on the widget of the same name in Hollywood
# (https://github.com/dustinkirkland/hollywood), Copyright 2014 Dustin Kirkland,
# licensed under the Apache License 2.0. The changes are by the docker-hollywood
# project and are licensed under the MIT license. See LICENSE and THIRD-PARTY.md.

command -v python3 >/dev/null 2>&1 || exit 1
trap "pkill -f -9 lib/hollywood/ >/dev/null 2>&1; exit" INT
trap 'printf "\033[0m\033[?25h"; exit 0' TERM HUP

seconds=${HOLLYWOOD_IMAGE_SECONDS:-3}
case "$seconds" in '' | *[!0-9]*) seconds=3 ;; esac
[ "$seconds" -lt 1 ] && seconds=1

while true; do
	files=$(find /usr -readable -size +0 -type f -name '*.jpg' -not -path '/usr/share/hollywood/*' 2>/dev/null | sort -R)
	[ -n "$files" ] || exit 1
	while IFS= read -r file; do
		size=$(stty size 2>/dev/null)
		/usr/local/bin/hollywood-image-render "$file" || continue
		# Wait, and draw the picture again if the pane changes size.
		for ((tick = 0; tick < seconds * 4; tick++)); do
			sleep 0.25
			if [ "$(stty size 2>/dev/null)" != "$size" ]; then
				size=$(stty size 2>/dev/null)
				printf '\033[2J'
				/usr/local/bin/hollywood-image-render "$file"
			fi
		done
	done <<<"$files"
done
