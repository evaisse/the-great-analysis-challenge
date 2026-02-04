# Use Ubuntu base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Node.js
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY bsconfig.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY src/ ./src/

# Build the ReScript project
RUN npm run build

# Create a non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S chess -u 1001

# Change ownership of the app directory
RUN chown -R chess:nodejs /app

# Switch to non-root user
USER chess

# Expose port (not needed for CLI but good practice)
EXPOSE 3000

# Default command to run the chess engine
CMD ["node", "lib/es6/src/Chess.js"]

# Alternative commands for different use cases:
# To build only: docker run --rm chess-engine npm run build
# To run tests: docker run --rm chess-engine npm test
# Interactive mode: docker run -it chess-engine