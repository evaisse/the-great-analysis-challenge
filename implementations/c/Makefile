.PHONY: all build test analyze clean docker-build docker-test help

CC := gcc
CFLAGS := -std=c11 -O2 -Wall -Wextra -Werror -pedantic
SRC := src/chess.c
BIN := chess

all: build

build:
	$(CC) $(CFLAGS) -o $(BIN) $(SRC)

test: build
	./$(BIN) --self-test

analyze:
	$(CC) $(CFLAGS) -fsyntax-only $(SRC)

clean:
	rm -f $(BIN)

docker-build:
	docker build -t chess-c .

docker-test: docker-build
	docker run --network none --rm -i chess-c ./chess --self-test

help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run self-tests"
	@echo "  make analyze - Run static analysis via compiler warnings"
	@echo "  make clean   - Remove build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Run tests in Docker"
