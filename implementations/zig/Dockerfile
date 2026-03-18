FROM ghcr.io/evaisse/tgac-zig-toolchain:latest

COPY . .

RUN zig build -Doptimize=ReleaseFast

LABEL org.chess.language="zig"
LABEL org.chess.version="latest"
LABEL org.chess.author="Zig Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion,pgn,uci,chess960"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.source_exts=".zig"
LABEL org.chess.build="zig build -Doptimize=ReleaseFast"
LABEL org.chess.run="./zig-out/bin/chess"
LABEL org.chess.test="./zig-out/bin/chess --test"
LABEL org.chess.analyze="zig fmt --check src/"
LABEL org.chess.bugit="if [ -f .bugit/main.zig.bak ]; then echo 'bugit already active for zig'; else mkdir -p .bugit && cp src/main.zig .bugit/main.zig.bak && printf '\n)\n' >> src/main.zig; fi"
LABEL org.chess.fix="if [ -f .bugit/main.zig.bak ]; then mv .bugit/main.zig.bak src/main.zig && rmdir .bugit 2>/dev/null || true; else echo 'no zig bugit backup to restore'; fi"

CMD ["./zig-out/bin/chess"]
