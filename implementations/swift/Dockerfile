FROM ghcr.io/evaisse/tgac-swift-toolchain:latest

COPY . .

RUN swift build -c release

LABEL org.chess.language="swift"
LABEL org.chess.version="5.5"
LABEL org.chess.author="Jules"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.source_exts=".swift"
LABEL org.chess.build="swift build -c release"
LABEL org.chess.test="swift test"
LABEL org.chess.analyze="swift build --configuration debug"
LABEL org.chess.bugit="if [ -f .bugit/main.swift.bak ]; then echo 'bugit already active for swift'; else mkdir -p .bugit && cp src/main.swift .bugit/main.swift.bak && printf '\n)\n' >> src/main.swift; fi"
LABEL org.chess.fix="if [ -f .bugit/main.swift.bak ]; then mv .bugit/main.swift.bak src/main.swift && rmdir .bugit 2>/dev/null || true; else echo 'no swift bugit backup to restore'; fi"

CMD [".build/release/Chess"]
