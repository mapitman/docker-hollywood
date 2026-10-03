# docker-hollywood

[Hollywood](https://github.com/dustinkirkland/hollywood) in a container.

The image is based on `debian:testing-slim`, which ships Hollywood 1.25 with all 20 widgets.

## Usage

```sh
docker run -it --rm mapitman/hollywood
```

To exit, you may have to press `<ctrl> - c` multiple times. Once Hollywood
stops spawning windows, press `<ctrl> - d` to exit the container.

You can also stop it from another terminal with `docker stop hollywood`
(when you started it with `--name hollywood`).

When Hollywood exits, the entrypoint resets your terminal: it shows the cursor, leaves the
alternate screen and turns off mouse reporting. This also happens after `docker stop`.
It cannot happen after `docker kill`, because Docker ends the container with no chance to clean up.
If your cursor is missing after `docker kill`, run `reset` (or `tput cnorm`).

## Build and run locally

```sh
just build
just run
```

`just run` names the container `hollywood`, so you can stop it with `docker stop hollywood`.

## Widgets

Hollywood opens a tmux session and fills it with panes. Each pane runs one widget, which wraps an
ordinary tool. The image has 20 widgets.

| Widget | Shows |
|---|---|
| `apg` | random passwords from `/dev/urandom`, colored with `ccze` |
| `atop` | system and process monitor (needs 60 x 24) |
| `bat` | random source files from `/usr`, syntax highlighted with `batcat` |
| `bmon` | network bandwidth monitor (needs 48 x 26, or 141 x 18) |
| `cmatrix` | falling green characters, as in The Matrix |
| `code` | random C, C++, Java and Python files, highlighted with `pygmentize` |
| `errno` | the list of error codes, in random order |
| `figlet` | large ASCII words such as ACCESS GRANTED (needs 57 x 7) |
| `hexdump` | hex dumps of programs in `/usr/bin` |
| `htop` | interactive process viewer |
| `jp2a` | JPEG images drawn as ASCII art |
| `logs` | log files under `/var/log` |
| `man` | random man pages |
| `map` | a world map drawn as ASCII art with `jp2a` |
| `mplayer` | a sound-wave video drawn as ASCII art with `mplayer` |
| `pv` | a fake file-transfer progress bar |
| `speedometer` | network throughput graph |
| `sshart` | random `ssh-keygen` key art (needs 20 x 12) |
| `stat` | file details for random paths under `/sys` and `/dev` |
| `tree` | directory trees under `/sys` and `/dev` |

The Debian slim image removes man pages and documentation. The Dockerfile puts them back so the
`man` and `code` widgets have something to show.

The `jp2a` widget draws every JPEG it finds under `/usr`. Debian has no wallpaper package like Ubuntu's,
so the image has only one JPEG (the `map` picture), and `jp2a` shows it repeatedly.

## Pane count and refresh time

The entrypoint script sizes the number of panes to your terminal. Docker passes the
terminal size in character cells, so the script divides the cell count by 1400.
The result is limited to two panes per CPU and to the number of widgets, with a minimum of 2.
A 161x37 terminal (a full-screen terminal at 1920x1080 with a typical font) gives 4 panes.

Hollywood replaces all panes together every 60 seconds.

| Setting | Environment variable | Default |
|---|---|---|
| Cells per pane | `HOLLYWOOD_CELLS_PER_PANE` | `1400` |
| Seconds between refreshes | `HOLLYWOOD_DELAY` | `60` |

```sh
docker run -it --rm -e HOLLYWOOD_CELLS_PER_PANE=1000 -e HOLLYWOOD_DELAY=30 mapitman/hollywood
```

The `-s` (panes) and `-d` (delay in seconds) options override the computed values:

```sh
docker run -it --rm mapitman/hollywood -s 6 -d 30
```

To find your terminal size, run `stty size` (it prints rows, then columns).

## Widget size guard

Some widgets stop working in a small pane. The image runs every widget through a guard script
(`widget-guard.sh`). The guard checks the pane size when the widget starts and again after every resize.
If the pane is too small, the guard stops the widget and starts a different one that fits.

| Widget | Minimum columns x rows |
|---|---|
| `atop` | 60 x 24 |
| `bmon` | 48 x 26, or 141 x 18 (it asks you to enlarge the window below this) |
| `figlet` | 57 x 7 |
| `sshart` | 20 x 12 |

All other widgets run in any pane size. To change a minimum or add a widget, edit the `MIN_` tables
and the `min_rows` function at the top of `widget-guard.sh`.

With the default settings on a 161x37 terminal, no pane is 24 rows tall, so `atop` never runs there.

## No repeated widgets

No two panes run the same widget. Each running widget holds a claim in `/tmp/hollywood-claims`,
and a pane that starts or switches picks a widget that nobody else holds.
The `map` and `jp2a` widgets both run `jp2a`, so they share one claim.
If no unused widget fits in a pane, the pane closes instead of repeating a widget.
This only happens with many small panes (for example, 16 panes on a 320x90 terminal).

## Launcher patch

The `hollywood` package picks one random pane for each split. When tmux refuses the split because that pane
is too small, the launcher does not retry, so you get fewer panes than requested.
`launcher-retry-splits.patch` makes the launcher try every pane in random order, in both directions,
until one has room. The Docker build applies the patch with no fuzz, so the build fails if a new
`hollywood` package changes the patched code.
