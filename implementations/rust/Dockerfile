# Build stage
FROM rust:1.84-slim AS builder

WORKDIR /app
COPY . .

# Build the application
RUN cargo build --release

# Runtime stage
FROM rust:1.84-slim

WORKDIR /app

# Install make for the test suite
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

# Copy the compiled binary and source code from the builder stage
COPY --from=builder /app /app

# Default command
CMD ["./target/release/chess"]
