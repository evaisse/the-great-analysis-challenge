# Use official Julia image
FROM jfrog.int.bourso.net/web-v-docker/julia:1.11-bookworm

WORKDIR /app

# Copy source files
COPY . .

LABEL org.chess.language="julia"
LABEL org.chess.version="1.11"
LABEL org.chess.author="Julia Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.run="julia --project=. chess.jl"
LABEL org.chess.build="julia --project=. -e 'using Pkg; Pkg.instantiate()'"
LABEL org.chess.test="julia --project=. test/runtests.jl"
LABEL org.chess.analyze="julia --project=. -e 'using Pkg; Pkg.precompile()'"

# Default command
CMD ["julia", "chess.jl"]
