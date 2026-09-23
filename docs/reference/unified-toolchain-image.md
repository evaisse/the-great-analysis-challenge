# Unified Toolchain Image

Tracks issue [#173](https://github.com/evaisse/the-great-analysis-challenge/issues/173).

`Dockerfile.unified` builds one image containing several language toolchains, so a fresh
checkout can build/analyze/test/run multiple implementations without first building or
pulling one dedicated `ghcr.io/evaisse/tgac-<language>-toolchain` image per language. It is
an **additional, opt-in convenience path**; it does not replace the per-language toolchain
images or the existing `make image|build|analyze|test|test-chess-engine DIR=<language>`
commands, which are unchanged and remain the source of truth for CI and for any language not
covered by the unified image.

**Status: build-verified locally (`linux/amd64`), CI pending.** `docker build -f
Dockerfile.unified .` and representative `build`/`analyze`/`test`/`test-chess-engine` runs
were exercised locally with Docker Desktop once it became available (see "Local verification"
below). `.github/workflows/unified-image.yml` builds it and smoke-tests one implementation per
included toolchain family on every change; treat that workflow, not this document, as the
final confirmation before relying on the image outside local development.

## Quick start

```bash
docker build -f Dockerfile.unified -t tgac-unified .

# Interactive shell with every included toolchain on PATH
docker run --rm -it -v "$PWD":/workspace tgac-unified shell

# Build / analyze / test a single implementation, no per-language image needed
docker run --rm -v "$PWD":/workspace tgac-unified build python
docker run --rm -v "$PWD":/workspace tgac-unified analyze go
docker run --rm -v "$PWD":/workspace tgac-unified test ruby

# Shared cross-language protocol suite
docker run --rm -v "$PWD":/workspace tgac-unified test-chess-engine python --track v1

# Launch an implementation interactively (stdin/stdout protocol)
echo -e "new\nai 3\nexport\nquit" | docker run --rm -i -v "$PWD":/workspace tgac-unified run python
```

The container always operates on the repository bind-mounted at `/workspace`; there is no
image variant that bakes in a copy of the source, so it always reflects your working tree (see
"Bind-mount side effects" below for what that implies).

### From the root Makefile

Inside a shell started from `tgac-unified shell` (repo mounted, `TGAC_UNIFIED_IMAGE=1` set),
the existing commands work unchanged and skip the per-language Docker step:

```bash
make build DIR=python
make analyze DIR=go
make test DIR=ruby
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

Included (installed via `apt-get`, `npm`, or `pip` only, per the repository's "no external
downloads in Dockerfiles" rule in `AGENTS.md` — confirmed buildable and, per the verification
table below, functional):

| Language | Install method | Note |
|---|---|---|
| c | apt (`gcc`) | |
| elixir | apt (`elixir`, `erlang`) | Build verified to segfault under `linux/amd64` QEMU emulation on Apple Silicon; see "Local verification" |
| elm | `npm install -g elm@0.19.1-5` | Same version pin as `implementations/elm/docker-images/toolchain/Dockerfile` |
| go | apt (`golang-go`) | Debian bookworm ships Go 1.19 against a `go 1.21` directive; builds cleanly anyway (older `go` does not enforce the directive as a hard failure) |
| haskell | apt (`ghc`, `cabal-install`) | |
| imba | `npm install -g imba@2.0.0-alpha.251` | Pinned below `imba@2.0.0-alpha.252`, which raised its `engines.node` requirement to `>=20.19`; Debian bookworm's apt `nodejs` is 18.x with no compliant (non-curl) upgrade path. `alpha.251` satisfies `implementations/imba`'s own `^2.0.0-alpha.247` dependency range |
| javascript, typescript | `npm install -g bun` | Installed via bun's documented npm package, not the curl installer |
| lua | apt (`lua5.4`) | |
| php | apt (`php-cli`) | |
| python | apt (`python3`, `python3-pip`) | |
| rescript | apt `nodejs`/`npm`, project deps via `npm install` | See "First-run dependency install" below |
| ruby | apt (`ruby-full`) + `gem install bundler` | Required a one-line fix to `implementations/ruby/Gemfile.lock`; see "Local verification" |
| zig | `pip install ziglang` | No Debian package; the PyPI wheel ships the compiler binary |

Excluded (no install path through a system/language package manager alone — confirmed, not
assumed; see "Local verification" for gleam and rust, which were only discovered to need
exclusion after a real `docker build` failure):

| Language | Why excluded |
|---|---|
| crystal | Official distribution is a vendor apt repository added via a downloaded GPG key, or a tarball; no plain Debian package |
| dart | Same as crystal: Google's apt repo requires a downloaded signing key |
| gleam | No Debian package (confirmed via `apt-cache search` against `debian:bookworm-slim`). The "gleam" package name is unrelated/library-only on both crates.io (`cargo install gleam` resolves `gleam v0.15.1`, "has no binaries") and npm (`gleam@3.1.2`, an unrelated "isomorphic entity" library) |
| julia | Debian's apt package trails the pinned 1.11 toolchain too far to trust for this repository's correctness-sensitive benchmark suite |
| kotlin | No Debian package for `kotlinc`; upstream distribution is SDKMAN or a downloaded release archive |
| nim | No reliably available/current Debian package across supported releases |
| rust | Debian bookworm's apt `rustc`/`cargo` (1.63 / 0.66 — confirmed via `apt-cache policy`, including `bookworm-backports`, which does not carry a newer build) cannot parse this repository's `Cargo.lock` (lockfile format `version = 4`, requires cargo >=1.78). Confirmed by a real `cargo build --release` failure: `lock file version 4 was found, but this version of Cargo does not understand this lock file`. The supported newer-Rust install path is the curl-piped rustup.rs installer, which this repo's rules forbid |
| swift | Swift.org ships Linux tarballs only, no apt repository |

Excluded languages are unaffected: `make image|build|analyze|test|test-chess-engine
DIR=<language>` continues to use their dedicated `tgac-<language>-toolchain` image exactly as
before. `docker run ... tgac-unified languages` prints this include/exclude list from inside
the image.

### First-run dependency install

A few implementations keep their build tooling as project-local `npm` dependencies
(`rescript`, `imba`, and `javascript`/`typescript`'s own `package.json`) rather than a global
compiler, mirroring how their dedicated toolchain images preinstall those dependencies at
image-build time. The unified image cannot bake those in (they are read from your working
tree, not a fixed snapshot), so its entrypoint runs `npm install` in the implementation
directory the first time you `build`/`analyze`/`test`/`run` it (matching each project's own
committed `package-lock.json` and its dedicated toolchain Dockerfile — `npm`, not `bun`, to
avoid creating a stray `bun.lock` next to an npm-managed project), Ruby's `bundle install`
when a `Gemfile` is present, and `bun install --frozen-lockfile` once at the repository root
for the shared `./workflow` tooling itself. This needs network access; run it once while
online, then work offline as usual (containers are ephemeral, so `docker run --rm` repeats the
install every time — use `tgac-unified shell` for a session that keeps it installed across
several commands).

### Bind-mount side effects

Because the unified image always operates directly on your bind-mounted working tree (unlike
the per-language Docker path, which builds inside an ephemeral image from a copy of the
source), any implementation whose build process writes into a tracked file will show that as a
local diff. Confirmed during local verification:

- **TypeScript and Imba commit their compiled output** (`implementations/{typescript,imba}/dist/`).
  Rebuilding regenerates it from `src/`; for TypeScript this produced a large diff because the
  committed output was already stale relative to source (missing PGN/opening-book/chess960
  code present in `src/chess.ts`). This predates and is unrelated to the unified image — it
  would happen with any local, non-Docker rebuild of these two languages — the unified image
  just makes it visible for the first time. Run `git diff`/`git checkout` on `dist/` afterward
  if you don't want the regenerated output, or work from a scratch clone.
- **Haskell's compiled binary** (`chess_engine`) and **Elm's compiled** `src/chess.js` land as
  new, currently un-gitignored files. Clean them up with `git clean` or add `.gitignore`
  entries if this bothers you; out of scope to fix here since it touches other languages'
  directories.
- Ruby's `Gemfile.lock` needed a genuine, minimal fix as part of this change (see below) —
  that one *was* fixed, because it was a one-line, purely-additive correction required for the
  feature to work without side effects at all.

If you want a pristine working tree after using the unified image, run it against a disposable
clone (`git worktree add` or a plain `git clone`) instead of your primary checkout.

## Local verification

Docker was not available when this image was first authored; it became available partway
through this change (Docker Desktop, this repo's `linux/amd64` target — the same architecture
GitHub Actions `ubuntu-latest` runners use). What follows is what a real `docker build` and
representative `docker run` invocations found, on an Apple Silicon host building for
`linux/amd64` (`docker build --platform linux/amd64`):

- **`cargo install gleam` does not install the Gleam compiler.** Crates.io hosts an unrelated
  library also named `gleam` (`gleam v0.15.1`, "has no binaries"). This was only discoverable
  by actually running the build — gleam was moved to the excluded list as a result (see
  coverage table).
- **Debian bookworm's apt `rustc`/`cargo` (1.63 / 0.66) cannot build this repository's Rust
  implementation** — `Cargo.lock` uses lockfile format `version = 4`, which requires cargo
  >=1.78. `bookworm-backports` does not carry a newer `rustc`. Rust was moved to the excluded
  list as a result.
- **`imba`'s latest npm release requires Node >=20.19**, which Debian bookworm's apt `nodejs`
  (18.x) does not satisfy, causing an `ERR_REQUIRE_ESM` crash at runtime (a stricter, later
  failure than npm's own non-fatal `EBADENGINE` warning suggested). Pinning to
  `imba@2.0.0-alpha.251` — the newest release still declaring `node >=13.10`, and one that
  satisfies `implementations/imba`'s own dependency range — fixed this without dropping the
  language.
- **Ruby's `bundle install`/`bundle check` wanted to add `x86_64-linux` to
  `implementations/ruby/Gemfile.lock`'s `PLATFORMS` list** (the committed lockfile only listed
  `arm64-darwin-23`, from whoever last ran `bundle lock` on macOS). Left as-is, every
  `analyze`/`test ruby` run would have dirtied that tracked file. Fixed by committing the
  platform addition once (`bundle lock --add-platform x86_64-linux`, a one-line, additive
  change) as part of this PR, so the unified image's Ruby path is idempotent against a clean
  checkout.
- **Go's build failed with `error obtaining VCS status`** when tested from this repository's
  own `.worktrees/` checkout: a git worktree's `.git` file points at an absolute host path
  (`.git/worktrees/<name>` inside the *main* repository clone) that isn't inside the bind
  mount, so `git` inside the container can't find it. Confirmed as worktree-specific, not a
  toolchain bug, by testing the same build against a plain `git clone` of the same branch
  (succeeded immediately). If you hit this, either run the unified image against a plain
  clone/checkout instead of a worktree, or set `GOFLAGS=-buildvcs=false`.
- **Elixir's `mix compile` segfaults consistently under `linux/amd64` QEMU emulation** on this
  Apple Silicon host, but `elixir`/`erlang` install and run correctly natively (`arm64`),
  confirmed by installing and invoking `erl`/`elixir --version` directly in a native
  `debian:bookworm-slim` container. This matches a known category of interaction between
  Erlang/OTP's JIT (introduced in OTP 24+) and QEMU's user-mode binary translation. It has
  **not** been confirmed to work on a native `amd64` machine (GitHub Actions' `ubuntu-latest`
  runners are real x86_64 hardware, not emulated) — `.github/workflows/unified-image.yml`'s
  Elixir smoke-test job is the pending confirmation.
- **All other included languages** (`c`, `go`, `python`, `ruby`, `php`, `lua`, `haskell`,
  `javascript`, `typescript`, `elm`, `imba`, `rescript`, `zig`) passed `build`, `analyze`, and
  `test` locally. `go` and `python` additionally passed the full `test-chess-engine --track v1`
  suite (27/27 tests each) through `docker run ... tgac-unified test-chess-engine <language>
  --track v1`, and `python`'s `run` command was exercised interactively over real stdin/stdout.
- **Image size**: 995MB (`docker images tgac-unified`, `linux/amd64`, after excluding
  gleam/rust). **Build time**: ~3m40s cold (mostly the combined `apt-get install` layer, ~78s
  of that under real hardware vs. ~160s observed under QEMU emulation on this host); near-instant
  on a rebuild that only touches the entrypoint script (Docker layer cache). These numbers are
  from local QEMU-emulated `linux/amd64` builds on Apple Silicon, not from CI; expect CI's
  native `amd64` numbers to differ (likely faster for the apt layer, unaffected for the pip/npm
  layers).

Exact commands run, for reproducibility:

```bash
docker build --platform linux/amd64 -f Dockerfile.unified -t tgac-unified .
docker run --rm --platform linux/amd64 tgac-unified languages
docker run --rm --platform linux/amd64 -v <clone>:/workspace tgac-unified build <language>
docker run --rm --platform linux/amd64 -v <clone>:/workspace tgac-unified analyze <language>
docker run --rm --platform linux/amd64 -v <clone>:/workspace tgac-unified test <language>
docker run --rm --platform linux/amd64 -v <clone>:/workspace tgac-unified test-chess-engine go --track v1
docker run --rm --platform linux/amd64 -v <clone>:/workspace tgac-unified test-chess-engine python --track v1
echo -e "new\nmove e2e4\nexport\nquit" | docker run --rm -i --platform linux/amd64 -v <clone>:/workspace tgac-unified run python
```
run for `<language>` in `c go python ruby php lua haskell javascript typescript elm imba rescript zig` (elixir build attempted and found to segfault, see above), against a plain `git clone` of this branch rather than this repository's own git-worktree checkout (see the Go finding above for why).

## Design comparison: monolithic vs. shared-base + per-language

Issue #173 asked for both options to be built and compared honestly.

| Dimension | Monolithic (`Dockerfile.unified`) | Shared-base + per-language (existing `tgac-*-toolchain` images) |
|---|---|---|
| Onboarding | One `docker build`/`docker pull`, then any covered language works | One pull/build per language touched; the first language needed is fast, but running the full 22-language suite still means 22 pulls |
| Coverage | 14 of 22 languages (see table above); the remaining 8 fall back to the existing per-language image | All 22 languages |
| Toolchain freshness/fidelity | Pinned to whatever Debian bookworm's apt repository ships, confirmed older than upstream for at least go (1.19 vs. 1.23) and imba (pinned below latest to stay Node-18-compatible); confirmed **unable** to support rust or gleam at all for this reason | Each image pins the exact upstream version the implementation was written against (see each `implementations/<language>/docker-images/toolchain/Dockerfile`) |
| Image size | 995MB measured (`linux/amd64`, 14 languages) | Each image only carries its own runtime; typically much smaller individually (e.g. a single-language `python:3.13-slim`-based image), larger in aggregate once every language has been pulled |
| Build time | ~3m40s cold locally (QEMU-emulated; CI's native amd64 runners should be faster for the apt layer), near-instant incremental rebuilds via Docker layer cache | Each per-language image builds independently and in parallel in CI (`publish-toolchains.yml` matrix); no single long combined layer |
| Rebuild/cache cost | A change affecting any one toolchain invalidates the combined apt layer shared by every other apt-installed language; rebuilding that layer is all-or-nothing | Changing one language's toolchain only rebuilds that language's image; other languages are untouched |
| Security/update surface | One image to patch and re-scan, but a vulnerability in any single toolchain's dependency affects the whole image's blast radius | Twenty-two images to patch/re-scan independently, but each vulnerability is scoped to the language that has it |
| Working-tree safety | Operates on a bind mount: confirmed to regenerate tracked build output (TypeScript/Imba `dist/`) and required one real source fix (Ruby's `Gemfile.lock`) to avoid dirtying the tree | Builds inside an ephemeral image from a copied source tree; the host checkout is never touched |
| CI fit | Good for "build/test everything in one job" workflows; poor fit for the existing per-language matrix build (`.github/workflows/test.yaml`), which intentionally isolates each language's toolchain image | Matches the existing CI matrix (`test.yaml`, `publish-toolchains.yml`) exactly; no migration needed |
| Fits repo's stated primary use case ("running the complete multi-language benchmark locally and in CI") | Strong for a single local machine wanting to try several languages quickly, weaker the more of the 8 excluded/segfaulting-under-emulation languages matter to you | Strong for CI, where per-language image isolation, independent caching, and matrix parallelism are already load-bearing |

**Recommendation:** keep the shared-base-plus-per-language images (`tgac-<language>-toolchain`)
as the system of record for CI and for any language-specific correctness guarantee, and treat
the unified image as an additive local-convenience layer for the languages it can honestly
support. Local verification reinforced this rather than weakening it: two languages (gleam,
rust) turned out to have **no** viable package-manager-only install path at all, and a third
(imba) needed a specific older version pinned to work around a Node version ceiling that the
per-language image doesn't have (it uses `node:22-alpine`, not Debian's apt `nodejs`). Nothing
about the per-language Docker path changed; the unified image's `--local` execution mode was
added to the shared tooling (`tooling/shared.ts`, `tooling/chess.ts`) as a pure addition, not a
replacement, so both paths stay available side by side.

## CI

`.github/workflows/unified-image.yml`:

- Builds `Dockerfile.unified` on every change to it or to `docker-images/unified/**`.
- Smoke-tests one representative implementation per included toolchain family
  (`c`, `go`, `python`, `ruby`, `php`, `lua`, `elixir`, `haskell`,
  `javascript`, `typescript`, `elm`, `imba`, `rescript`, `zig`) via
  `docker run ... tgac-unified test-chess-engine <language> --track v1`. This is the pending
  confirmation for whether Elixir's local-only segfault (see "Local verification") is in fact
  QEMU-emulation-specific, since these runners are native amd64.
- Does not build or test the 8 excluded languages; their coverage remains
  `.github/workflows/test.yaml` and `.github/workflows/publish-toolchains.yml`, unchanged.
