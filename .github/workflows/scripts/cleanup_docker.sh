#!/bin/bash
# Cleanup Docker images and temporary files
# Usage: cleanup_docker.sh <engine_name>

set -e

ENGINE="$1"
if [[ -z "$ENGINE" ]]; then
    echo "Error: Engine name required"
    exit 1
fi

echo "🧹 Cleaning up $ENGINE..."
docker rmi chess-$ENGINE-test || true
rm -f *.txt