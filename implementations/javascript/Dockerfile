FROM node:22-alpine

LABEL org.chess.language="javascript"
LABEL org.chess.version="1.0.0"
LABEL org.chess.author="JavaScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.build="npm install"
LABEL org.chess.test="npm test"
LABEL org.chess.analyze="npm run lint"

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# Ensure chess.js is executable
RUN chmod +x chess.js

# Default command
CMD ["node", "chess.js"]
