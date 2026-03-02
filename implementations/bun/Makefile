.PHONY: all build test analyze clean docker-build docker-test help

all: build

build:
	bun --version

test:
	bun test

analyze:
	bun --version

clean:
	rm -rf node_modules bun.lockb

help:
	@echo "Available targets: all, build, test, analyze, clean, docker-build, docker-test, help"

docker-build:
	docker build -t chess-bun .

docker-test: docker-build
	docker run --network none --rm -i chess-bun sh -c "printf 'new\nmove e2e4\nmove e7e5\nexport\nquit\n' | bun run chess.js"
