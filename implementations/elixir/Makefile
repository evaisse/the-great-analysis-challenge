.PHONY: all build test analyze clean docker-build docker-test help

all: build

build:
	mix compile --warnings-as-errors

test:
	mix run -e "ChessEngine.SelfTest.main()"

analyze:
	mix format --check-formatted
	mix compile --warnings-as-errors

clean:
	rm -rf _build deps

docker-build:
	docker build -t chess-elixir .

docker-test: docker-build
	docker run --network none --rm -i chess-elixir mix run --no-compile -e "ChessEngine.SelfTest.main()"

help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run self-tests"
	@echo "  make analyze - Run formatting and compile checks"
	@echo "  make clean   - Remove build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Run tests in Docker"

.PHONY: bugit fix

bugit:
	../../workflow error-analysis bugit --impl .

fix:
	../../workflow error-analysis fix --impl .
