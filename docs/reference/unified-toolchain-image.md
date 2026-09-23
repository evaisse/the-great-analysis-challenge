# Unified Toolchain Image

Tracks issue [#173](https://github.com/evaisse/the-great-analysis-challenge/issues/173).

`Dockerfile.unified` builds one image containing several language toolchains, so a fresh
checkout can build/analyze/test/run multiple implementations without first building or
pulling one dedicated `ghcr.io/evaisse/tgac-<language>-toolchain` image per language. It is
an **additional, opt-in convenience path**; it does not replace the per-language toolchain
images or the existing `make image|build|analyze|test|test-chess-engine DIR=<language>`
commands, which are unchanged and remain the source of truth for CI and for any language not
covered by the unified image.

**Status: build- and run-verified, locally and on CI.** `docker build -f Dockerfile.unified .`
and representative `build`/`analyze`/`test`/`test-chess-engine` runs pass both locally
(Docker Desktop, `linux/amd64`) and on GitHub Actions
(`.github/workflows/unified-image.yml`, native amd64) for all 13 included languages. See
"Local verification" below for exact commands and every finding along the way — including
three languages dropped from the image after real build/run failures, not just static review.

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

Included — **13 of 22** languages, installed via `apt-get`, `npm`, or `pip` only, per the
repository's "no external downloads in Dockerfiles" rule in `AGENTS.md`, and confirmed
buildable *and* functional (build/analyze/test, and for go/python the full protocol suite) both
locally and on GitHub Actions CI:

| Language | Install method | Note |
|---|---|---|
| c | apt (`gcc`) | |
| elm | `npm install -g elm@0.19.1-5` | Same version pin as `implementations/elm/docker-images/toolchain/Dockerfile` |
| go | apt (`golang-go`) | Debian bookworm ships Go 1.19 against a `go 1.21` directive; builds cleanly anyway (older `go` does not enforce the directive as a hard failure) |
| haskell | apt (`ghc`, `cabal-install`) | |
| imba | `npm install -g imba@2.0.0-alpha.251` | Pinned below `imba@2.0.0-alpha.252`, which raised its `engines.node` requirement to `>=20.19`; Debian bookworm's apt `nodejs` is 18.x with no compliant (non-curl) upgrade path. `alpha.251` satisfies `implementations/imba`'s own `^2.0.0-alpha.247` dependency range |
| javascript, typescript | `npm install -g bun` | Installed via bun's documented npm package, not the curl installer |
| lua | apt (`lua5.4`) | |
| php | apt (`php-cli`) | |
| python | apt (`python3`, `python3-pip`) | |
| rescript | apt `nodejs`/`npm`, project deps via `npm ci` | See "First-run dependency install" below |
| ruby | apt (`ruby-full`) + `gem install bundler` | Required a one-line fix to `implementations/ruby/Gemfile.lock`; see "Local verification" |
| zig | `pip install ziglang` | No Debian package; the PyPI wheel ships the compiler binary |

Excluded — **9 of 22** languages, no install path through a system/language package manager
alone. Every exclusion below was either obviously true from the outset (crystal, dart, kotlin,
nim, swift) or, for the other three, only discovered by actually attempting a build/run:

| Language | Why excluded |
|---|---|
| crystal | Official distribution is a vendor apt repository added via a downloaded GPG key, or a tarball; no plain Debian package |
| dart | Same as crystal: Google's apt repo requires a downloaded signing key |
| elixir | Debian bookworm's apt `elixir` is 1.14.0; `implementations/elixir/mix.exs` requires `~> 1.17`. Confirmed by a real `mix compile` failure **on GitHub Actions CI** (native amd64, not an emulation artifact): `You're trying to run :chess_engine on Elixir v1.14.0 but it has declared in its mix.exs file it supports only Elixir ~> 1.17`. `bookworm-backports` does not carry a newer Elixir either |
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
tree, not a fixed snapshot), so its entrypoint installs them the first time you
`build`/`analyze`/`test`/`run` an implementation:

- Node-based implementations: `npm ci` when a `package-lock.json` is committed (`rescript`,
  `imba`, `typescript`) — confirmed to never rewrite the lockfile, unlike `npm install`, which
  was observed mutating it even with nothing new to resolve. `elm` and `javascript` have no
  committed lockfile, so they fall back to `npm install`, which creates one as a new untracked
  file (see "Bind-mount side effects"). `npm`, not `bun`, to match each project's own
  toolchain Dockerfile convention and avoid creating a stray `bun.lock`.
- Ruby: `bundle install` when a `Gemfile` is present (only if `bundle check` reports unmet
  dependencies).
- The repository root itself, once, for the shared `./workflow` tooling: `bun install
  --frozen-lockfile`.

This needs network access; run it once while online, then work offline as usual (containers
are ephemeral, so `docker run --rm` repeats the install every time — use `tgac-unified shell`
for a session that keeps it installed across several commands).

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
- **Haskell's compiled binary** (`chess_engine`), **Elm's compiled** `src/chess.js`, and a
  first-run `package-lock.json` for `elm`/`javascript` (the two implementations with no
  committed lockfile) land as new, currently un-gitignored files. Clean them up with
  `git clean` or add `.gitignore` entries if this bothers you; out of scope to fix here since
  it touches other languages' directories.
- Ruby's `Gemfile.lock` needed a genuine, minimal fix as part of this change (see below) —
  that one *was* fixed, because it was a one-line, purely-additive correction required for the
  feature to work without side effects at all.

If you want a pristine working tree after using the unified image, run it against a disposable
clone (`git worktree add` or a plain `git clone`) instead of your primary checkout.

## Local verification

Docker was not available when this image was first authored; it became available partway
through this change (Docker Desktop, `linux/amd64` locally; GitHub Actions' `ubuntu-latest`
runners for CI — the same architecture). What follows is everything a real `docker build` and
representative `docker run`/CI invocations found that static review had not, in the order
found:

- **`cargo install gleam` does not install the Gleam compiler.** Crates.io hosts an unrelated
  library also named `gleam` (`gleam v0.15.1`, "has no binaries"). Discovered by CI's very
  first run on this branch. Moved gleam to the excluded list.
- **Debian bookworm's apt `rustc`/`cargo` (1.63 / 0.66) cannot build this repository's Rust
  implementation** — `Cargo.lock` uses lockfile format `version = 4`, which requires cargo
  >=1.78. `bookworm-backports` does not carry a newer `rustc`. Discovered by a real local
  `docker build`. Moved rust to the excluded list.
- **`imba`'s latest npm release requires Node >=20.19**, which Debian bookworm's apt `nodejs`
  (18.x) does not satisfy, causing an `ERR_REQUIRE_ESM` crash at runtime (a stricter, later
  failure than npm's own non-fatal `EBADENGINE` warning suggested). Fixed by pinning to
  `imba@2.0.0-alpha.251` — the newest release still declaring `node >=13.10`, and one that
  satisfies `implementations/imba`'s own dependency range — without dropping the language.
- **Ruby's `bundle install`/`bundle check` wanted to add `x86_64-linux` to
  `implementations/ruby/Gemfile.lock`'s `PLATFORMS` list** (the committed lockfile only listed
  `arm64-darwin-23`, from whoever last ran `bundle lock` on macOS). Left as-is, every
  `analyze`/`test ruby` run would have dirtied that tracked file. Fixed by committing the
  platform addition once (`bundle lock --add-platform x86_64-linux`, a one-line, additive
  change), so the unified image's Ruby path is idempotent against a clean checkout.
- **`npm install` rewrites `package-lock.json` even when there is nothing new to resolve**
  (observed for `rescript`: adding no new packages still produced a diff). Since implementations
  keep this file committed, that would dirty the tree on every first run. Fixed by switching the
  first-run install to `npm ci` when a lockfile is committed (never rewrites it; fails loudly
  instead if the lockfile and `package.json` disagree) — `elm` and `javascript` have no
  committed lockfile, so they still use `npm install`, which creates one as a new, currently
  untracked file (harmless, but worth knowing about).
- **Go's build failed with `error obtaining VCS status: exit status 128` on GitHub Actions CI**
  (a plain `actions/checkout`, native amd64, run `35920887060`): the container always runs as
  root against a bind mount owned by whatever CI user cloned it, which git's ownership check
  rejects ("detected dubious ownership"). The same symptom, different cause, showed up locally
  too when testing from this repository's own `.worktrees/` checkout (a git worktree's `.git`
  file points at an absolute host path outside the bind mount). Fixed the ownership case with
  `git config --system --add safe.directory '*'` baked into the image (harmless here: this
  image's only job is to run against whatever repository the caller explicitly bind-mounted,
  not to broker access to arbitrary git repos) — confirmed fixed by both a local re-run and a
  subsequent green CI run. The worktree case is different and not fixed by this — the
  referenced `.git/worktrees/<name>` directory genuinely does not exist inside the container —
  so it remains a real caveat: run the unified image against a plain clone/checkout rather than
  a `.worktrees/` checkout, or set `GOFLAGS=-buildvcs=false`.
- **Elixir's `mix compile` segfaulted consistently under local QEMU `amd64`-on-`arm64`
  emulation** (this reviewer's Apple Silicon host), with `elixir`/`erlang` otherwise installing
  and running correctly natively (`arm64`) — this looked at first like a QEMU/BEAM-JIT
  interaction and was reported as such pending CI. **GitHub Actions CI (native amd64) then
  found the real, simpler cause**: Debian bookworm's apt `elixir` is 1.14.0, and
  `implementations/elixir/mix.exs` requires `~> 1.17`
  (`You're trying to run :chess_engine on Elixir v1.14.0 but it has declared in its mix.exs
  file it supports only Elixir ~> 1.17`) — a real version mismatch that the local QEMU segfault
  had been masking, not an emulation artifact at all. No apt backport carries a newer Elixir.
  Moved elixir to the excluded list. (Lesson: a plausible-looking explanation for a local-only
  failure — "must be the emulator" — turned out to be wrong; the CI run that could have been
  skipped as "just confirming what we already know" instead overturned the working theory.)
- **All 13 remaining included languages** (`c`, `go`, `python`, `ruby`, `php`, `lua`,
  `haskell`, `javascript`, `typescript`, `elm`, `imba`, `rescript`, `zig`) pass `build`,
  `analyze`, `test`, and `test-chess-engine --track v1` both locally and on GitHub Actions CI
  (`.github/workflows/unified-image.yml`). `go` and `python` additionally passed the full
  `test-chess-engine --track v1` suite locally (27/27 tests each), and `python`'s `run` command
  was exercised interactively over real stdin/stdout.
- **Image size**: 769MB (`docker images tgac-unified`, `linux/amd64`, 13 languages, after
  excluding elixir/erlang/gleam/rust). **Build time**: cold builds ranged roughly 2–4 minutes
  locally under QEMU emulation on Apple Silicon (the combined `apt-get install` layer is the
  bulk of it); CI's native amd64 runners built and ran the full 13-language smoke-test matrix
  in well under 15 minutes end to end. Rebuilds that only touch the entrypoint script are
  near-instant via Docker layer cache.

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
run for `<language>` in `c go python ruby php lua haskell javascript typescript elm imba rescript zig`,
against a plain `git clone` of this branch rather than this repository's own git-worktree
checkout (see the Go finding above for why), plus the equivalent runs GitHub Actions CI
performs on every push/PR via `.github/workflows/unified-image.yml`.

## Design comparison: monolithic vs. shared-base + per-language

Issue #173 asked for both options to be built and compared honestly.

| Dimension | Monolithic (`Dockerfile.unified`) | Shared-base + per-language (existing `tgac-*-toolchain` images) |
|---|---|---|
| Onboarding | One `docker build`/`docker pull`, then any covered language works | One pull/build per language touched; the first language needed is fast, but running the full 22-language suite still means 22 pulls |
| Coverage | 13 of 22 languages (see table above); the remaining 9 fall back to the existing per-language image | All 22 languages |
| Toolchain freshness/fidelity | Pinned to whatever Debian bookworm's apt repository ships, confirmed older than upstream for at least go (1.19 vs. 1.23) and imba (pinned below latest to stay Node-18-compatible); confirmed **unable** to support elixir, gleam, or rust at all for this reason | Each image pins the exact upstream version the implementation was written against (see each `implementations/<language>/docker-images/toolchain/Dockerfile`) |
| Image size | 769MB measured (`linux/amd64`, 13 languages) | Each image only carries its own runtime; typically much smaller individually (e.g. a single-language `python:3.13-slim`-based image), larger in aggregate once every language has been pulled |
| Build time | ~2–4 min cold locally (QEMU-emulated); CI's native amd64 build + full 13-language smoke-test matrix completes in well under 15 minutes | Each per-language image builds independently and in parallel in CI (`publish-toolchains.yml` matrix); no single long combined layer |
| Rebuild/cache cost | A change affecting any one toolchain invalidates the combined apt layer shared by every other apt-installed language; rebuilding that layer is all-or-nothing | Changing one language's toolchain only rebuilds that language's image; other languages are untouched |
| Security/update surface | One image to patch and re-scan, but a vulnerability in any single toolchain's dependency affects the whole image's blast radius | Twenty-two images to patch/re-scan independently, but each vulnerability is scoped to the language that has it |
| Working-tree safety | Operates on a bind mount: confirmed to regenerate tracked build output (TypeScript/Imba `dist/`), required trusting the mount for git (`safe.directory`), and required one real source fix (Ruby's `Gemfile.lock`) to avoid dirtying the tree | Builds inside an ephemeral image from a copied source tree; the host checkout is never touched |
| CI fit | Good for "build/test everything in one job" workflows; poor fit for the existing per-language matrix build (`.github/workflows/test.yaml`), which intentionally isolates each language's toolchain image | Matches the existing CI matrix (`test.yaml`, `publish-toolchains.yml`) exactly; no migration needed |
| Fits repo's stated primary use case ("running the complete multi-language benchmark locally and in CI") | Strong for a single local machine wanting to try several languages quickly, weaker the more of the 9 excluded languages matter to you | Strong for CI, where per-language image isolation, independent caching, and matrix parallelism are already load-bearing |

**Recommendation:** keep the shared-base-plus-per-language images (`tgac-<language>-toolchain`)
as the system of record for CI and for any language-specific correctness guarantee, and treat
the unified image as an additive local-convenience layer for the languages it can honestly
support. Real build/run attempts reinforced this rather than weakening it: three languages
(elixir, gleam, rust) turned out to have **no** viable package-manager-only install path new
enough for this repository at all, and a fourth (imba) needed a specific older version pinned
to work around a Node version ceiling that the per-language image doesn't have (it uses
`node:22-alpine`, not Debian's apt `nodejs`). Nothing about the per-language Docker path
changed; the unified image's `--local` execution mode was added to the shared tooling
(`tooling/shared.ts`, `tooling/chess.ts`) as a pure addition, not a replacement, so both paths
stay available side by side.

## CI

`.github/workflows/unified-image.yml`:

- Builds `Dockerfile.unified` on every change to it or to `docker-images/unified/**`.
- Smoke-tests one representative implementation per included toolchain family
  (`c`, `go`, `python`, `ruby`, `php`, `lua`, `haskell`, `javascript`, `typescript`, `elm`,
  `imba`, `rescript`, `zig`) via `docker run ... tgac-unified build|analyze|test`, then
  `docker run ... tgac-unified test-chess-engine <language> --track v1`. All 13 currently pass.
- Does not build or test the 9 excluded languages; their coverage remains
  `.github/workflows/test.yaml` and `.github/workflows/publish-toolchains.yml`, unchanged.
