FROM golang:1.22-slim

WORKDIR /app
COPY . .

# Copy and build the application, using Go's strong build caching
# The `sed` command is carried over from the original Dockerfile.
RUN cp src/*.go . && sed -i '/import "math"/d' ai.go && go build -ldflags="-s -w" -o chess *.go

CMD ["./chess"]
