FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN env http_proxy="" https_proxy="" apt-get update && env http_proxy="" https_proxy="" apt-get install -y \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Julia
RUN env http_proxy="" https_proxy="" JULIA_VERSION="1.9.4" \
    && wget "https://julialang-s3.julialang.org/bin/linux/x64/1.9/julia-${JULIA_VERSION}-linux-x86_64.tar.gz" \
    && tar -xzf "julia-${JULIA_VERSION}-linux-x86_64.tar.gz" \
    && mv "julia-${JULIA_VERSION}" /opt/julia \
    && ln -s /opt/julia/bin/julia /usr/local/bin/julia \
    && rm "julia-${JULIA_VERSION}-linux-x86_64.tar.gz"

WORKDIR /app

# Copy project files
COPY Project.toml .
COPY src/ src/
COPY chess.jl .

# Install dependencies (if any)
RUN julia --project=. -e "using Pkg; Pkg.instantiate()"

# Make the chess engine executable
CMD ["julia", "--project=.", "chess.jl"]