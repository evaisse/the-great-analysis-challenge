# Use official Go image
FROM golang:1.24-slim

# Install make
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Copy and build the application
RUN cp src/*.go . && sed -i '/import "math"/d' ai.go && go build -ldflags="-s -w" -o chess *.go

# Default command
CMD ["./chess"]
