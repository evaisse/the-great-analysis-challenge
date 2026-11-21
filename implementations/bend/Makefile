.PHONY: all build test analyze clean docker-build docker-test help

BEND ?= bend
SRC := src/chess.bend
BIN := chess

all: build

# compile the checked program to a native binary through clang
build:
	$(BEND) $(SRC) -o $(BIN)

test: build
	sh tests/run.sh ./$(BIN)

# type, quantity and termination checking of every module
analyze:
	@for f in src/*.bend; do echo "checking $$f"; $(BEND) $$f --check-only || exit 1; done

clean:
	rm -f $(BIN) chess.c

docker-build:
	docker build -t chess-bend .

docker-test: docker-build
	docker run --network none --rm -i chess-bend make test

help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run the scripted tests"
	@echo "  make analyze - Check every module (types, quantities, termination)"
	@echo "  make clean   - Remove build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Run tests in Docker"

.PHONY: bugit fix

bugit:
	../../workflow error-analysis bugit --impl .

fix:
	../../workflow error-analysis fix --impl .
