# Build stage
FROM ziglang/zig:0.13.0 AS builder

WORKDIR /app
COPY . .

# Build the application
RUN zig build -Doptimize=ReleaseFast

# Runtime stage
FROM alpine:3.20

WORKDIR /app

# Copy the compiled binary and necessary files
COPY --from=builder /app/zig-out/bin/chess /app/chess
COPY --from=builder /app/Makefile /app/Makefile

# Install make for the test suite
RUN apk add --no-cache make

# Default command
CMD ["./chess"]
