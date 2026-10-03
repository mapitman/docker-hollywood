# docker-hollywood

[Hollywood](https://github.com/dustinkirkland/hollywood) in a container.

The image is based on `debian:trixie-slim` (Debian 13, the current stable release).
It installs Hollywood 1.25 from the upstream source at a pinned commit, with all 20 widgets.

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

The `jp2a` widget draws every JPEG it finds under `/usr`. The image has only one JPEG (the `map` picture),
so `jp2a` shows it repeatedly.

## Pane count and widget time

The entrypoint script sizes the number of panes to your terminal. Docker passes the
terminal size in character cells, so the script divides the cell count by 1400.
The result is limited to two panes per CPU and to the number of widgets, with a minimum of 2.
A 161x37 terminal (a full-screen terminal at 1920x1080 with a typical font) gives 4 panes.

Each pane keeps its widget for 60 to 90 seconds, then swaps in another unused widget.
Every pane picks its own time, so the panes change at different moments.
Every 10 minutes the window is rebuilt: one pane stays, the others are replaced, and the panes are laid out
again at random.

| Setting | Environment variable | Default |
|---|---|---|
| Cells per pane | `HOLLYWOOD_CELLS_PER_PANE` | `1400` |
| Minimum seconds a pane keeps a widget (the maximum is 1.5 times this) | `HOLLYWOOD_DELAY` | `60` |
| Seconds between layout rebuilds (`0` turns the rebuild off) | `HOLLYWOOD_REBUILD` | `600` |

```sh
docker run -it --rm -e HOLLYWOOD_CELLS_PER_PANE=1000 -e HOLLYWOOD_DELAY=30 mapitman/hollywood
```

The `-s` (panes) and `-d` (minimum seconds a pane keeps a widget) options override the computed values:

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
If no unused widget fits in a new pane, the pane closes instead of repeating a widget.
This only happens with many small panes (for example, 16 panes on a 320x90 terminal).
When a pane is ready to swap and no other widget is free, it keeps its current widget.

## Launcher patch

The Hollywood launcher picks one random pane for each split. When tmux refuses the split because that pane
is too small, the launcher does not retry, so you get fewer panes than requested.
`launcher-retry-splits.patch` makes the launcher try every pane in random order, in both directions,
until one has room. The Docker build applies the patch with no fuzz, so the build fails if a new
Hollywood source changes the patched code.

## Why these changes

This image changes how Hollywood runs in several ways. Each change fixes a problem we found.

- **Debian stable base.** `debian:trixie-slim` is a named release, so the base does not change between builds
  except for security fixes. It has every tool the widgets need, including `mplayer`.
- **Hollywood from the upstream source.** The Dockerfile fetches the commit tagged `1.25` (`4bfa297`), so the
  Hollywood scripts do not change between builds. This version has all 20 widgets. Its launcher passes the values of
  `-s` and `-d` to its own tmux session, which the entrypoint needs. Its `sshart` widget works with current OpenSSH.
- **Pane count from terminal size.** Hollywood defaults to two panes per CPU. On an 8-CPU machine that is
  16 panes, which are too small to read on a 1920x1080 screen. The entrypoint sizes the count to the terminal.
- **60 to 90 seconds per widget.** Hollywood replaces every pane every 10 seconds by default. That is not long
  enough to see what is happening in each widget. Some examples:
  - The `bmon` graph covers 60 seconds of history, so a pane that lasts 10 seconds shows only the first sixth of it.
  - The `code` widget shows each file for 2 seconds and the `bat` widget for 3, so 10 seconds is only a few files.
- **Panes change one at a time.** Hollywood replaces all panes at the same moment, so you cannot finish reading one
  before it disappears. The widget guard gives each pane its own random time between the delay and 1.5 times the delay,
  then swaps the widget inside the pane. Swapping does not rebuild the window. The launcher's own refresh now runs
  only every 10 minutes, so the pane layout still changes now and then.
- **Launcher patch.** The launcher picks one random pane per split and never retries. When that pane was too small,
  tmux refused the split and the window ended up with fewer panes than requested. At 161x37, 2 of 8 launches gave
  3 panes instead of 4.
- **Widget size guard.** Some widgets keep running in a pane that is too small and show a message instead of content:
  `atop` asks for 60 x 24, and `bmon` asks you to enlarge the window. At 161x37 the largest panes are 18 rows tall.
  A pane also shrinks while the launcher splits later panes, so the guard checks again on every resize.
- **No repeated widgets.** The launcher picks the first widget separately from the rest, so two panes can start
  with the same widget. The guard keeps one widget per pane, both at the start and when panes swap.
- **Terminal reset on exit.** `cmatrix` and `mplayer` hide the cursor, switch to the alternate screen and turn on
  mouse reporting. They cannot undo this when the container stops, so the terminal had no cursor afterward.
- **Man pages and docs restored.** The slim image removes them, and the `man` and `code` widgets need them.
