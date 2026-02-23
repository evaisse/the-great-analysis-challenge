FROM ghcr.io/evaisse/tgac-dart-toolchain:latest

COPY . .

RUN dart pub get && dart compile exe bin/main.dart -o bin/chess_engine

LABEL org.chess.language="dart"
LABEL org.chess.version="3.0"
LABEL org.chess.author="Dart Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=900
LABEL org.chess.test="dart test"
LABEL org.chess.analyze="dart analyze"

CMD ["./bin/chess_engine"]
