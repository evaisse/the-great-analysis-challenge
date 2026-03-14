FROM ghcr.io/evaisse/tgac-haskell-toolchain:latest

COPY src/ src/
COPY Makefile .

RUN ghc -O2 --make src/Main.hs -o chess_engine -i/app/src

LABEL org.chess.language="haskell"
LABEL org.chess.version="9.0"
LABEL org.chess.author="Haskell Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.source_exts=".hs"
LABEL org.chess.run="./chess_engine"
LABEL org.chess.build="ghc -O2 --make src/Main.hs -o chess_engine -isrc"
LABEL org.chess.test="./chess_engine --test"
LABEL org.chess.analyze="ghc -fno-code --make src/Main.hs -isrc"
LABEL org.chess.bugit="if [ -f .bugit/Main.hs.bak ]; then echo 'bugit already active for haskell'; else mkdir -p .bugit && cp src/Main.hs .bugit/Main.hs.bak && printf '\n)\n' >> src/Main.hs; fi"
LABEL org.chess.fix="if [ -f .bugit/Main.hs.bak ]; then mv .bugit/Main.hs.bak src/Main.hs && rmdir .bugit 2>/dev/null || true; else echo 'no haskell bugit backup to restore'; fi"

CMD ["./chess_engine"]
