# Use the official Crystal image for version 1.11.2
FROM crystal:1.11.2-alpine

# Set working directory
WORKDIR /app

# Copy source files
COPY shard.yml ./
COPY src/ ./src/

# The official image should already contain necessary build tools.
# If the project requires specific C libraries, they should be added here using `apk add`.
# Assuming core libraries are covered for a typical chess engine.

# Build the application
# We use a release build for performance
RUN crystal build src/chess_engine.cr --release -o chess_engine

# Make executable
RUN chmod +x chess_engine

# Default command
CMD ["./chess_engine"]
