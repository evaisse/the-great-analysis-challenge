# Multi-stage build for Zig Chess Engine
FROM alpine:3.18 AS builder

# Install dependencies
RUN apk add --no-cache \
    curl \
    xz \
    tar

# Download and install Zig
RUN curl -L https://ziglang.org/builds/zig-linux-x86_64-0.13.0.tar.xz -o /tmp/zig.tar.xz && \
    cd /tmp && \
    tar -xf zig.tar.xz && \
    mv zig-linux-x86_64-0.13.0 /usr/local/zig

ENV PATH="/usr/local/zig:${PATH}"

WORKDIR /app

# Copy source files
COPY build.zig ./
COPY src/ ./src/

# Build the application
RUN zig build -Doptimize=ReleaseFast

# Final stage with minimal base image
FROM alpine:3.18

WORKDIR /app

# Copy the built binary
COPY --from=builder /app/zig-out/bin/chess ./

# Make executable
RUN chmod +x chess

# Default command
CMD ["./chess"]