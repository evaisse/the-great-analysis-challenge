FROM ghcr.io/evaisse/tgac-typescript-toolchain:latest

COPY . .

RUN npm run build

LABEL org.chess.language="typescript"
LABEL org.chess.version="5.0"
LABEL org.chess.author="TypeScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.source_exts=".ts"
LABEL org.chess.build="npm run build"
LABEL org.chess.test="npm test"
LABEL org.chess.test_contract="node unit_contract_runner.js"
LABEL org.chess.analyze="npm run lint"
LABEL org.chess.bugit="if [ -f .bugit/chess.ts.bak ]; then echo 'bugit already active for typescript'; else mkdir -p .bugit && cp src/chess.ts .bugit/chess.ts.bak && printf '\n)\n' >> src/chess.ts; fi"
LABEL org.chess.fix="if [ -f .bugit/chess.ts.bak ]; then mv .bugit/chess.ts.bak src/chess.ts && rmdir .bugit 2>/dev/null || true; else echo 'no typescript bugit backup to restore'; fi"

CMD ["node", "dist/chess.js"]
