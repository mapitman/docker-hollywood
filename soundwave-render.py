#!/usr/bin/env python3
"""Draw a YUV4MPEG2 video stream on the terminal with half-block characters.

Each terminal cell shows two vertical pixels: the top pixel is the text color of
the upper half block and the bottom pixel is the background color. The video
must already have the size columns x (2 * rows), with the number of columns
rounded down to an even number (the chroma planes need an even width). The last
column of a pane with an odd width stays empty. The script exits with status 3
when the terminal size changes, so the caller can start the video again at the
new size.
"""
import os
import signal
import sys

OUT = sys.stdout.fileno()
IN = sys.stdin.buffer
BLACK = 16  # xterm-256 color 16 is black
DARK = 28   # luma below this counts as black
SHOW_CURSOR = b"\x1b[0m\x1b[?25h"

# Map a channel value 0..255 to a level 0..5 of the xterm 6x6x6 color cube.
LEVEL = bytes(0 if v < 48 else 1 if v < 115 else 2 if v < 155 else 3 if v < 195 else 4 if v < 235 else 5
              for v in range(256))
cache = {}


def terminal_size():
    size = os.get_terminal_size(OUT)
    return size.columns, size.lines


def color(y, u, v):
    """Return the xterm-256 color index for a YUV pixel (BT.601)."""
    key = (y << 16) | (u << 8) | v
    index = cache.get(key)
    if index is None:
        luma = 298 * (y - 16)
        r = (luma + 409 * (v - 128) + 128) >> 8
        g = (luma - 100 * (u - 128) - 208 * (v - 128) + 128) >> 8
        b = (luma + 516 * (u - 128) + 128) >> 8
        r, g, b = (0 if c < 0 else 255 if c > 255 else c for c in (r, g, b))
        index = 16 + 36 * LEVEL[r] + 6 * LEVEL[g] + LEVEL[b]
        cache[key] = index
    return index


def stop(signum, frame):
    os.write(OUT, SHOW_CURSOR)
    sys.exit(0)


def main():
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, stop)
    header = IN.readline()
    if not header.startswith(b"YUV4MPEG2"):
        return 1
    width = height = 0
    for token in header.split():
        if token[:1] == b"W":
            width = int(token[1:])
        elif token[:1] == b"H":
            height = int(token[1:])
    cols, rows = terminal_size()
    if width != cols - cols % 2 or height != 2 * rows:
        return 3
    luma_size = width * height
    chroma_size = (width // 2) * (height // 2)
    chroma_width = width // 2

    os.write(OUT, b"\x1b[?25l\x1b[0m\x1b[2J")
    frames = 0
    while True:
        if not IN.readline().startswith(b"FRAME"):
            break
        data = IN.read(luma_size + 2 * chroma_size)
        if len(data) < luma_size + 2 * chroma_size:
            break
        frames += 1
        if frames % 8 == 0 and terminal_size() != (cols, rows):
            os.write(OUT, SHOW_CURSOR)
            return 3
        luma = data[:luma_size]
        cb = data[luma_size:luma_size + chroma_size]
        cr = data[luma_size + chroma_size:]
        parts = []
        for row in range(rows):
            parts.append(b"\x1b[%d;1H" % (row + 1))
            top = 2 * row * width
            bottom = top + width
            chroma_row = row * chroma_width
            state = None
            for x in range(width):
                c = chroma_row + (x >> 1)
                u, v = cb[c], cr[c]
                yt, yb = luma[top + x], luma[bottom + x]
                fg = BLACK if yt < DARK else color(yt, u, v)
                bg = BLACK if yb < DARK else color(yb, u, v)
                if fg == BLACK and bg == BLACK:
                    if state is not None:
                        parts.append(b"\x1b[0m")
                        state = None
                    parts.append(b" ")
                else:
                    if state != (fg, bg):
                        parts.append(b"\x1b[38;5;%d;48;5;%dm" % (fg, bg))
                        state = (fg, bg)
                    parts.append("▀".encode())
            if state is not None:
                parts.append(b"\x1b[0m")
        os.write(OUT, b"".join(parts))
    os.write(OUT, SHOW_CURSOR)
    return 0


if __name__ == "__main__":
    sys.exit(main())
