FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV ZIG_VERSION=0.11.0
ENV ZIG_ARCH=x86_64

# Install dependencies
RUN export http_proxy="" && export https_proxy="" && apt-get update && apt-get install -y wget xz-utils

# Download and install Zig
RUN export http_proxy="" && export https_proxy="" && wget https://ziglang.org/download/${ZIG_VERSION}/zig-linux-${ZIG_ARCH}-${ZIG_VERSION}.tar.xz && \
    tar -xf zig-linux-${ZIG_ARCH}-${ZIG_VERSION}.tar.xz && \
    mv zig-linux-${ZIG_ARCH}-${ZIG_VERSION} /usr/local/share/zig && \
    ln -s /usr/local/share/zig/zig /usr/local/bin/zig && \
    rm zig-linux-${ZIG_ARCH}-${ZIG_VERSION}.tar.xz

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