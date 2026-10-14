ARG DISTRO=xenial

FROM ubuntu:$DISTRO

RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
        ca-certificates \
        git \
        make

# Run unsafe tests:
ENV CI=y

COPY [".", "/src"]
WORKDIR /src
CMD ["make", "test"]
