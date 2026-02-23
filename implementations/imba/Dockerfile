FROM ghcr.io/evaisse/tgac-imba-toolchain:latest

COPY . .

RUN npm run build

LABEL org.chess.language="imba"
LABEL org.chess.version="2.0"
LABEL org.chess.author="Imba Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.build="npm run build"
LABEL org.chess.test="node dist/chess.js --test"
LABEL org.chess.analyze="npx imba check src/chess.imba"

CMD ["node", "dist/chess.js"]
