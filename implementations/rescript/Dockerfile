# Use official Node image
FROM node:22-slim

# Install minimal build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    make \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy project files
COPY package*.json ./
COPY bsconfig.json ./
COPY Makefile ./

# Install dependencies
RUN npm install

# Copy source code
COPY src/ ./src/

# Build the ReScript project
RUN npm run build

# Create a non-root user
RUN useradd -ms /bin/bash chess && chown -R chess:chess /app

# Switch to non-root user
USER chess

# Default command to run the chess engine
CMD ["node", "lib/es6/src/Chess.js"]
