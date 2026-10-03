#!/bin/sh
# Copy JPEG files to the same path under /, shrinking the big ones.
#
# The jp2a widget draws at most a few hundred columns of text, so a photo that is
# 5120 pixels wide is far larger than it needs to be. Photos 3000 pixels wide or
# more are shrunk to a quarter of their size, and photos 1500 pixels wide or more
# to half. Smaller files are copied as they are. If a file cannot be shrunk, it is
# copied unchanged.
#
# Run it from the folder that holds the files: shrink-jpeg.sh usr/share/x/a.jpg ...
for f in "$@"; do
	mkdir -p "/$(dirname "$f")"
	width=$(rdjpgcom -verbose "$f" | sed -n 's/^JPEG image is \([0-9]*\)w.*/\1/p')
	if [ "${width:-0}" -ge 3000 ]; then
		scale=4
	elif [ "${width:-0}" -ge 1500 ]; then
		scale=2
	else
		scale=1
	fi
	if [ "$scale" = 1 ] || ! djpeg -scale "1/$scale" "$f" | cjpeg -quality 85 -optimize > "/$f"; then
		cp "$f" "/$f"
	fi
done
