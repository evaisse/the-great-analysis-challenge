# Use official Crystal image
FROM crystal:1.15-alpine

# Install make for the test suite
RUN apk add --no-cache make

# Set working directory
WORKDIR /app

# Copy source files
COPY shard.yml ./
COPY src/ ./src/

# Build the application
RUN crystal build src/chess_engine.cr --release -o chess_engine

# Make executable
RUN chmod +x chess_engine

# Default command
CMD ["./chess_engine"]
