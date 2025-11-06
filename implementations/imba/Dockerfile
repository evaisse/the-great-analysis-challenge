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
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (including Imba)
RUN npm install

# Copy source code
COPY src/ ./src/

# Build the Imba project
RUN npm run build

# Create a non-root user
RUN addgroup --gid 1001 nodejs && \
    adduser --system --uid 1001 chess

# Change ownership of the app directory
RUN chown -R chess:nodejs /app

# Switch to non-root user
USER chess

# Default command to run the chess engine
CMD ["node", "dist/chess.js"]
