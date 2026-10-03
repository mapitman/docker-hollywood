FROM debian:testing-slim
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
# complete set of tools Hollywood can use.
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
        hollywood byobu tmux procps ncurses-term \
        apg atop bat bmon bsdextrautils ccze cmatrix figlet htop jp2a \
        man-db manpages mplayer openssh-client pv python3-pygments \
        speedometer tree \
    && apt-get -y --reinstall install coreutils findutils \
    && rm -rf /var/lib/apt/lists/*

# The stock launcher gives up on a pane when tmux refuses a split because the
# chosen pane is too small, so you sometimes get fewer panes than requested.
# The patch retries other panes. It applies with no fuzz, so the build fails if
# the Hollywood package changes the code it patches.
COPY launcher-retry-splits.patch /tmp/launcher-retry-splits.patch
RUN apt-get update \
    && apt-get -y install --no-install-recommends patch \
    && patch --fuzz=0 /usr/games/hollywood /tmp/launcher-retry-splits.patch \
    && apt-get -y purge patch \
    && rm -rf /var/lib/apt/lists/* /tmp/launcher-retry-splits.patch

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
