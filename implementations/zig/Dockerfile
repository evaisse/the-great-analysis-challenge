# Use Debian base image
FROM debian:bookworm-slim

# Set working directory
WORKDIR /app

# Install dependencies and Zig
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    make \
    && curl -L https://ziglang.org/download/0.13.0/zig-linux-$(uname -m | sed 's/arm64/aarch64/' | sed 's/x86_64/x86_64/')-0.13.0.tar.xz | tar -xJ --strip-components=1 -C /usr/local/bin \
    && rm -rf /var/lib/apt/lists/*

# Copy source code
COPY . .

# Build the application
RUN zig build -Doptimize=ReleaseFast

# Default command

LABEL org.chess.language="zig"
LABEL org.chess.version="0.13.0"
LABEL org.chess.author="Zig Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.run="zig run src/main.zig"
LABEL org.chess.build="zig build"
LABEL org.chess.test="zig test src/main.zig"
LABEL org.chess.analyze="zig fmt --check src/ && zig test src/main.zig"

CMD ["./zig-out/bin/chess"]
