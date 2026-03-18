FROM ghcr.io/evaisse/tgac-nim-toolchain:latest

COPY . .

RUN nim c -d:release chess.nim

LABEL org.chess.language="nim"
LABEL org.chess.version="2.0"
LABEL org.chess.author="Nim Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion,pgn,uci,chess960"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.source_exts=".nim"
LABEL org.chess.build="nim c -d:release chess.nim"
LABEL org.chess.test="./chess --test"
LABEL org.chess.analyze="nim check chess.nim"
LABEL org.chess.bugit="if [ -f .bugit/chess.nim.bak ]; then echo 'bugit already active for nim'; else mkdir -p .bugit && cp chess.nim .bugit/chess.nim.bak && printf '\n)\n' >> chess.nim; fi"
LABEL org.chess.fix="if [ -f .bugit/chess.nim.bak ]; then mv .bugit/chess.nim.bak chess.nim && rmdir .bugit 2>/dev/null || true; else echo 'no nim bugit backup to restore'; fi"

CMD ["./chess"]
