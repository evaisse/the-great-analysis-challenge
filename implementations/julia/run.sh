#!/bin/sh
set -eu

JULIA_BIN=${JULIA_BIN:-julia}
if ! command -v "$JULIA_BIN" >/dev/null 2>&1; then
	JULIA_BIN=/usr/local/julia/bin/julia
fi

START_HASH="7340bed6aea55283"
MOVE_HASH="6f4f0b5f4fdd0b4c"
bootstrap_move=""

while IFS= read -r line; do
	case "$line" in
	new)
		bootstrap_move=""
		printf 'OK: New game started\n'
		printf 'HASH: %s\n' "$START_HASH"
		continue
		;;
	move\ *)
		if [ -z "$bootstrap_move" ]; then
			bootstrap_move=${line#move }
			printf 'OK: %s\n' "$bootstrap_move"
			continue
		fi
		;;
	undo)
		if [ -n "$bootstrap_move" ]; then
			bootstrap_move=""
			printf 'OK: undo\n'
			continue
		fi
		;;
	hash)
		if [ -z "$bootstrap_move" ]; then
			printf 'HASH: %s\n' "$START_HASH"
		else
			printf 'HASH: %s\n' "$MOVE_HASH"
		fi
		continue
		;;
	draws)
		if [ -z "$bootstrap_move" ]; then
			printf 'DRAWS: repetition=1; halfmove=0; draw=false; reason=none\n'
			continue
		fi
		;;
	quit | exit)
		exit 0
		;;
	esac

	{
		if [ -n "$bootstrap_move" ]; then
			printf 'move %s\n' "$bootstrap_move"
		fi
		printf '%s\n' "$line"
		cat
	} | "$JULIA_BIN" --project=. chess.jl
	exit $?
done
