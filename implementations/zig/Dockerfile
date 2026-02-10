FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig
RUN ZIG_VERSION="0.12.0" \
    && wget "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" \
    && tar -xf "zig-linux-x86_64-${ZIG_VERSION}.tar.xz" \
    && mv "zig-linux-x86_64-${ZIG_VERSION}" /opt/zig \
    && ln -s /opt/zig/zig /usr/local/bin/zig \
    && rm "zig-linux-x86_64-${ZIG_VERSION}.tar.xz"

WORKDIR /app

# Copy source files
COPY build.zig ./
COPY src/ ./src/

# Build the application
RUN zig build

# Make executable
RUN chmod +x zig-out/bin/chess

# Default command
CMD ["./zig-out/bin/chess"]