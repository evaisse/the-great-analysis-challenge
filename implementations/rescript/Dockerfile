FROM ghcr.io/evaisse/tgac-rescript-toolchain:latest

RUN if command -v apk >/dev/null 2>&1; then apk add --no-cache make; \
    elif command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y --no-install-recommends make && rm -rf /var/lib/apt/lists/*; \
    else echo "No supported package manager found to install make" >&2; exit 1; fi

COPY . .

RUN npm install && npm run build

LABEL org.chess.language="rescript"
LABEL org.chess.version="10.0"
LABEL org.chess.author="ReScript Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1500
LABEL org.chess.build="npm run build"
LABEL org.chess.test="node lib/es6/src/Chess.js --test"
LABEL org.chess.analyze="npx rescript build"

CMD ["node", "lib/es6/src/Chess.js"]
