# Use official Node Alpine image
FROM node:22-alpine

# Set working directory
WORKDIR /app

# Copy project files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies including TypeScript compiler
RUN npm install

# Copy source code
COPY src/ ./src/
COPY test/ ./test/

# Build the TypeScript project
RUN npm run build

# Default command to run the chess engine

LABEL org.chess.language="typescript"
LABEL org.chess.version="5.0"
LABEL org.chess.author="TypeScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.build="npm install && npm run build"
LABEL org.chess.test="npm test"
LABEL org.chess.analyze="npm run lint && npx tsc --noEmit && npx prettier --check src/*.ts"

CMD ["node", "dist/chess.js"]
