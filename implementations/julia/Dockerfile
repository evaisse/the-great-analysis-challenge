# Use official Julia image
FROM julia:1.11-bookworm

WORKDIR /app

# Install dependencies and make for the test suite
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY . .

# Instantiate packages
RUN julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"

# Default command

LABEL org.chess.language="julia"
LABEL org.chess.version="1.9"
LABEL org.chess.author="Julia Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.run="julia chess.jl"
LABEL org.chess.build="true"
LABEL org.chess.test="julia -e 'using Pkg; Pkg.test()'"
LABEL org.chess.analyze="julia --check-bounds=yes chess.jl"

CMD ["julia", "--project=.", "chess.jl"]
