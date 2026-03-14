FROM ghcr.io/evaisse/tgac-rescript-toolchain:latest

COPY . .

RUN npm install && npm run build

LABEL org.chess.language="rescript"
LABEL org.chess.version="10.0"
LABEL org.chess.author="ReScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1500
LABEL org.chess.source_exts=".res,.resi"
LABEL org.chess.build="npm run build"
LABEL org.chess.test="node lib/es6/src/Chess.js --test"
LABEL org.chess.analyze="npx rescript build"
LABEL org.chess.bugit="if [ -f .bugit/Chess.res.bak ]; then echo 'bugit already active for rescript'; else mkdir -p .bugit && cp src/Chess.res .bugit/Chess.res.bak && printf '\n)\n' >> src/Chess.res; fi"
LABEL org.chess.fix="if [ -f .bugit/Chess.res.bak ]; then mv .bugit/Chess.res.bak src/Chess.res && rmdir .bugit 2>/dev/null || true; else echo 'no rescript bugit backup to restore'; fi"

CMD ["node", "lib/es6/src/Chess.js"]
