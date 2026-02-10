FROM node:22-slim

# Install make
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

LABEL org.chess.language="javascript"
LABEL org.chess.version="1.0.0"
LABEL org.chess.author="JavaScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# Ensure chess.js is executable
RUN chmod +x chess.js

# Default command
CMD ["node", "chess.js"]
