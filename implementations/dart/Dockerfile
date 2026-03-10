FROM dart:stable

ENV PATH="/usr/lib/dart/bin:${PATH}"
WORKDIR /app

COPY . .

LABEL org.chess.language="dart"
LABEL org.chess.version="3.0"
LABEL org.chess.author="Dart Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=900
LABEL org.chess.benchmark.build="skip"
LABEL org.chess.build="printf 'quit\n' | dart --packages=package_config.json bin/main.dart"
LABEL org.chess.test="printf 'new\nmove e2e4\nmove e7e5\nexport\nquit\n' | dart --packages=package_config.json bin/main.dart"
LABEL org.chess.analyze="dart format --output=none bin lib"

CMD ["dart", "--packages=package_config.json", "bin/main.dart"]
