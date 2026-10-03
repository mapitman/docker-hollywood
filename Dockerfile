FROM debian:trixie-slim
ARG VCS_REF
ARG BUILD_DATE
LABEL maintainer="Mark Pitman <pitman.io>"
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# The slim image strips man pages and docs. Hollywood's "man" and "code"
# widgets display them, so allow them back in before installing anything.
RUN rm -f /etc/dpkg/dpkg.cfg.d/docker* \
    && sed -i '/path-exclude/d' /etc/dpkg/dpkg.cfg.d/* 2>/dev/null; true

# One package per widget tool. Recommends are off so the list below is the
# complete set of tools Hollywood can use. The Hollywood scripts themselves come
# from the upstream source below, not from a package.
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
        byobu tmux procps ncurses-term \
        apg atop bat bmon bsdextrautils ccze cmatrix figlet htop \
        man-db manpages moreutils mplayer openssh-client pv python3 python3-pil python3-pygments \
        speedometer tree \
    && apt-get -y --reinstall install coreutils findutils \
    && rm -rf /var/lib/apt/lists/*

# Install Hollywood from the upstream source at the commit tagged 1.25. The
# Debian stable package is version 1.21, which has broken widgets and a launcher
# that loses the -s and -d options. The layout matches the Debian package:
# launcher in /usr/games, widgets in /usr/lib/hollywood, data in /usr/share.
ADD https://github.com/dustinkirkland/hollywood.git#4bfa29772a6e2f1e4aecbd3e26fde7dc69cce6eb /usr/src/hollywood
RUN install -D -m 755 /usr/src/hollywood/bin/hollywood /usr/games/hollywood \
    && mkdir -p /usr/lib /usr/share/man/man1 \
    && cp -a /usr/src/hollywood/lib/hollywood /usr/lib/hollywood \
    && cp -a /usr/src/hollywood/share/hollywood /usr/share/hollywood \
    && install -m 644 /usr/src/hollywood/share/man/man1/hollywood.1 /usr/share/man/man1/hollywood.1 \
    && rm -rf /usr/src/hollywood

# The jp2a widget draws every JPEG file it finds under /usr, and the image has
# only one of its own. Add the wallpapers from the KDE Plasma package. Only the
# JPEG files are kept, with the package's folder layout, because many files share
# a name such as 5120x2880.jpg. shrink-jpeg.sh shrinks the big photos while it
# copies them, which keeps the image about 90 MB smaller. The package's copyright
# file stays with the files. The wallpapers are licensed GPL-2+. The last command
# fails the build if too few wallpapers were installed.
COPY --chmod=755 shrink-jpeg.sh /tmp/shrink-jpeg.sh
RUN apt-get update \
    && apt-get -y install --no-install-recommends libjpeg-turbo-progs \
    && cd /tmp \
    && apt-get download plasma-workspace-wallpapers \
    && dpkg-deb -x plasma-workspace-wallpapers_*.deb /tmp/wallpapers \
    && cd /tmp/wallpapers \
    && find usr -iname '*.jpg' -exec /tmp/shrink-jpeg.sh {} + \
    && install -D -m 644 usr/share/doc/plasma-workspace-wallpapers/copyright \
        /usr/share/doc/plasma-workspace-wallpapers/copyright \
    && cd / \
    && apt-get -y purge libjpeg-turbo-progs \
    && rm -rf /tmp/wallpapers /tmp/*.deb /tmp/shrink-jpeg.sh /var/lib/apt/lists/* \
    && [ "$(find /usr/share/wallpapers -name '*.jpg' -size +0 | wc -l)" -ge 150 ]

# Replace the mplayer widget. The one in Hollywood draws the video with libcaca,
# which fills the pane with random letters that change on every frame. The
# replacement scales the video to the pane and draws it in true color with half
# blocks. It needs the renderer script.
COPY --chmod=755 mplayer-widget.sh /usr/lib/hollywood/mplayer
COPY --chmod=755 soundwave-render.py /usr/local/bin/hollywood-soundwave-render

# Replace the jp2a and map widgets too. Hollywood's draw pictures as letters in the
# eight basic terminal colors with the jp2a program. The jp2a widget changes
# pictures twice a second, and the map widget prints its picture again every second,
# so its pane scrolls all the time. The replacements draw each picture in 256 colors
# with half blocks, so the jp2a program is not needed.
COPY --chmod=755 image-widget.sh /usr/lib/hollywood/jp2a
COPY --chmod=755 map-widget.sh /usr/lib/hollywood/map
COPY --chmod=755 image-render.py /usr/local/bin/hollywood-image-render

# Byobu asks which mode ctrl-a should use the first time you press it. Choose
# GNU Screen mode (option 1) now so the question never appears.
RUN byobu-ctrl-a screen

# The stock launcher gives up on a pane when tmux refuses a split because the
# chosen pane is too small, so you sometimes get fewer panes than requested. It
# also leaves the panes at uneven sizes. The launcher patch retries other panes
# and arranges an even number of panes in a grid of equal sizes. The patch applies
# with no fuzz, so the build fails if the Hollywood source changes the code it
# patches.
COPY launcher.patch /tmp/launcher.patch
COPY --chmod=755 even-layout.sh /usr/local/bin/hollywood-layout
RUN apt-get update \
    && apt-get -y install --no-install-recommends patch \
    && patch --fuzz=0 /usr/games/hollywood /tmp/launcher.patch \
    && apt-get -y purge patch \
    && rm -rf /var/lib/apt/lists/* /tmp/launcher.patch

# Move the real widgets aside and put a size guard in their place. The real
# widgets keep a ".../lib/hollywood/" path because they stop each other with
# "pkill -f lib/hollywood/" when you press ctrl-c. The widgets "map" and
# "mplayer" read files from ../../share/hollywood, so link that directory too.
COPY --chmod=755 widget-guard.sh /usr/local/bin/hollywood-widget
RUN mkdir -p /opt/hollywood/lib /opt/hollywood/share \
    && mv /usr/lib/hollywood /opt/hollywood/lib/hollywood \
    && ln -s /usr/share/hollywood /opt/hollywood/share/hollywood \
    && mkdir /usr/lib/hollywood \
    && for w in $(ls /opt/hollywood/lib/hollywood); do \
         ln -s /usr/local/bin/hollywood-widget /usr/lib/hollywood/$w; \
       done

COPY --chmod=755 entrypoint.sh /usr/local/bin/hollywood-entrypoint

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/mapitman/docker-hollywood"
ENTRYPOINT ["/usr/local/bin/hollywood-entrypoint"]
