FROM ghcr.io/evaisse/tgac-javascript-toolchain:latest

COPY . .

# TypeScript tooling is preinstalled in the toolchain image; verify offline.
RUN npm ls --depth=0

LABEL org.chess.language="javascript"
LABEL org.chess.version="1.0.0"
LABEL org.chess.author="JavaScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.source_exts=".js"
LABEL org.chess.benchmark.build="skip"
LABEL org.chess.build="node --check chess.js"
LABEL org.chess.test="npm test"
LABEL org.chess.analyze="npm run lint"
LABEL org.chess.bugit="if [ -f .bugit/chess.js.bak ]; then echo 'bugit already active for javascript'; else mkdir -p .bugit && cp chess.js .bugit/chess.js.bak && printf '\nfunction __bugit__( {\n' >> chess.js; fi"
LABEL org.chess.fix="if [ -f .bugit/chess.js.bak ]; then mv .bugit/chess.js.bak chess.js && rmdir .bugit 2>/dev/null || true; else echo 'no javascript bugit backup to restore'; fi"

CMD ["node", "chess.js"]
