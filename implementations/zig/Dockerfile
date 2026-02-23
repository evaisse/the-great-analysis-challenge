FROM ghcr.io/evaisse/tgac-zig-toolchain:latest

COPY . .

RUN zig build -Doptimize=ReleaseFast

LABEL org.chess.language="zig"
LABEL org.chess.version="latest"
LABEL org.chess.author="Zig Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.build="zig build -Doptimize=ReleaseFast"
LABEL org.chess.run="./zig-out/bin/chess"
LABEL org.chess.test="./zig-out/bin/chess --test"
LABEL org.chess.analyze="zig fmt --check src/"

CMD ["./zig-out/bin/chess"]
