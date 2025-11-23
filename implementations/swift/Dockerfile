FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies for Swift
RUN export http_proxy="" && export https_proxy="" && apt-get update && apt-get install -y \
    binutils \
    git \
    gnupg2 \
    libc6-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libgcc-13-dev \
    libpython3.12 \
    libsqlite3-0 \
    libstdc++-13-dev \
    libxml2-dev \
    libz3-dev \
    pkg-config \
    tzdata \
    unzip \
    zlib1g-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download and install Swift
ENV SWIFT_VERSION=5.9.2
ENV SWIFT_PLATFORM=ubuntu22.04
ENV SWIFT_BRANCH=swift-${SWIFT_VERSION}-release
ENV SWIFT_URL=https://download.swift.org/${SWIFT_BRANCH}/${SWIFT_PLATFORM}/${SWIFT_BRANCH}/${SWIFT_BRANCH}-${SWIFT_PLATFORM}.tar.gz
RUN export http_proxy="" && export https_proxy="" && wget -q -O swift.tar.gz "${SWIFT_URL}" \
    && tar -xzf swift.tar.gz --strip-components=1 -C /usr/local \
    && rm swift.tar.gz \
    && swift --version

# Set PATH
ENV PATH="/usr/local/bin:${PATH}"

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
