# Use official Go image
FROM golang:1.23

# Install make
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Build the application
RUN go build -ldflags="-s -w" -o chess .

# Default command
CMD ["./chess"]
