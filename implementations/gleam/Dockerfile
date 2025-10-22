FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Erlang from Ubuntu repositories
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    build-essential \
    erlang \
    erlang-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Gleam
RUN GLEAM_VERSION="1.2.1" \
    && case "$(uname -m)" in \
        x86_64) ARCH="x86_64-unknown-linux-musl" ;; \
        aarch64|arm64) ARCH="aarch64-unknown-linux-musl" ;; \
        *) echo "Unsupported architecture" && exit 1 ;; \
    esac \
    && wget "https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-${ARCH}.tar.gz" \
    && tar -xzf "gleam-v${GLEAM_VERSION}-${ARCH}.tar.gz" \
    && mv gleam /usr/local/bin/ \
    && rm "gleam-v${GLEAM_VERSION}-${ARCH}.tar.gz" \
    && chmod +x /usr/local/bin/gleam

WORKDIR /app

# Copy project files
COPY . .

# Download dependencies and build
RUN gleam deps download && gleam build

# Set the default command
CMD ["gleam", "run"]