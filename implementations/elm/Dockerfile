FROM ghcr.io/evaisse/tgac-elm-toolchain:latest

ENV ELM_HOME=/root/.elm

COPY . .

# Vendor the exact package cache needed by elm.json so fresh Docker builds stay offline.
RUN mkdir -p "$ELM_HOME" \
    && cp -R vendor/elm-home/. "$ELM_HOME"/ \
    && mkdir -p dist \
    && elm make src/ChessEngine.elm --optimize --output=src/chess.js

LABEL org.chess.language="elm"
LABEL org.chess.version="0.19.1"
LABEL org.chess.author="Elm Implementation with Node.js Bridge"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion,pgn,uci,chess960"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1200
LABEL org.chess.source_exts=".elm"
LABEL org.chess.run="node chess-bridge.js"
LABEL org.chess.build="elm make src/ChessEngine.elm --optimize --output=src/chess.js"
LABEL org.chess.test="node chess-bridge.js --test"
LABEL org.chess.analyze="elm make src/ChessEngine.elm --output=/tmp/tgac-elm-check.js"
LABEL org.chess.bugit="if [ -f .bugit/ChessEngine.elm.bak ]; then echo 'bugit already active for elm'; else mkdir -p .bugit && cp src/ChessEngine.elm .bugit/ChessEngine.elm.bak && printf '\n)\n' >> src/ChessEngine.elm; fi"
LABEL org.chess.fix="if [ -f .bugit/ChessEngine.elm.bak ]; then mv .bugit/ChessEngine.elm.bak src/ChessEngine.elm && rmdir .bugit 2>/dev/null || true; else echo 'no elm bugit backup to restore'; fi"

CMD ["node", "src/cli.js"]
