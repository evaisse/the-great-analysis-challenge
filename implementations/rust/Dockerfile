# Build stage
FROM rust:1.84-slim AS builder

WORKDIR /app
COPY . .

# Build the application
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

WORKDIR /app

# Copy the compiled binary from the builder stage
COPY --from=builder /app/target/release/chess /app/chess
COPY --from=builder /app/Makefile /app/Makefile

# Install make for the test suite
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

# Default command
CMD ["./chess"]
