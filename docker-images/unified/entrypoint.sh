#!/bin/sh
# Entrypoint for the unified toolchain image (issue #173).
#
# Dispatches to the same org.chess.* / chess.meta metadata commands the
# per-language Docker workflow uses (see tooling/shared.ts getMetadata),
# but runs them directly against the toolchains installed in this image
# instead of spawning a nested `docker run`. The repository must be bind
# mounted at $TGAC_WORKSPACE (default /workspace).
set -eu

REPO_ROOT="${TGAC_WORKSPACE:-/workspace}"
cd "$REPO_ROOT"

usage() {
	cat <<'USAGE'
Unified toolchain image for The Great Analysis Challenge.

Usage:
  docker run --rm -v "$PWD":/workspace tgac-unified <command> [args]

Commands:
  help                                 Show this message
  languages                            List included / excluded toolchains
  build <language>                     Run org.chess.build for <language> locally
  analyze <language>                   Run org.chess.analyze for <language> locally
  test <language>                      Run org.chess.test for <language> locally
  test-chess-engine <language> [args]  Run the shared protocol test suite locally
                                        (forwards extra args to ./workflow, e.g. --track v2-full)
  run <language>                       Launch the implementation interactively (stdin/stdout)
  shell                                Open an interactive shell with every toolchain on PATH

<language> must match a directory name under implementations/.
Not every implementation's toolchain is included in this image; run
'languages' to see the covered/excluded list, or read
docs/reference/unified-toolchain-image.md for the full trade-off writeup.
USAGE
}

require_workspace() {
	if [ ! -x "$REPO_ROOT/workflow" ] || [ ! -d "$REPO_ROOT/implementations" ]; then
		echo "error: $REPO_ROOT does not look like a the-great-analysis-challenge checkout." >&2
		echo "Mount the repository root, e.g.: docker run --rm -v \"\$PWD\":/workspace tgac-unified $*" >&2
		exit 1
	fi
}

require_language() {
	lang="$1"
	if [ -z "$lang" ]; then
		echo "error: a <language> argument is required." >&2
		exit 1
	fi
	if [ ! -d "$REPO_ROOT/implementations/$lang" ]; then
		echo "error: implementations/$lang not found." >&2
		exit 1
	fi
}

# A few implementations keep their build tooling as project-local
# dependencies (rescript/javascript/typescript's package.json, ruby's
# Gemfile) rather than a global compiler, mirroring how their dedicated
# toolchain images preinstall those dependencies at image-build time. The
# unified image cannot bake those in (they come from the working tree, not
# a fixed snapshot), so install them here on first use instead.
ensure_project_deps() {
	impl_dir="implementations/$1"
	if [ -f "$impl_dir/package.json" ] && [ ! -d "$impl_dir/node_modules" ]; then
		echo "Installing npm dependencies for $1 (first run only, needs network)..." >&2
		# npm, not bun: matches each implementation's own committed
		# package-lock.json / toolchain Dockerfile convention (bun still
		# reads the resulting node_modules fine for bun run/build/test) and
		# avoids leaving a stray bun.lock next to an npm-managed project.
		(cd "$impl_dir" && npm install)
	fi
	if [ -f "$impl_dir/Gemfile" ] && ! (cd "$impl_dir" && bundle check >/dev/null 2>&1); then
		echo "Installing gem dependencies for $1 (first run only, needs network)..." >&2
		(cd "$impl_dir" && bundle install)
	fi
}

# ./workflow (tooling/cli.ts) imports the full shared-tooling module graph
# eagerly, so it needs the repo root's own node_modules (bun install)
# resolvable before any subcommand can run, regardless of which command is
# invoked. This is an existing prerequisite for make build/analyze/test on
# the host too; the unified image just satisfies it automatically.
ensure_workflow_deps() {
	if [ ! -d "$REPO_ROOT/node_modules" ]; then
		echo "Installing repository tooling dependencies (first run only, needs network)..." >&2
		bun install --frozen-lockfile
	fi
}

command="${1:-help}"

case "$command" in
help | -h | --help)
	usage
	;;
languages)
	echo "Included:  ${TGAC_UNIFIED_LANGUAGES:-unknown}"
	echo "Excluded:  ${TGAC_UNIFIED_EXCLUDED_LANGUAGES:-unknown}  (use: make image DIR=<language>)"
	;;
build | analyze | test)
	phase="$command"
	lang="${2:-}"
	require_workspace "$@"
	require_language "$lang"
	ensure_workflow_deps
	ensure_project_deps "$lang"
	exec ./workflow run-metadata-phase --impl "implementations/$lang" --phase "$phase" --local
	;;
test-chess-engine)
	lang="${2:-}"
	require_workspace "$@"
	require_language "$lang"
	shift 2 2>/dev/null || shift $#
	ensure_workflow_deps
	ensure_project_deps "$lang"
	exec ./workflow test-chess-engine "$lang" --local "$@"
	;;
run)
	lang="${2:-}"
	require_workspace "$@"
	require_language "$lang"
	ensure_project_deps "$lang"
	run_cmd=$(bun run docker-images/unified/print-metadata.ts --impl "implementations/$lang" --field run) || {
		echo "error: no org.chess.run command found for '$lang'." >&2
		exit 1
	}
	cd "implementations/$lang"
	exec sh -c "$run_cmd"
	;;
shell)
	exec sh
	;;
*)
	echo "error: unknown command '$command'" >&2
	echo >&2
	usage >&2
	exit 1
	;;
esac
