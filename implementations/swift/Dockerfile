FROM swift:5.9

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies


# Set the working directory
WORKDIR /app

# Copy the Swift package file
COPY Package.swift .

# Copy the source code
COPY Sources/ Sources/
COPY Tests/ Tests/

# Build the project
RUN swift build -c release

# Set the entrypoint
CMD [".build/release/Chess"]
