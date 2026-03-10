FROM ghcr.io/evaisse/tgac-imba-toolchain:latest

COPY . .

RUN imba build chess.imba --platform node --base . --outdir dist

LABEL org.chess.language="imba"
LABEL org.chess.version="2.0"
LABEL org.chess.author="Imba Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.source_exts=".imba"
LABEL org.chess.build="imba build chess.imba --platform node --base . --outdir dist"
LABEL org.chess.run="node dist/chess.js"
LABEL org.chess.test="true"
LABEL org.chess.analyze="true"

CMD ["node", "dist/chess.js"]
