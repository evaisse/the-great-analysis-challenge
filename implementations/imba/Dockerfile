# Use Ubuntu base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Node.js from Ubuntu repos
RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (including Imba)
RUN npm config set strict-ssl false && npm install

# Copy source code
COPY src/ ./src/

# Create a non-root user
RUN addgroup --gid 1001 nodejs && \
    adduser --system --uid 1001 chess

# Change ownership of the app directory
RUN chown -R chess:nodejs /app

# Switch to non-root user
USER chess

# Default command to run the chess engine
CMD ["npx", "imba", "run", "src/chess.imba"]
