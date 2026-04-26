#!/bin/sh
set -eu

# Prime stdin with a blank line so `gleam run` fully starts before the
# harness sends its first real command.
{ printf '\n'; cat; } | gleam run
