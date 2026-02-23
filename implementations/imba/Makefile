.PHONY: all build test analyze clean docker-build docker-test help

all: build

build:
	npm install
	npm run build

test:
	# No internal tests yet, but required for compliance
	@echo "No internal tests defined"

analyze:
	# Imba doesn't have a standalone static analyzer like tsc yet
	@echo "No static analysis tool defined"

clean:
	rm -rf node_modules dist

help:
	@echo "Available targets: all, build, test, analyze, clean, docker-build, docker-test, help"

docker-build:
	docker build -t chess-imba .

docker-test: docker-build
	docker run --network none --rm -i chess-imba sh -c "echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | node dist/chess.js"
