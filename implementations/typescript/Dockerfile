# Use Ubuntu base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Node.js
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and npm
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs npm

# Set working directory
WORKDIR /app

# Copy project files needed for dependency install and make targets
COPY package*.json ./
COPY tsconfig.json ./
COPY Makefile ./

# Install dependencies
RUN npm install

# Copy source code
COPY src/ ./src/
COPY test/ ./test/

# Build the TypeScript project
RUN npm run build

# Create a non-root user for running the engine
RUN useradd -ms /bin/bash chess

# Change ownership of the app directory to the non-root user
RUN chown -R chess:chess /app

# Switch to non-root user
USER chess

# Expose port (not needed for CLI but good practice)
EXPOSE 3000

# Default command to run the chess engine
CMD ["node", "dist/chess.js"]

# Alternative commands for different use cases:
# To build only: docker run --rm chess-engine npm run build
# To run tests: docker run --rm chess-engine npm test
# Interactive mode: docker run -it chess-engine
