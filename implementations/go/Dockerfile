# Use official Go image
FROM golang:1.23

WORKDIR /app
COPY . .

# Copy and build the application
RUN cp src/*.go . && go build -ldflags="-s -w" -o chess *.go

# Default command
CMD ["./chess"]
