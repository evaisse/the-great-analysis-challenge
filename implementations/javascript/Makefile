.PHONY: all build test analyze clean docker-build docker-test help

all: build

build:
	npm install

test:
	npm test

analyze:
	npm run analyze

clean:
	rm -rf node_modules

help:
	@echo "Available targets: all, build, test, analyze, clean, docker-build, docker-test, help"

docker-build:
	docker build -t chess-javascript .

docker-test: docker-build
	docker run --network none --rm -i chess-javascript sh -c "echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | node chess.js"
