.PHONY: all build test analyze clean docker-build docker-test help

all: build

build:
	bun run build

test:
	bun run test

analyze:
	bun run analyze

clean:
	rm -rf dist node_modules bun.lock bun.lockb

help:
	@echo "Available targets: all, build, test, analyze, clean, docker-build, docker-test, help"

docker-build:
	docker build -t chess-javascript .

docker-test: docker-build
	docker run --network none --rm -i chess-javascript sh -c "printf 'new\nmove e2e4\nmove e7e5\nexport\nquit\n' | bun run chess.js"

.PHONY: bugit fix

bugit:
	python3 ../../scripts/error_analysis_benchmark.py bugit --impl .

fix:
	python3 ../../scripts/error_analysis_benchmark.py fix --impl .
