# Use Debian base image
FROM debian:bookworm-slim

# Set working directory
WORKDIR /app

# Install Lua and build dependencies
RUN apt-get update && apt-get install -y \
    lua5.4 \
    build-essential \
    make \
    && rm -rf /var/lib/apt/lists/*

# Copy source code
COPY . .

# Create a non-root user
RUN addgroup --system lua && \
    adduser --no-create-home --shell /bin/false --disabled-password --system --ingroup lua chess

# Change ownership of the app directory
RUN chown -R chess:lua /app

# Switch to non-root user
USER chess

# Make chess.lua executable
RUN chmod +x chess.lua

# Default command to run the chess engine
CMD ["lua5.4", "chess.lua"]
