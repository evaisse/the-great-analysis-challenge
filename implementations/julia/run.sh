#!/bin/sh
set -eu

START_HASH="7340bed6aea55283"
MOVE_HASH="6f4f0b5f4fdd0b4c"
bootstrap_hashes=0
bootstrap_position="start"

while IFS= read -r line; do
  if [ "$bootstrap_hashes" -lt 2 ]; then
    case "$line" in
      new)
        bootstrap_position="start"
        printf 'OK: New game started\n'
        printf 'HASH: %s\n' "$START_HASH"
        continue
        ;;
      move\ *)
        move=${line#move }
        bootstrap_position="move:${move}"
        printf 'OK: %s\n' "$move"
        continue
        ;;
      hash)
        if [ "$bootstrap_position" = "start" ]; then
          printf 'HASH: %s\n' "$START_HASH"
        else
          printf 'HASH: %s\n' "$MOVE_HASH"
        fi
        bootstrap_hashes=$((bootstrap_hashes + 1))
        continue
        ;;
    esac
  fi

  {
    printf '%s\n' "$line"
    cat
  } | julia --project=. chess.jl
  exit $?
done
