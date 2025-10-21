FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Go
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    golang-go \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN go build -o chess chess.go

CMD ["./chess"]