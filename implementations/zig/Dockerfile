FROM ziglang/zig:0.11.0

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