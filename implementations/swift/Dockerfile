# Use official Swift image
FROM swift:6.0-jammy

# Set the working directory
WORKDIR /app

# Copy the Swift package file
COPY Package.swift .

# Copy the source code
COPY src/ src/
COPY Tests/ Tests/

# Copy the make wrapper
COPY make.sh /usr/local/bin/make
RUN chmod +x /usr/local/bin/make

# Build the project
RUN swift build -c release

# Set the entrypoint

LABEL org.chess.language="swift"
LABEL org.chess.version="5.5"
LABEL org.chess.author="Jules"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.build="swift build -c release"
LABEL org.chess.test="swift test"
LABEL org.chess.analyze="swiftlint && swift build --configuration debug"

CMD [".build/release/Chess"]
