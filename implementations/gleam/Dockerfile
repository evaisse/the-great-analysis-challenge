FROM ghcr.io/gleam-lang/gleam:v1.2.1-erlang-alpine

WORKDIR /app

# Copy project files
COPY . .

# Initialize a new project and compile to Erlang
RUN gleam run