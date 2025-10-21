FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    binutils \
    git \
    gnupg2 \
    libc6-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libgcc-9-dev \
    libpython3-dev \
    libsqlite3-0 \
    libstdc++-9-dev \
    libxml2-dev \
    libz3-dev \
    pkg-config \
    tzdata \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Swift
RUN SWIFT_VERSION="5.9.2" \
    && SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2004/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu20.04.tar.gz" \
    && wget "${SWIFT_URL}" \
    && tar -xzf "swift-${SWIFT_VERSION}-RELEASE-ubuntu20.04.tar.gz" \
    && mv "swift-${SWIFT_VERSION}-RELEASE-ubuntu20.04" /opt/swift \
    && ln -s /opt/swift/usr/bin/swift* /usr/local/bin/ \
    && rm "swift-${SWIFT_VERSION}-RELEASE-ubuntu20.04.tar.gz"

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
