FROM julia:1.9

WORKDIR /app

# Copy project files
COPY Project.toml .
COPY src/ src/
COPY chess.jl .

# Install dependencies (if any)
RUN julia --project=. -e "using Pkg; Pkg.instantiate()"

# Make the chess engine executable
CMD ["julia", "--project=.", "chess.jl"]