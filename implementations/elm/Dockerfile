FROM ghcr.io/evaisse/tgac-elm-toolchain:latest

COPY . .

RUN npm install && mkdir -p dist && elm make src/ChessEngine.elm --output=src/chess.js

LABEL org.chess.language="elm"
LABEL org.chess.version="0.19.1"
LABEL org.chess.author="Elm Implementation with Node.js Bridge"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1200
LABEL org.chess.run="node chess-bridge.js"
LABEL org.chess.build="npm install"
LABEL org.chess.test="node chess-bridge.js --test"
LABEL org.chess.analyze="node chess-bridge.js --check"

CMD ["node", "src/cli.js"]
