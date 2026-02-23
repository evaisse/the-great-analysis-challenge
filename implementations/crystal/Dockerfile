FROM ghcr.io/evaisse/tgac-crystal-toolchain:latest

COPY . .

RUN crystal build src/chess_engine.cr --release -o chess_engine

LABEL org.chess.language="crystal"
LABEL org.chess.version="1.14.0"
LABEL org.chess.author="Crystal Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.build="crystal build src/chess_engine.cr --release -o chess_engine"
LABEL org.chess.run="./chess_engine"
LABEL org.chess.test="crystal spec"
LABEL org.chess.analyze="crystal tool format --check"

CMD ["./chess_engine"]
