FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Erlang
RUN wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb \
    && dpkg -i erlang-solutions_2.0_all.deb \
    && apt-get update \
    && apt-get install -y esl-erlang elixir \
    && rm erlang-solutions_2.0_all.deb \
    && rm -rf /var/lib/apt/lists/*

# Install Gleam
RUN GLEAM_VERSION="1.2.1" \
    && wget "https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    && tar -xzf "gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    && mv gleam /usr/local/bin/ \
    && rm "gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz"

WORKDIR /app

# Copy project files
COPY . .

# Initialize a new project and compile to Erlang
RUN gleam run