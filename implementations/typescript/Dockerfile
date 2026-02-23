FROM ghcr.io/evaisse/tgac-typescript-toolchain:latest

COPY . .

RUN npm run build

LABEL org.chess.language="typescript"
LABEL org.chess.version="5.0"
LABEL org.chess.author="TypeScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.build="npm run build"
LABEL org.chess.test="npm test"
LABEL org.chess.analyze="npm run lint"

CMD ["node", "dist/chess.js"]
