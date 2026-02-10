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
CMD ["./zig-out/bin/chess"]
