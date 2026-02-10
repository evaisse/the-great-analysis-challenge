# Use official Julia image
FROM julia:1.11-bookworm

WORKDIR /app

# Copy project files
COPY . .

# Install dependencies and make for the test suite
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/* && \
    julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"

# Default command
CMD ["julia", "--project=.", "chess.jl"]
