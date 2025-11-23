FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install Rust
RUN export http_proxy="" && export https_proxy="" && apt-get update && apt-get install -y curl build-essential
RUN export http_proxy="" && export https_proxy="" && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /app

COPY . .

RUN cargo build --release

CMD ["./target/release/chess"]