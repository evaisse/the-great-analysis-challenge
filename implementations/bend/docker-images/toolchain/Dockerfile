# Bend 2 toolchain, built from source.
#
# Bend 2 ships no package-manager release (only prebuilt archives), so this
# dedicated image builds it from its pinned source tag instead: the compiler
# is TypeScript run by Bun, and native builds go through clang (14+).
FROM oven/bun:1-debian

ARG BEND_VERSION=2.0.40

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates clang git make \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "v${BEND_VERSION}" https://github.com/bendlang/bend.git /opt/bend \
    && rm -rf /opt/bend/.git /opt/bend/media /opt/bend/paper /opt/bend/bench /opt/bend/evals \
    && printf '#!/bin/sh\nexec bun /opt/bend/bend2/main.ts "$@"\n' > /usr/local/bin/bend \
    && chmod +x /usr/local/bin/bend

# no daily version check from inside the container
ENV BEND_NO_TELEMETRY=1
ENV CC=clang

RUN bend version

WORKDIR /app
