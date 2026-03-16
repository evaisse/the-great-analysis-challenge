.PHONY: all build test analyze clean docker-build docker-test help

all: build

build:
	imba build chess.imba --platform node --base . --outdir dist

test:
	# No internal tests yet, but required for compliance
	@echo "No internal tests defined"

analyze:
	imba build chess.imba --platform node --base . --outdir /tmp/tgac-imba-check

clean:
	rm -rf node_modules dist

help:
	@echo "Available targets: all, build, test, analyze, clean, docker-build, docker-test, help"

docker-build:
	docker build -t chess-imba .

docker-test: docker-build
	docker run --network none --rm -i chess-imba sh -c "echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | node dist/chess.js"

.PHONY: bugit fix

bugit:
	../../workflow error-analysis bugit --impl .

fix:
	../../workflow error-analysis fix --impl .
