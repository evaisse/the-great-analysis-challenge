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

WORKDIR /app

# Install Elm
RUN npm install -g elm@0.19.1

# Copy package files
COPY package.json elm.json ./

# Install Node dependencies
RUN npm install

# Copy source files
COPY src ./src

# Build the Elm application
RUN mkdir -p dist && elm make src/ChessEngine.elm --output=dist/chess.js

# Run the chess engine
CMD ["node", "src/cli.js"]
