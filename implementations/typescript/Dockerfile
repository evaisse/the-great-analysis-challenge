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
COPY tsconfig.json ./
COPY Makefile ./

# Install dependencies
RUN npm install

# Copy source code
COPY src/ ./src/
COPY test/ ./test/

# Build the TypeScript project
RUN npm run build

# Create a non-root user
RUN useradd -ms /bin/bash chess && chown -R chess:chess /app

# Switch to non-root user
USER chess

# Default command to run the chess engine

LABEL org.chess.language="typescript"
LABEL org.chess.version="5.0"
LABEL org.chess.author="TypeScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.build="npm install && npm run build"
LABEL org.chess.test="npm install && npm test"
LABEL org.chess.analyze="npm install && npm run lint && npx tsc --noEmit && npx prettier --check src/*.ts"

CMD ["node", "dist/chess.js"]
