ARG DISTRO=xenial

FROM ubuntu:$DISTRO

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends ca-certificates git make

RUN git config --global --add safe.directory /src

COPY [".", "/src"]

WORKDIR /src

CMD ["make", "test/local", "test/linux-home"]
