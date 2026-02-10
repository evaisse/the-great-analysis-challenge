# Use official Ruby image
FROM ruby:3.4-slim-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    make \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile first for better caching
COPY Gemfile* ./

# Install bundler and gems
RUN if [ -f Gemfile ]; then \
    gem install bundler && bundle install; \
    fi

# Copy source code
COPY . .

# Create a non-root user
RUN groupadd -g 1001 ruby && \
    useradd -m -u 1001 -g ruby -s /bin/false chess

# Change ownership of the app directory
RUN chown -R chess:ruby /app

# Switch to non-root user
USER chess

# Make chess.rb executable
RUN chmod +x chess.rb

# Default command to run the chess engine
CMD ["ruby", "chess.rb"]
