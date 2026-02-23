# Use official Gleam image with Erlang
FROM jfrog.int.bourso.net/web-v-docker/ghcr.io/gleam-lang/gleam:v1.3.1-erlang

WORKDIR /app

# Copy project files (deps are vendored via path dependencies)
COPY . .

# Build (no network needed, deps are vendored)
RUN gleam build

LABEL org.chess.language="gleam"
LABEL org.chess.version="1.3.1"
LABEL org.chess.author="Gleam Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.build="gleam build"
LABEL org.chess.test="gleam test"
LABEL org.chess.analyze="gleam format --check && gleam check"

CMD ["gleam", "run"]
