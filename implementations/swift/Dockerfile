FROM ghcr.io/evaisse/tgac-swift-toolchain:latest

RUN apt-get update && apt-get install -y --no-install-recommends make && rm -rf /var/lib/apt/lists/*

COPY . .

RUN swift build -c release

LABEL org.chess.language="swift"
LABEL org.chess.version="5.5"
LABEL org.chess.author="Jules"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.build="swift build -c release"
LABEL org.chess.test="swift test"
LABEL org.chess.analyze="swift build --configuration debug"

CMD [".build/release/Chess"]
