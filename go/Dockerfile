# Use an official Go runtime as a parent image
FROM golang:1.23-alpine

# Set the working directory in the container
WORKDIR /app

# Copy the go.mod and go.sum files to download dependencies
COPY go.mod ./
RUN go mod download

# Copy the rest of the application source code
COPY . .

# Build the Go app
RUN go build -o /chess ./cmd/chess

# Command to run the executable
CMD ["/chess"]
