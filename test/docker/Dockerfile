ARG DISTRO=xenial

FROM ubuntu:$DISTRO

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends ca-certificates git

RUN git config --global --add safe.directory /src
