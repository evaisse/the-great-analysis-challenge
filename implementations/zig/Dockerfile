ARG ZIG_IMAGE=jfrog.int.bourso.net/web-v-docker/ziglings/ziglang:latest
ARG MAKE_IMAGE=jfrog.int.bourso.net/web-v-docker/buildpack-deps:bookworm
ARG MAKE_PLATFORM=linux/amd64
ARG ZIG_PLATFORM=linux/amd64
FROM --platform=$MAKE_PLATFORM ${MAKE_IMAGE} AS make

FROM --platform=$ZIG_PLATFORM ${ZIG_IMAGE}

# Set working directory
WORKDIR /app

# Ensure make is available for containerized test/analyze targets
# The base image is minimal, so copy make + libdl from a buildpack-deps stage.
RUN mkdir -p /lib/x86_64-linux-gnu
COPY --from=make /usr/bin/make /usr/bin/make
COPY --from=make /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
RUN if [ ! -e /lib/x86_64-linux-gnu/libc.so.6 ]; then \
        ln -s /lib/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6; \
    fi

# Copy source code
COPY . .

# Build the application
RUN zig build -Doptimize=ReleaseFast

# Default command

LABEL org.chess.language="zig"
LABEL org.chess.version="latest"
LABEL org.chess.author="Zig Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.build="make docker-build"
LABEL org.chess.run="./zig-out/bin/chess"
LABEL org.chess.test="make docker-test"
LABEL org.chess.analyze="docker run --network none --rm chess-zig zig fmt --check src/"

CMD ["./zig-out/bin/chess"]
