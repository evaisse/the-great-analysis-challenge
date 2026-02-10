# Build stage
FROM node:22-slim AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# Runtime stage
FROM node:22-slim

# Install make for the test suite
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/Makefile ./Makefile

LABEL org.chess.language="imba"
LABEL org.chess.version="2.0"
LABEL org.chess.author="Imba Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000

# Default command
CMD ["node", "dist/chess.js"]
