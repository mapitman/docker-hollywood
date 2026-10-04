# Third-party software and licenses

The files in this repository are licensed under the MIT license (see `LICENSE`), except where a file says
otherwise. The image that the repository builds also contains software from other projects. Each project keeps
its own license. This file lists them and says what this project changed.

The image carries a copy of this file at `/usr/share/doc/hollywood/THIRD-PARTY.md`.

## Hollywood

- **Project:** <https://github.com/dustinkirkland/hollywood>
- **Copyright:** 2014 Dustin Kirkland
- **License:** Apache License 2.0. The full text is `/usr/share/common-licenses/Apache-2.0` in the image, and
  `/usr/share/doc/hollywood/LICENSE` links to it. Hollywood's own copyright file (`debian/copyright` from its
  source) is `/usr/share/doc/hollywood/copyright`.
- **Source:** the Docker build downloads Hollywood from the commit tagged `1.25`
  (`4bfa29772a6e2f1e4aecbd3e26fde7dc69cce6eb`). Hollywood's source is not copied into this repository.

### Changes made to Hollywood

- **The launcher** (`bin/hollywood`) is patched during the build with `launcher.patch`. A split that tmux refuses
  is tried again in other panes, and an even number of panes is arranged in a grid of equal sizes with
  `even-layout.sh`. The patched launcher carries a notice that says it was modified.
- **Three widgets are replaced:** `mplayer`, `jp2a` and `map`. They are `mplayer-widget.sh`, `image-widget.sh` and
  `map-widget.sh`, with the renderers `soundwave-render.py` and `image-render.py`. Each script says it is based on
  the Hollywood widget it replaces.
- **Everything else is unchanged:** the other widgets and the bundled `map.jpg` and `soundwave.mp4` are used as they are.

### Files in this repository that come from Hollywood

`launcher.patch`, `mplayer-widget.sh`, `image-widget.sh` and `map-widget.sh` contain or follow parts of Hollywood.
Those parts stay under the Apache License 2.0. The changes that this project made to them are licensed under the
MIT license. The other files here, such as `entrypoint.sh`, `widget-guard.sh`, `even-layout.sh`,
`shrink-jpeg.sh` and the Dockerfile, were written for this project.

## KDE Plasma wallpapers

- **Package:** `plasma-workspace-wallpapers` from Debian 13 (trixie).
- **License:** GPL-2+ according to the package's copyright file, which the image keeps at
  `/usr/share/doc/plasma-workspace-wallpapers/copyright`. The GPL-2 text is `/usr/share/common-licenses/GPL-2`.
- **What is in the image:** only the JPEG files, in `/usr/share/wallpapers`. `shrink-jpeg.sh` makes photos that are
  1500 pixels wide or more smaller during the build, so those files are modified copies.
- **Source:** `apt-get source plasma-workspace-wallpapers` on a Debian 13 system.

## Debian base image and packages

The image starts from `debian:trixie-slim` and installs packages with `apt` (tmux, byobu, mplayer, atop, htop,
bmon, cmatrix, figlet and others). Each package's license is in `/usr/share/doc/<package>/copyright` in the
image, and its source is available with `apt-get source <package>`.
