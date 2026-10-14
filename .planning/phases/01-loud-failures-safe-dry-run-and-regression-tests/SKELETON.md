# Walking Skeleton — rea-installer

**Phase:** 1
**Generated:** 2026-10-14

## Capability Proven End-to-End

A maintainer runs `./test.sh` (locally, or through GitHub Actions on every push and pull request) and gets one `PASS`/`FAIL`/`SKIP` line per check. The checks run the real installer scripts' own functions, loaded by `source` through a guard that still runs `main` under `curl | bash`.

This project is three standalone installer scripts, not a web app. The template's "routing / DB / UI / deployment" layers map onto this domain as follows:

| Template layer | This project's equivalent |
|---|---|
| Project scaffold (build, lint, test runner) | `test.sh` at the repo root: plain bash, `bash -n`, `shellcheck`, PowerShell parser |
| Routing (one real route) | Source guard at the bottom of each bash script: sourced means functions only, run or piped means `main` |
| Database read + write | Installer ledger `~/.rea-installer/installed` and shell profile block, exercised under a temporary `HOME` |
| UI interaction wired to the API | A check that calls a real script function (`node_supported`, `unpack`, `pkg_install`, `brew_install`, `do_uninstall`) through the real `run`/`record` wrappers |
| Deployment / documented full-stack run | `.github/workflows/test.yml` runs `./test.sh` on `ubuntu-latest` and `/bin/bash ./test.sh` on `macos-latest` |

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Test runner | One plain-bash `./test.sh` in the repo root, no framework, Bash 3.2 compatible, `set -u` only (no `set -e`) | D-03, D-11; the macOS CI job runs it under `/bin/bash` 3.2; `set -e` would stop at the first failing check |
| Function access | `(return 0 2>/dev/null) && return 0` on the line after the `# ---- main` banner in `rea-install-linux.sh` and `rea-install-macos.sh` | D-01; detects "being sourced", so `curl \| bash`, `bash < file` and `./file` still reach `main`. Header line count is untouched, so `usage()`'s `sed -n` ranges stay valid |
| Isolation | Each check runs in a plain-statement `sandbox` subshell that exports a temporary `HOME`, a stub-first `PATH`, `SHELL=/bin/bash` and no `ZDOTDIR`, then sources the script | D-02; `HOME` must be set before sourcing because `STATE_DIR`/`TOOLS_DIR` are computed at source time. A plain statement keeps the script's errexit semantics (a sandbox inside `if` or `\|\|` turns `set -e` off) |
| Failure injection | Executable stubs (`sudo`, `apt-get`, `apt-cache`, `dpkg-query`, `tar`, `brew`, `npm`, `rea`, `node`) in a `mktemp -d` folder at the front of `PATH` | D-02; the real `run`/`record` wrappers stay on the tested path |
| Fresh-machine simulation | `docker run --rm --network none --platform linux/amd64 -v "$root:/src:ro" ubuntu:24.04` | D-04; real absence of Node and curl, read-only repo, no network proves the dry run downloads nothing; amd64 so the Ghidra branch runs on Apple silicon too |
| PowerShell checks | A small driver `.ps1` generated at runtime into the work folder, dot-sources `rea-install-windows.ps1`, overrides `$ToolsDir`/`$StateDir`/`$StateFile`, prints `PASS:`/`FAIL:` lines that `test.sh` counts | No Pester dependency; dot-sourcing with no command only prints help |
| Missing tools | `need TOOL CHECK`: `SKIP` locally; `FAIL` when `CI=true`, except Docker and shellcheck on Darwin (expected absent on `macos-latest`) | D-10, D-13; the Ubuntu job lints both scripts, so lint does not depend on host OS |
| OS-gated checks | Linux-script profile and uninstall checks run only on Linux (GNU `sed -i`, `tac`); macOS-script ones only on Darwin (BSD `sed -i ''`, `tail -r`) | Each CI job covers its half; an OS-gated `SKIP` is not a missing tool and never fails CI |
| CI | `.github/workflows/test.yml`, `on: [push, pull_request]`, `permissions: contents: read`, two independent jobs, `actions/checkout@v7.0.1` | D-12; all logic stays in `test.sh` |
| Directory layout | `test.sh` at the root; no `tests/` folder and no tracked fixtures; stubs, temp `HOME` and sample profiles are generated in one `mktemp -d` folder removed by an `EXIT` trap (`rm -rf "${work:?}"`) | D-03 |

## Stack Touched in Phase 1

- [ ] Project scaffold: `test.sh` with `ok`/`bad`/`skip` counters, summary line, exit 1 on any `FAIL` (plan 01-01, tracer task)
- [ ] Routing: source guard in both bash scripts, plus checks that a piped run reaches `main` and a sourced load does not (plan 01-01)
- [ ] Ledger and profile read/write: profile-block round trip (TEST-02) and ledger assertions in the failure checks (plans 01-01, 01-02)
- [ ] Real function calls through real wrappers: `node_supported` table (01-01); `unpack`, `pkg_install`, `brew_install`, `do_uninstall`, `Expand-PinnedArchive`, `Invoke-Uninstall` (01-02)
- [ ] CI: `.github/workflows/test.yml` running `test.sh` on Ubuntu and on macOS Bash 3.2 (plan 01-01)

## Out of Scope (Deferred to Later Slices)

- Fixing `usage()`'s `sed -n '2,Np' "$0"` under `curl | bash` (CONTEXT deferred). The guard check asserts `unknown command: bogus` instead of usage output.
- Rolling back a partial install on failure (D-07 rejected it).
- Profile files without a trailing newline (RESEARCH Pitfall 6): pre-existing uninstall bug. TEST-02's sample ends with a newline. Recorded as a deferred item in the plan 01-01 SUMMARY.
- Running the macOS script's own `install --dry-run` in CI (D-13: the runner is not a fresh Mac).
- Real macOS and Windows installs (v2 VERI-01/02).
- A shared helper library across the scripts (each stays standalone for `curl | bash`).

## Subsequent Slice Plan

Each later phase adds checks to the same `test.sh` and fixes to the same three scripts, without changing the decisions above:

- Phase 2: Consistent Java handling. `test.sh` gains JDK-version checks for each platform, using the same `sandbox` + stub `java` pattern.
- Phase 3: macOS unattended install and README sync. A no-tty / `--yes` Homebrew check for the macOS script; the README "Testing" section describes `./test.sh` and the CI workflow.
