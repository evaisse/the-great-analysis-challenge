#!/bin/bash
case "$1" in
  test)
    swift test
    ;;
  build)
    swift build -c release
    ;;
  analyze)
    swift build
    ;;
  clean)
    swift package clean
    ;;
  *)
    echo "Unknown command: $1"
    exit 1
    ;;
esac
