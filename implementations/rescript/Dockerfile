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

LABEL org.chess.language="rescript"
LABEL org.chess.version="10.0"
LABEL org.chess.author="ReScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1500
LABEL org.chess.build="npm install && npm run build"
LABEL org.chess.test="node lib/es6/src/Chess.js"
LABEL org.chess.analyze="npx rescript build"

CMD ["node", "lib/es6/src/Chess.js"]
