#!/bin/bash
# Hollywood "map" widget: show a map of the world.
#
# This script replaces the widget that comes with Hollywood, which draws the map as
# letters and prints it again every second, so the pane scrolls all the time. Here
# image-render.py draws the map once with half blocks in 256 colors. The widget
# draws it again only when the pane changes size.
#
# Based on the widget of the same name in Hollywood
# (https://github.com/dustinkirkland/hollywood), Copyright 2014 Dustin Kirkland,
# licensed under the Apache License 2.0. The changes are by the hollywood-directors-cut
# project and are licensed under the MIT license. See LICENSE and THIRD-PARTY.md.

command -v python3 >/dev/null 2>&1 || exit 1
trap "pkill -f -9 lib/hollywood/ >/dev/null 2>&1; exit" INT
trap 'printf "\033[0m\033[?25h"; exit 0' TERM HUP

PKG=hollywood
map="$(dirname "$0")/../../share/$PKG/map.jpg"

size=$(stty size 2>/dev/null)
/usr/local/bin/hollywood-image-render "$map" || exit 1
while true; do
	sleep 0.5
	if [ "$(stty size 2>/dev/null)" != "$size" ]; then
		size=$(stty size 2>/dev/null)
		printf '\033[2J'
		/usr/local/bin/hollywood-image-render "$map"
	fi
done
