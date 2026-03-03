FROM ghcr.io/evaisse/tgac-rescript-toolchain:latest

COPY . .

LABEL org.chess.language="rescript"
LABEL org.chess.version="10.0"
LABEL org.chess.author="ReScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1500
LABEL org.chess.build="npm run build"
LABEL org.chess.test="node lib/es6/src/Chess.js --test"
LABEL org.chess.analyze="node --check lib/es6/src/Chess.js && echo 'Syntax OK'"

CMD ["node", "lib/es6/src/Chess.js"]
