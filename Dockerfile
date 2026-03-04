FROM ubuntu:latest
ARG VCS_REF
ARG BUILD_DATE
MAINTAINER Mark Pitman <pitman.io>
RUN yes | unminimize
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install byobu hollywood ubuntu-wallpapers python3-pygments man curl man-db
RUN updatedb
RUN cp $(locate *.c) /usr
RUN mv /usr/share/backgrounds/* /usr/
LABEL   org.label-schema.build-date=$BUILD_DATE \
        org.label-schema.vcs-ref=$VCS_REF\
        org.label-schema.vcs-url="https://github.com/mapitman/dockerfiles/hollywood"
ENTRYPOINT ["hollywood"]
