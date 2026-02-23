# Use official Node Alpine image
FROM node:22-alpine

# Set working directory
WORKDIR /app

# Copy project files
COPY package*.json ./
COPY bsconfig.json ./

# Install dependencies including ReScript compiler
RUN npm install

# Copy source code
COPY src/ ./src/

# Build the ReScript project
RUN npm run build

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
