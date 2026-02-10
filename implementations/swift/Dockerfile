# Use official Swift image
FROM swift:6.0-jammy

# Set the working directory
WORKDIR /app

# Install make for the test suite
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

# Copy the Swift package file
COPY Package.swift .

# Copy the source code
COPY src/ src/

# Build the project
RUN swift build -c release

# Set the entrypoint
CMD [".build/release/Chess"]
