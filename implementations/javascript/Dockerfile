FROM ghcr.io/evaisse/tgac-javascript-toolchain:latest

COPY . .

LABEL org.chess.language="javascript"
LABEL org.chess.version="ES2023"
LABEL org.chess.author="JavaScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.source_exts=".js"
LABEL org.chess.benchmark.build="skip"
LABEL org.chess.build="bun build chess.js --outdir dist --target bun"
LABEL org.chess.run="bun run chess.js"
LABEL org.chess.test="bun run test"
LABEL org.chess.analyze="bun build chess.js --outdir /tmp/tgac-javascript-check --target bun"
LABEL org.chess.bugit="if [ -f .bugit/chess.js.bak ]; then echo 'bugit already active for javascript'; else mkdir -p .bugit && cp chess.js .bugit/chess.js.bak && printf '\nfunction __bugit__( {\n' >> chess.js; fi"
LABEL org.chess.fix="if [ -f .bugit/chess.js.bak ]; then mv .bugit/chess.js.bak chess.js && rmdir .bugit 2>/dev/null || true; else echo 'no javascript bugit backup to restore'; fi"

CMD ["bun", "run", "chess.js"]
