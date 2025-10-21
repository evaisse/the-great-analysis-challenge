# Multi-stage build for Crystal Chess Engine
FROM crystallang/crystal:1.14 AS builder

WORKDIR /app

# Copy source files
COPY shard.yml ./
COPY src/ ./src/

# Build the application
RUN crystal build src/chess_engine.cr --release --static -o chess_engine

# Final stage with minimal base image
FROM alpine:3.18

WORKDIR /app

# Copy the built binary
COPY --from=builder /app/chess_engine ./

# Make executable
RUN chmod +x chess_engine

# Default command
CMD ["./chess_engine"]