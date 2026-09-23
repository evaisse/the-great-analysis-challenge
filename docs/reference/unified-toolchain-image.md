# Unified Toolchain Image

Tracks issue [#173](https://github.com/evaisse/the-great-analysis-challenge/issues/173).

`Dockerfile.unified` builds one image containing several language toolchains, so a fresh
checkout can build/analyze/test/run multiple implementations without first building or
pulling one dedicated `ghcr.io/evaisse/tgac-<language>-toolchain` image per language. It is
an **additional, opt-in convenience path**; it does not replace the per-language toolchain
images or the existing `make image|build|analyze|test|test-chess-engine DIR=<language>`
commands, which are unchanged and remain the source of truth for CI and for any language not
covered by the unified image.

**Status: not build-tested locally.** This Dockerfile was authored in an environment without
a Docker CLI. `.github/workflows/unified-image.yml` builds it and smoke-tests one
implementation per included toolchain family on every change; do not treat the image as
working until that workflow is green, and re-check it before relying on the image for
anything beyond local convenience.

## Quick start

```bash
docker build -f Dockerfile.unified -t tgac-unified .

# Interactive shell with every included toolchain on PATH
docker run --rm -it -v "$PWD":/workspace tgac-unified shell

# Build / analyze / test a single implementation, no per-language image needed
docker run --rm -v "$PWD":/workspace tgac-unified build python
docker run --rm -v "$PWD":/workspace tgac-unified analyze rust
docker run --rm -v "$PWD":/workspace tgac-unified test go

# Shared cross-language protocol suite
docker run --rm -v "$PWD":/workspace tgac-unified test-chess-engine python --track v1

# Launch an implementation interactively (stdin/stdout protocol)
echo -e "new\nai 3\nexport\nquit" | docker run --rm -i -v "$PWD":/workspace tgac-unified run python
```

The container always operates on the repository bind-mounted at `/workspace`; there is no
image variant that bakes in a copy of the source, so it always reflects your working tree.

### From the root Makefile

Inside a shell started from `tgac-unified shell` (repo mounted, `TGAC_UNIFIED_IMAGE=1` set),
the existing commands work unchanged and skip the per-language Docker step:

```bash
make build DIR=python
make analyze DIR=rust
make test DIR=go
make test-chess-engine DIR=python TRACK=v1
```

`make image DIR=<language>` becomes a no-op message in this mode (the toolchain is already
in the image). Outside the unified container, `make build|analyze|test|test-chess-engine`
behave exactly as before (docker-per-language).

## How commands are preserved

The unified image does not reimplement `chess.meta` / `org.chess.*` parsing. Its entrypoint
and the Makefile's unified-mode branch both call the same shared tooling
(`tooling/shared.ts` `getMetadata`/`executePhase`, `tooling/chess.ts` `runTestHarness`) that
the per-language Docker path already uses, via a new `--local` flag
(`./workflow run-metadata-phase ... --local`, `./workflow test-chess-engine ... --local`).
`--local` skips the nested `docker run` and executes the implementation's
`org.chess.build|analyze|test|run` command directly, since the toolchain is already present
in the container (or, when run outside a container, on the host). This is the same mechanism
`build-local.sh` already used for ad hoc non-Docker testing, generalized and made a first-class,
tested code path (`tooling/shared.ts`, `tooling/chess.ts`, `tooling/cli.ts`).

## Toolchain coverage

Included (installed via `apt-get`, `npm`, `pip`, or `cargo` only, per the repository's "no
external downloads in Dockerfiles" rule in `AGENTS.md`):

| Language | Install method | Note |
|---|---|---|
| c | apt (`gcc`) | |
| elixir | apt (`elixir`, `erlang`) | |
| elm | `npm install -g elm@0.19.1-5` | Same version pin as `implementations/elm/docker-images/toolchain/Dockerfile` |
| gleam | `cargo install gleam` | No Debian package; built from source, needs the `erlang` package above |
| go | apt (`golang-go`) | Debian bookworm ships Go 1.19; the pinned per-language image uses 1.23 |
| haskell | apt (`ghc`, `cabal-install`) | |
| imba | `npm install -g imba` | |
| javascript, typescript | `npm install -g bun` | Installed via bun's documented npm package, not the curl installer |
| lua | apt (`lua5.4`) | |
| php | apt (`php-cli`) | |
| python | apt (`python3`, `python3-pip`) | |
| rescript | apt `nodejs`/`npm`, project deps via `bun install` | See "First-run dependency install" below |
| ruby | apt (`ruby-full`) + `gem install bundler` | |
| rust | apt (`rustc`, `cargo`) | Debian bookworm ships rustc ~1.63; the pinned per-language image uses 1.84 |
| zig | `pip install ziglang` | No Debian package; the PyPI wheel ships the compiler binary |

Excluded (no install path through a system/language package manager alone):

| Language | Why excluded |
|---|---|
| crystal | Official distribution is a vendor apt repository added via a downloaded GPG key, or a tarball; no plain Debian package |
| dart | Same as crystal: Google's apt repo requires a downloaded signing key |
| julia | Debian's apt package trails the pinned 1.11 toolchain too far to trust for this repository's correctness-sensitive benchmark suite |
| kotlin | No Debian package for `kotlinc`; upstream distribution is SDKMAN or a downloaded release archive |
| nim | No reliably available/current Debian package across supported releases |
| swift | Swift.org ships Linux tarballs only, no apt repository |

Excluded languages are unaffected: `make image|build|analyze|test|test-chess-engine
DIR=<language>` continues to use their dedicated `tgac-<language>-toolchain` image exactly as
before. `docker run ... tgac-unified languages` prints this include/exclude list from inside
the image.

### First-run dependency install

A few implementations keep their build tooling as project-local `npm`/`bun` dependencies
(`rescript`, and `javascript`/`typescript`'s own `package.json`) rather than a global compiler,
mirroring how their dedicated toolchain images preinstall those dependencies at image-build
time. The unified image cannot bake those in (they are read from your working tree, not a
fixed snapshot), so its entrypoint runs `bun install` in the implementation directory the
first time you `build`/`analyze`/`test`/`run` it, and once at the repository root for the
shared `./workflow` tooling itself. This needs network access; run it once while online, then
work offline as usual.

## Design comparison: monolithic vs. shared-base + per-language

Issue #173 asked for both options to be built and compared honestly. Docker was not available
in the environment used to write this, so the numbers below are structural (image contents,
layer/RUN counts, apt package list) rather than measured `docker build`/`docker images`
output; CI is expected to attach real build-time and size numbers once
`.github/workflows/unified-image.yml` runs. Treat the qualitative trade-offs as the
deliverable and the placeholders as pending measurement, not as claimed results.

| Dimension | Monolithic (`Dockerfile.unified`) | Shared-base + per-language (existing `tgac-*-toolchain` images) |
|---|---|---|
| Onboarding | One `docker build`/`docker pull`, then any covered language works | One pull/build per language touched; the first language needed is fast, but running the full 22-language suite still means 22 pulls |
| Coverage | 16 of 22 languages (see table above); the remaining 6 fall back to the existing per-language image | All 22 languages |
| Toolchain freshness/fidelity | Pinned to whatever Debian bookworm's apt repository ships (often older than upstream); some implementations may fail to build against it | Each image pins the exact upstream version the implementation was written against (see each `implementations/<language>/docker-images/toolchain/Dockerfile`) |
| Image size | Expected to be large: apt `build-essential`+`ghc`+`golang-go`+`rustc`+Node all in one image, plus a `cargo install`-built `gleam`. *(pending CI measurement)* | Each image only carries its own runtime; typically much smaller individually, larger in aggregate once every language has been pulled |
| Rebuild/cache cost | A change affecting any one toolchain invalidates apt layers shared by all the others in the same `RUN`; rebuilding is all-or-nothing for that layer | Changing one language's toolchain only rebuilds that language's image; other languages are untouched |
| Security/update surface | One image to patch and re-scan, but a vulnerability in any single toolchain's dependency affects the whole image's blast radius | Twenty-two images to patch/re-scan independently, but each vulnerability is scoped to the language that has it |
| CI fit | Good for "build/test everything in one job" workflows; poor fit for the existing per-language matrix build (`.github/workflows/test.yaml`), which intentionally isolates each language's toolchain image | Matches the existing CI matrix (`test.yaml`, `publish-toolchains.yml`) exactly; no migration needed |
| Fits repo's stated primary use case ("running the complete multi-language benchmark locally and in CI") | Strong for a single local machine wanting to try several languages quickly | Strong for CI, where per-language image isolation, independent caching, and matrix parallelism are already load-bearing |

**Recommendation:** keep the shared-base-plus-per-language images (`tgac-<language>-toolchain`)
as the system of record for CI and for any language-specific correctness guarantee, and treat
the unified image as an additive local-convenience layer for the languages it can honestly
support. This matches what is implemented here: nothing about the per-language Docker path
changed, and the unified image's `--local` execution mode was added to the shared tooling
(`tooling/shared.ts`, `tooling/chess.ts`) as a pure addition, not a replacement, so both paths
stay available side by side.

## CI

`.github/workflows/unified-image.yml`:

- Builds `Dockerfile.unified` on every change to it or to `docker-images/unified/**`.
- Smoke-tests one representative implementation per included toolchain family
  (`c`, `go`, `python`, `ruby`, `php`, `lua`, `rust`, `elixir`, `haskell`, `gleam`,
  `javascript`, `typescript`, `elm`, `imba`, `rescript`, `zig`) via
  `docker run ... tgac-unified test-chess-engine <language> --track v1`.
- Does not build or test the 6 excluded languages; their coverage remains
  `.github/workflows/test.yaml` and `.github/workflows/publish-toolchains.yml`, unchanged.
