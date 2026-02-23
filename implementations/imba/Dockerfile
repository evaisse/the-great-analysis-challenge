# Build stage
FROM node:22-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# Runtime stage
FROM node:22-alpine

WORKDIR /app
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

LABEL org.chess.language="imba"
LABEL org.chess.version="2.0"
LABEL org.chess.author="Imba Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.build="npm install && npm run build"
LABEL org.chess.test="node dist/chess.js --test"
LABEL org.chess.analyze="npx imba check src/chess.imba"

# Default command
CMD ["node", "dist/chess.js"]
