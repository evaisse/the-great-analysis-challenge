FROM ghcr.io/evaisse/tgac-haskell-toolchain:latest

COPY src/ src/

RUN ghc -O2 --make src/Main.hs -o chess_engine -i/app/src

LABEL org.chess.language="haskell"
LABEL org.chess.version="9.0"
LABEL org.chess.author="Haskell Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.run="./chess_engine"
LABEL org.chess.build="ghc -O2 --make src/Main.hs -o chess_engine -isrc"
LABEL org.chess.test="./chess_engine --test"
LABEL org.chess.analyze="hlint src/"

CMD ["./chess_engine"]
