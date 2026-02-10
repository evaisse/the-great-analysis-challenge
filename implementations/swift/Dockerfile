FROM swift:5.10.1-jammy

# Set the working directory
WORKDIR /app

# Copy the Swift package file
COPY Package.swift .

# Copy the source code
COPY src/ src/

# Build the project
RUN swift build -c release

# Set the entrypoint
CMD [".build/release/Chess"]
