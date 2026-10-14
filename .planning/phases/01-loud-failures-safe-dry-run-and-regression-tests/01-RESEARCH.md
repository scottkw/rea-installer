# Phase 1: Loud Failures, Safe Dry Run, and Regression Tests - Research

**Researched:** 2026-10-14
**Domain:** Bash 3.2/5.x errexit semantics, shell test harness without a framework, PowerShell 5.1/7 error handling, GitHub Actions
**Confidence:** HIGH. Every fix and check below was built in a scratch copy of the scripts and run red (original) then green (patched). The runs used bash 3.2.57 on this Mac and bash 5.2.21 in `ubuntu:24.04`, with shellcheck 0.9.0 and 0.11.0 and pwsh 7.6.7.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Test access to script functions
- **D-01:** Add a source guard to `rea-install-linux.sh` and `rea-install-macos.sh` so `test.sh` can `source` a script and call its real functions (`node_supported`, `remove_profile_block`, `pkg_install`, `unpack`, `brew_install`) without running the bottom `main` dispatch. **Constraint:** the guard must still run main under `curl | bash`, where `BASH_SOURCE[0]` is empty and `$0` is `bash`. A naive `[ "${BASH_SOURCE[0]}" = "$0" ]` breaks the documented install path. Use a check that detects "being sourced" (e.g. `(return 0 2>/dev/null)`) rather than "being run as a file", and keep it Bash 3.2 and `set -u` safe. `test.sh` must include a check that the script still runs main when piped into bash (e.g. `bash < rea-install-linux.sh --help`-style or `cat script | bash -s -- --help` prints usage). — **Reversibility:** costly — the `curl | bash` contract is the published install path; a guard regression breaks every user install.
- **D-02:** Force failures with fake commands on `PATH`: `test.sh` writes stub `apt-get`/`dnf`/`pacman`/`unzip`/`tar`/`brew`/`rea`/`sudo` executables (exit 1 or record-and-succeed as needed) into a `mktemp -d` bin folder at the front of `PATH`, with a temporary `HOME`, then sources the script and calls the function. Do not redefine `run`; the real `run` wrapper must be on the tested path.
- **D-03:** One file: `./test.sh` in the repo root. Stubs, temp `HOME` and sample profiles are generated at runtime in `mktemp` dirs and cleaned up by a `trap`. No `tests/` directory, no tracked fixtures.
- **D-04:** TEST-04 runs via `docker run` from `test.sh`: mount the repo read-only into `ubuntu:24.04`, seed `~/.rea-installer/node/` and an empty `~/.agents/skills/`, run `install --dry-run --with-android` (no Node present) and `uninstall --dry-run`, assert exit 0 and that the seeded folders still exist. The same command works locally and in CI.
- **D-05:** TEST-05 red proof: commit `test.sh` (plus the source guard it needs) on its own **before** any FAIL/DRY fix, run it, and save the failing output to `.planning/phases/01-loud-failures-safe-dry-run-and-regression-tests/01-RED.log` in that commit or the next one. Then commit the fixes. The FAIL-01, FAIL-02 and DRY-01 checks must show FAIL in that log.

#### Extraction and failure semantics
- **D-06:** Overrides the AUDIT HARD-01 fix: **extract to a staging folder, then rename**. Linux `unpack` extracts into `$TOOLS_DIR/.staging-<name>` (deleted first if left over from an earlier run), then moves the expected top-level folder to `$target` only after the extract succeeds. On error: remove staging and `die "could not unpack <archive>"`. Windows `Expand-PinnedArchive` does the same with `try`/`catch`/`Remove-Item` and rethrow. A Ctrl-C or kill leaves only a staging folder, which the next run deletes, never a `$target` that a rerun would trust. Mirrors the existing `.part` download pattern. Must honor dry run (`run` / `Invoke-Step`, no real mkdir/mv/rm under `--dry-run`).
- **D-07:** No rollback. A failure stops the install. Items already recorded stay in the ledger so `uninstall` can remove them, and a rerun continues from there.
- **D-08:** Required tools: `pkg_install X || die "X is required ..."` (existing messages). Optional tools: replace `|| true` with `|| warn "<tool> could not be installed; skipping it."` (the existing pwntools pattern). A failed package is never recorded (`pkg_install`/`brew_install` get `|| return 1` on the install command, per AUDIT HARD-02). macOS `brew_install` failures are reported the same way (FAIL-03).
- **D-09:** UNIN-01 is as AUDIT HARD-07 specifies: bash `run "$rea_bin" uninstall --purge-data || warn "rea uninstall failed; remove agent registrations by hand."`. Windows wraps it in `try { ... } catch { Warn ... }`. Uninstall then continues through the rest of the ledger.

#### test.sh behavior with missing tools
- **D-10:** If `docker`, `pwsh` or `shellcheck` is missing, print `SKIP: <check> (<tool> not found)` and continue locally. When `CI=true`, a missing tool fails the run unless that tool is expected to be absent on that runner (see D-13). CI must never pass by skipping checks it was supposed to run.
- **D-11:** Output is one `PASS`/`FAIL`/`SKIP` line per check. Every check runs even after a failure, followed by a summary count. Exit 1 if any check failed. Plain bash, no test framework.

#### CI
- **D-12:** `.github/workflows/` workflow on every push and pull request with two jobs: `ubuntu-latest` runs the whole of `test.sh` (shellcheck, `bash -n`, pwsh parse, function checks, docker dry run); `macos-latest` runs `test.sh` under `/bin/bash` 3.2 so `bash -n` and the sourced-function checks for `rea-install-macos.sh` run on the real Bash 3.2.
- **D-13:** The macOS job does **not** run the macOS script's own `install --dry-run` (the runner already has Homebrew/Node, so it doesn't represent a fresh Mac). Docker is expected to be absent there; `test.sh` needs a per-OS rule (e.g. container checks only on Linux) so that skip is not a CI failure.

### Claude's Discretion
- Exact source-guard idiom (it must satisfy D-01's `curl | bash` constraint).
- Stub mechanics: which stubs log calls versus fail, and how the staging folder name maps to the archive's top-level folder.
- Whether `test.sh` itself uses `set -e` internally, as long as D-11 holds.
- How `test.sh` runs the bash 3.2 vs Linux-script checks (e.g. Linux-script functions are sourced only under bash 4+).
- Workflow file name and action versions (pin to exact tags).

### Deferred Ideas (OUT OF SCOPE)
- Fixing `usage()`'s `sed -n '2,Np' "$0"` under `curl | bash` (`$0` is `bash` there, so sed reads a nonexistent file; not verified). This is a pre-existing issue outside Phase 1; it could go in Phase 3 polish.
- Rolling back a partial install on failure (D-07 rejected for this milestone).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FAIL-01 | Failed archive extraction (Linux or Windows) stops with an error, leaves no partial tool folder, rerun extracts again | Staging `unpack` and `Expand-PinnedArchive` (Code Examples 3, 6). Both were verified red, then green, with a stub `tar` that leaves a partial folder and exits 1. Gap: Rizin and Wakaru extract outside `unpack` (Pitfall 7) |
| FAIL-02 | Failed Linux package install stops with "X is required" and writes no `pkg:X` | `|| return 1` on the 3 install lines in `pkg_install`. Verified red (records `pkg:curl `, exits 0) then green with stub `apt-get` exit 100 |
| FAIL-03 | Failed macOS `brew install` not recorded, failure reported | `|| return 1` in `brew_install`. **Real callers are already safe** (Finding 2). The red check has to call `brew_install X || ...` directly |
| DRY-01 | Linux `install --dry-run [--with-android]` exits 0 on a fresh machine with no Node | **Four changes are needed, not two** (Finding 1): `install_node` dry-run early return, `install_jdk` dry-run branch, the `/dev/tty` probe and the `rm -rf` → `run`. Verified in `ubuntu:24.04 --network none` |
| DRY-02 | Linux dry-run install/uninstall change nothing on disk | `run rm -rf` in `install_node`; `[ "$dry_run" = true ] ||` before `rmdir`. Verified with a `find ~ | sort` snapshot taken before and after |
| UNIN-01 | Broken `rea` CLI: uninstall warns, removes everything else (3 platforms) | `|| warn` in both bash scripts; `try/catch` in PS. Verified red→green on Linux (container), macOS (bash 3.2) and the PS script under pwsh 7 |
| TEST-01 | `shellcheck`, `bash -n` both scripts, PS parse | Parser one-liner verified; current scripts are clean on shellcheck 0.9.0 and 0.11.0 |
| TEST-02 | Profile-block add→remove is byte-identical | Verified with `cmp -s`. The Linux check needs GNU sed and the macOS check needs BSD sed, so each is OS-gated (Pitfall 4) |
| TEST-03 | `node_supported` table | Verified with a stub `node` that prints the version, for both scripts, on both bash versions |
| TEST-04 | Linux dry run in fresh `ubuntu:24.04` | Verified `docker run` command (Code Example 5) |
| TEST-05 | Checks fail before / pass after FAIL-01, FAIL-02, DRY-01 | Red/green matrix below, captured on this Mac (bash 3.2 + Docker) |
| TEST-06 | GitHub Actions on push and PR | Workflow skeleton (Code Example 8); runner tool inventory checked against the runner-images repo |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

From `/Users/ken/dev/rea-installer/.claude/CLAUDE.md` (project) and `/Users/ken/dev/CLAUDE.md` (global):

- `rea-install-macos.sh` must run on macOS Bash 3.2: no `mapfile`, no associative arrays. `test.sh` must also be Bash 3.2 compatible because the macOS CI job runs it under `/bin/bash` (D-12).
- `rea-install-linux.sh` may use Bash 4+. The Windows script must work on PowerShell 5.1 and 7.
- Each installer stays a single self-contained file. Do not add a shared library. `test.sh` is a separate file (D-03).
- Dry run must change nothing. Uninstall must not remove anything the script didn't add.
- All side effects go through `run` (bash) or `Invoke-Step` (PS). Ledger writes go through `record` / `Add-Record`. A direct mutation must be guarded by `[ "$dry_run" = true ] ||`.
- Do not add new `|| true` on required steps; make them fail loudly. Optional-step fallbacks must `warn`.
- Bash style: 2-space indent, `#!/bin/bash`, `set -euo pipefail`, `[[ ]]` for regex and string tests, quote every expansion, `printf` over `echo` for variable data, booleans as `true`/`false` strings tested with `[ "$x" = true ]`, function locals declared with `local`.
- PowerShell style: 4-space indent; keep `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'` and `$ProgressPreference`; fatal paths use `throw`, not `Write-Error`; use `Write-Host`, not `Write-Output`, for user text.
- shellcheck: inline disables with a reason only; no blanket disable at the top of a file.
- `usage()` slices the header with a hard-coded `sed` range, so **do not change the header line count**. Put the source guard at the bottom, in the `main` section.
- Banner sections (`environment`, `install`, `uninstall`, `main`) keep their order.
- Commit messages are short imperative sentences in sentence case with no prefix (e.g. `Add regression test script`).
- User-facing text uses sentence case and ends with a period.
- CI can only exercise Linux containers, shellcheck and PowerShell parsing. There are no real macOS or Windows installs.
- Global rule: "Silent Fallbacks: let it crash." "Chesterton's Fence" applies before removing anything.
- Ponytail guardrail is active for executors: keep `test.sh` minimal (helpers plus checks, no framework).

## Summary

The phase is small in lines changed. Most of the risk is in details the AUDIT did not catch, and running the scripts surfaced five of them.

**First**, the HARD-03 fix as written does not make DRY-01 pass. In a fresh `ubuntu:24.04` container the dry run dies at `install_node` line 294 (`curl: command not found`). Under dry run, step 1 only *prints* the curl install, so curl is never there. After that is fixed, it dies again at the `rea setup </dev/tty` redirect, because `[ -r /dev/tty ]` is true in a container that has no controlling terminal. Four edits are needed, and with them the dry run passes even with `--network none`.

**Second**, the AUDIT is wrong about macOS. `[ -n "${JAVA_HOME:-}" ] || install_jdk` does **not** turn off `set -e`: a function that is the final command of an `||` list keeps errexit (verified on 3.2.57 and 5.2.21). Every real `brew_install` call path already stops on failure today. The `|| return 1` is defence in depth, and a FAIL-03 check can only go red by calling `brew_install X || ...` directly.

**Third**, the harness itself can fall into the same trap. Wrapping a sandbox subshell in `if ( ... )` or `( ... ) || ...` turns errexit off inside it, even with an explicit `set -e`. Each check's subshell must run as a plain statement, followed by `rc=$?`.

The other two concern the guard check and the platform split. The source guard `(return 0 2>/dev/null) && return 0` works in every invocation mode. However, the "piped into bash prints usage" check suggested in D-01 cannot pass, because `usage()` reads `$0` (deferred bug). The check must use an unknown command and expect `unknown command:` instead. Also, `remove_profile_block` uses GNU `sed -i` in the Linux script and BSD `sed -i ''` in the macOS script, and uninstall uses `tac` versus `tail -r`. So the profile and uninstall checks are OS-gated. `unpack`, `pkg_install`, `brew_install` and `node_supported` are portable, so the FAIL-01 and FAIL-02 red checks run on the maintainer's Mac under bash 3.2.

**Primary recommendation:** Commit the source guard and a single `test.sh` first (a plain-statement `sandbox` helper, PATH stubs, OS-gated checks, Docker `--network none --platform linux/amd64`, a pwsh dot-source driver) and capture `01-RED.log`. Then apply the fixes: the staging `unpack`/`Expand-PinnedArchive`, `|| return 1`, four dry-run edits, three uninstall `warn`/`catch`. Last, add `.github/workflows/test.yml` with `actions/checkout@v7.0.1`.

## Key Findings (verified by execution this session)

### Finding 1: DRY-01 needs four edits; the AUDIT lists two
Original script, fresh container (`docker run --platform linux/amd64 ubuntu:24.04`, seeded `~/.rea-installer/node` and `~/.agents/skills`) [VERIFIED: docker run this session]:
```
  $ sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl
==> procps already installed (left as-is)
  $ sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip
  $ sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xz-utils
/src/rea-install-linux.sh: line 294: curl: command not found
rc=127
```
After the `install_node` and `install_jdk` dry-run fixes [VERIFIED: docker run this session]:
```
==> Running rea setup
/src/linux.sh: line 495: /dev/tty: No such device or address
rc=1
```
The code involved [VERIFIED: rea-install-linux.sh:292-297, 305-313, 485-491]:
- line 294: `  sums="$(curl -fsSL --proto '=https' "$base/SHASUMS256.txt")"`
- line 297: `  rm -rf "$STATE_DIR/node"`
- lines 312-313: `    meta="$(curl -fsSL --proto '=https' "https://api.adoptium.net/v3/assets/latest/21/hotspot?...` `|` `      node -e '...'`
- line 487: `  elif [ -r /dev/tty ]; then` / line 488: `    run "$rea_bin" setup </dev/tty`

The redirect `</dev/tty` is applied to `run` itself, so it fails even under dry run. With all four edits (Code Example 4), `install --dry-run --with-android` and `install --dry-run --with-android --with-extras --with-linux-tools` exit 0, and `uninstall --dry-run` exits 0. The `find ~ | sort` snapshot is unchanged, all under `--network none` [VERIFIED: docker run this session].

### Finding 2: errexit context map (bash 3.2.57 and 5.2.21, identical results)
[VERIFIED: /bin/bash 3.2.57 on this Mac and bash 5.2.21 in ubuntu:24.04, same script]

| Context | `set -e` inside the called function | Effect in this repo |
|---------|-------------------------------------|---------------------|
| `[ -n "" ] \|\| f` (f is the **final** command) | **ON**: f stops at its first failure | macOS `rea-install-macos.sh:191` `    [ -n "${JAVA_HOME:-}" ] \|\| install_jdk` **already stops on brew failure**. The AUDIT HARD-02 macOS claim is wrong |
| `f \|\| handler` (f on the left) | OFF | Linux `pkg_install curl \|\| die "curl is required."` (lines 352-356): **red** |
| `x="$(f)"` | OFF inside f | `unpack` (always called in `$(...)`): **red**. `fetch`'s checksum `die` inside `unpack` is also swallowed today |
| `if f; then` | OFF | `if make_venv ...` (lines 435, 451) |
| `( set -e; ... ) \|\| h` or `if ( set -e; ... )` | **OFF, even with explicit `set -e`** | **Harness trap**: a check written this way does not reproduce production behavior |
| `( ... ); rc=$?` as a plain statement | ON | The correct harness pattern |

### Finding 3: Red/green matrix from the scratch prototype
Original scripts compared with patched copies, run with the prototype harness [VERIFIED: executed this session; bash 3.2 on macOS, bash 5.2 in container, pwsh 7.6.7]:

| Check | Original | Patched | Where it can run |
|-------|----------|---------|------------------|
| FAIL-01 Linux `unpack` failure: non-zero, no `$TOOLS_DIR/foo-1.0` | FAIL (rc=0, `foo-1.0` left) | PASS | anywhere (portable) |
| FAIL-01 Linux rerun extracts again | FAIL | PASS | anywhere |
| FAIL-01 Windows `Expand-PinnedArchive` (pwsh): throws, no partial | FAIL (`partial-left=True`) | PASS | anywhere pwsh exists |
| FAIL-01 Windows rerun extracts | FAIL | PASS | anywhere pwsh exists |
| FAIL-02 `pkg_install curl \|\| die`: non-zero, "curl is required", no `pkg:curl` | FAIL (rc=0, ledger `pkg:curl `) | PASS | anywhere (portable) |
| FAIL-03 `brew_install X \|\| echo returned $?`: returns non-zero, no `brew:` record | FAIL (records `brew:rea-test-formula`) | PASS | anywhere (portable) |
| FAIL-03 via the real `[ -n "$JAVA_HOME" ] \|\| install_jdk` | PASS (already safe) | PASS | anywhere |
| DRY-01 container `install --dry-run --with-android` | FAIL (`curl: command not found`) | PASS | Docker |
| DRY-02 container `uninstall --dry-run` keeps empty `~/.agents/skills` | FAIL (deleted) | PASS | Docker |
| UNIN-01 Linux `do_uninstall` with `rea` exiting 3 | FAIL (rc=3) | PASS | Linux only (GNU sed, `tac`) |
| UNIN-01 macOS `do_uninstall` with `rea` exiting 3 | FAIL (rc=3) | PASS | macOS only (BSD sed, `tail -r`) |
| UNIN-01 Windows `Invoke-Uninstall` (pwsh) | FAIL (throws, state dir left) | PASS | anywhere pwsh exists |
| TEST-02 profile round trip (Linux script) | PASS | PASS | Linux only |
| TEST-02 profile round trip (macOS script) | PASS | PASS | macOS only |
| TEST-03 `node_supported` table, both scripts | PASS | PASS | anywhere |
| Guard: `$BASH -s -- bogus < script` prints `unknown command: bogus` | PASS* | PASS | anywhere |

\*Once the guard is added. On the maintainer's Mac with Docker running, every row the TEST-05 red log needs (FAIL-01, FAIL-02, DRY-01) shows FAIL against the original scripts.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Stop on failed extract / package install | Installer script (each of 3) | — | The failure has to be detected where the command runs; there is no shared library by design |
| Never leave a trusted partial folder | Installer `unpack` / `Expand-PinnedArchive` | — | Staging plus rename is a local filesystem invariant |
| Dry run changes nothing | Installer `run` / `Invoke-Step` wrappers | Explicit `dry_run` guards | Single choke point for side effects |
| Uninstall survives broken `rea` | Installer `do_uninstall` / `Invoke-Uninstall` | — | Ledger-driven removal must not depend on a third-party CLI |
| Loading functions without running main | Installer bottom guard | `test.sh` | One line in each bash script; `test.sh` sources it |
| Regression proof | `test.sh` (repo root) | Docker container, pwsh | One file; external runtimes are used only when present |
| Run on every push and PR | GitHub Actions workflow | `test.sh` | The workflow only invokes `test.sh`, with no logic duplicated |

## Standard Stack

No packages are installed by this phase. Everything is either already in the repo's toolchain or preinstalled on GitHub-hosted runners.

### Core
| Tool | Version (local / CI) | Purpose | Why Standard |
|------|---------------------|---------|--------------|
| Bash | 3.2.57 (`/bin/bash`, macOS local and `macos-latest`) / 5.2.21 (`ubuntu-latest`, `ubuntu:24.04` image) | `test.sh` and the scripts under test | Already the scripts' runtime [VERIFIED: `/bin/bash --version`; runner-images Ubuntu2404-Readme "Bash 5.2.21(1)-release"; macos-26-arm64-Readme "Bash 3.2.57(1)-release"] |
| ShellCheck | 0.11.0 local / 0.9.0 on `ubuntu-latest` / **absent** on `macos-latest` | TEST-01 lint | Already used per README [VERIFIED: `shellcheck --version`; runner-images Ubuntu2404-Readme lists `shellcheck 0.9.0-1`; not in macos-26-arm64-Readme] |
| PowerShell | 7.6.7 local / 7.6.6 ubuntu / 7.6.5 macOS | TEST-01 parse plus Windows function checks | Preinstalled on both runners [VERIFIED: `pwsh --version`; runner-images readmes] |
| Docker | 29.8.2 local (Desktop, context `desktop-linux`) / 28.0.4 on `ubuntu-latest` / **absent** on `macos-latest` | TEST-04 container dry run | D-04 [VERIFIED: `docker version`; Ubuntu2404-Readme "Docker Server 28.0.4"] |
| `ubuntu:24.04` image | tag | Fresh Linux machine for DRY-01 | D-04. Local cache is amd64 (`sha256:69f91949...`) |
| `actions/checkout` | `v7.0.1` (published 2026-07-20) | Workflow checkout | Latest release [VERIFIED: `gh api repos/actions/checkout/releases/latest` → `v7.0.1 2026-07-20T15:10:05Z`] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Plain-bash `test.sh` | bats-core, shellspec | Rejected by D-11 (no framework) and the ponytail guardrail |
| pwsh dot-source checks | Pester | A new dependency; dot-sourcing plus `try/catch` is enough for two checks |
| Docker `--platform linux/amd64` | native arch image | On Apple silicon a native arm64 image skips the Ghidra branch (`arch != x64`), so local and CI would test different paths. Pinning amd64 makes them the same path |
| `actions/checkout@v7.0.1` tag | full commit SHA pin | SHA pinning is stronger supply-chain hygiene, but D-12 discretion says "pin to exact tags" |

**Installation:** none. Local prerequisites are `shellcheck`, `pwsh` and a running Docker daemon. All three are present on this machine.

## Package Legitimacy Audit

No npm, PyPI or crates packages are installed or recommended by this phase. The only new external reference is the GitHub Action `actions/checkout`. It is a GitHub-owned action, verified via `gh api`, and not a registry package.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (none) | — | — | — | — | — | — |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
./test.sh  (bash 3.2-compatible, no set -e, one trap'd mktemp work dir)
   │
   ├─► static: bash -n ×2 ─► shellcheck ×3 (scripts + test.sh) ─► pwsh Parser.ParseFile
   │                                   │ tool missing? ─► need(): SKIP locally / FAIL in CI unless expected-absent on this OS
   │
   ├─► guard: "$BASH" -s -- bogus < script  ─► expect "unknown command: bogus"   (main still runs when piped)
   │          ( . script; echo loaded )     ─► expect only "loaded"               (main skipped when sourced)
   │
   ├─► sandbox SCRIPT 'code'   ──►  ( export HOME=$work/home PATH=$work/stubs:$PATH
   │      (plain statement,          . SCRIPT            # guard returns before main; set -euo pipefail now active
   │       then rc=$?)               eval "code" ) >$work/out 2>&1
   │         │
   │         ├─ portable: node_supported table · unpack fail/rerun · pkg_install fail · brew_install fail
   │         ├─ uname=Linux only : profile round trip (GNU sed) · do_uninstall + broken rea (tac)
   │         └─ uname=Darwin only: profile round trip (BSD sed) · do_uninstall + broken rea (tail -r)
   │
   ├─► docker run --rm --network none --platform linux/amd64 -v $root:/src:ro ubuntu:24.04
   │         seed ~/.rea-installer/node + ~/.agents/skills ─► snapshot find ~ ─► install --dry-run --with-android
   │         ─► grep plan ─► uninstall --dry-run ─► compare snapshot ─► exit code → PASS/FAIL
   │
   ├─► pwsh -NoProfile -File $work/w.ps1   (generated at runtime)
   │         . rea-install-windows.ps1 (no command → help, discarded) ─► override $ToolsDir/$StateDir/$Downloads
   │         ─► Expand-PinnedArchive with failing tar stub ─► rerun with real tar ─► Invoke-Uninstall with rea stub
   │         ─► prints PASS:/FAIL: lines that test.sh counts
   │
   └─► summary "N passed, N failed, N skipped" ─► exit 1 if any FAIL

.github/workflows/test.yml:  push + pull_request
   ├─ ubuntu-latest : checkout ─► ./test.sh          (everything runs; docker/shellcheck/pwsh required)
   └─ macos-latest  : checkout ─► /bin/bash ./test.sh (bash 3.2; docker + shellcheck expected absent)
```

### Recommended file layout
```
rea-install-linux.sh     # + source guard, + fixes
rea-install-macos.sh     # + source guard, + fixes
rea-install-windows.ps1  # + fixes (no guard needed: dot-sourcing with no command only prints help)
test.sh                  # new, executable (mode 100755 in git)
.github/workflows/test.yml   # new
.planning/phases/01-.../01-RED.log   # red evidence (D-05)
```

### Pattern 1: Source guard (D-01)
**What:** One line just under the `# ---- main` banner, before `cmd="${1:-}"`:
```bash
# Sourced (by test.sh): stop here so only the functions are defined. Run or piped into bash: fall through to main.
(return 0 2>/dev/null) && return 0
```
**Why this idiom:** `return` succeeds only inside a function or a sourced file. At top level of a file run as `./x`, `bash x`, `bash < x`, `cat x | bash -s -- args` or `bash <(curl ...)`, the subshell's `return` fails with status 1, so the `&&` list stops. A failing non-final command of an `&&` list does not trigger errexit. Main is left at top level, so its errexit semantics are unchanged (wrapping main in a function or in `|| main` would change them).
**Verified:** bash 3.2.57 and 5.2.21, all five invocation modes, `set -euo pipefail` and `set -u` safe; shellcheck 0.9.0 and 0.11.0 report nothing [VERIFIED: executed this session].
**Placement:** at the bottom, so the header line count used by `usage()`'s `sed -n '2,15p'` / `'2,11p'` is untouched.

### Pattern 2: Plain-statement sandbox (keeps production errexit semantics)
```bash
# Runs CODE in a subshell with SCRIPT's functions loaded, under the temp HOME and stub PATH.
# Call it as a plain statement and read $rc after: inside `if` or `||` bash turns set -e off for the whole subshell.
sandbox() {
  (
    export HOME="$work/home" PATH="$STUBS:$PATH"
    # shellcheck source=/dev/null
    . "$1"
    eval "$2"
  ) >"$work/out" 2>&1
  rc=$?
}
```
Sourcing turns on the script's `set -euo pipefail` inside the subshell, so `pkg_install curl || die ...` behaves exactly as in `do_install` [VERIFIED: red rc=0 vs green rc=1 this session]. `HOME` must be set **before** `. "$1"`, because `STATE_DIR`, `TOOLS_DIR` and `NPM_PREFIX` are computed at source time [VERIFIED: rea-install-linux.sh:17-20 `STATE_DIR="$HOME/.rea-installer"`, `STATE_FILE="$STATE_DIR/installed"`, `TOOLS_DIR="$STATE_DIR/tools"`, `NPM_PREFIX="$HOME/.local"`]. The eval-based form is shellcheck-clean (a per-call subshell triggers SC2030, SC2031, SC1090 and SC2034).

### Pattern 3: Stubs on PATH (D-02)
```bash
stub() { printf '#!/bin/sh\n%s\n' "$2" >"$STUBS/$1"; chmod +x "$STUBS/$1"; }
stub sudo 'exec "$@"'          # ALWAYS: real sudo resets PATH (secure_path) and would run the real apt-get
stub apt-get 'exit 100'
stub apt-cache 'exit 0'
# shellcheck disable=SC2016  # expanded by the stub, not here
stub dpkg-query 'case "$*" in *Status-Abbrev*) echo "ii  base-files";; *) exit 1;; esac'
```
Remove stubs that later checks must not see (`rm -f "$STUBS"/apt-get ...`), or toggle them with an env var (`STUB_TAR=fail`).

### Pattern 4: Staging extract (D-06)
See Code Examples 3 and 6. The archive is extracted into `$TOOLS_DIR/.staging-DIR`. The staging folder is moved to `$TOOLS_DIR/DIR` only on success. On failure it is removed and the run dies, keeping the verified archive so a rerun reuses it without downloading again.

### Anti-Patterns to Avoid
- **`if ( . script; f )` / `( ... ) || bad` in test.sh**: errexit is off inside, so the check tests different behavior from production. Use `sandbox` then `rc=$?`.
- **`set -e` at the top of test.sh**: the first failing check would kill the run, which violates D-11.
- **Setting a temp `HOME` globally in test.sh**: the Docker CLI reads `~/.docker` for its context (`desktop-linux` here). It only worked with a temp HOME because of the `/var/run/docker.sock` symlink. Set HOME per sandbox and per pwsh run instead.
- **Ledger entries with real formula or package names in uninstall checks** (e.g. `brew:node`): on a dev Mac, `load_brew` evals the real `brew shellenv`, which puts `/opt/homebrew/bin` before the stubs, so a real `brew uninstall` could run. Use only `npm:`, `profile:` and fake names.
- **Relying on PATH to find `npm`/`rea` in uninstall checks**: put `npm:$STUBS/npm` in the ledger. Both scripts take `npm_bin` from the ledger first, so the real `npm` and a real `rea` are never reached.
- **Changing the guard to `[ "${BASH_SOURCE[0]}" = "$0" ]`**: this breaks `curl | bash` (D-01).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PowerShell syntax check | Regex or `pwsh -c` execution | `[System.Management.Automation.Language.Parser]::ParseFile` | Parses without running; already in TESTING.md |
| Fresh-machine simulation | Unsetting PATH entries, fake `uname` | `docker run ubuntu:24.04 --network none` | Real dpkg, real absence of curl and node, proves no downloads |
| Faking failures | Redefining `run` / `pkg_install` in test.sh | Executable stubs on PATH | D-02; keeps the real `run` wrapper on the tested path |
| Byte-identical comparison | `diff` output parsing | `cmp -s` | Exit status only, exact bytes |
| Test framework | bats/shellspec/Pester | `ok`/`bad`/`skip` counters (3 one-liners) | D-11 |

## Common Pitfalls

### Pitfall 1: The suggested D-01 "pipe prints usage" check cannot pass
**What goes wrong:** `cat script | bash -s -- --help` prints `sed: RE error: illegal byte sequence` and exits 1, before and after the guard [VERIFIED: executed this session].
**Why:** `usage()` is `sed -n '2,15p' "$0"` [VERIFIED: rea-install-linux.sh:69 `usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }`]. When the script is piped, `$0` is `/bin/bash` (the binary), not `bash`. This is the deferred usage bug.
**How to avoid:** Assert `"$BASH" -s -- bogus < script` exits non-zero with `unknown command: bogus` on stderr. That message comes from main's final `case` [VERIFIED: rea-install-linux.sh:592 `  *) die "unknown command: $cmd (use install or uninstall)" ;;`]. It proves main ran without touching the deferred bug. Use `"$BASH"`, not `bash`, so the macOS job pipes into 3.2.

### Pitfall 2: Fresh container has no tty, but `[ -r /dev/tty ]` is true
**What goes wrong:** `run "$rea_bin" setup </dev/tty` fails at redirect time (`No such device or address`) even under dry run.
**How to avoid:** Change line 487 to `  elif (: </dev/tty) 2>/dev/null; then`. It is verified to choose the warn branch with no tty and the setup branch under `docker run -t`, and it is shellcheck-clean [VERIFIED: executed this session]. This also fixes a real (non-dry) Linux install over a no-tty session without `--yes`, which currently crashes at the last step. The macOS equivalent is MAC-01 in Phase 3; leave macOS alone here.

### Pitfall 3: Harness subshell in a condition disables errexit
See Finding 2. Every scenario must be `sandbox ...` on its own line, then `rc=$?`, then the assertions.

### Pitfall 4: GNU vs BSD `sed -i`, and `tac` vs `tail -r`
**What goes wrong:** On macOS, the Linux script's `remove_profile_block` runs `sed -i "/.../d" file`, which BSD sed treats as an `-i` suffix and fails. The macOS script's `sed -i '' ...` fails under GNU sed. Linux uninstall needs `tac`, which is not standard on macOS; macOS uninstall needs `tail -r`, which GNU tail lacks [VERIFIED: rea-install-linux.sh:286 `  run sed -i "/^$PROFILE_BEGIN\$/,/^$PROFILE_END\$/d" "$file"`; rea-install-macos.sh:117 `  run sed -i '' "/^$PROFILE_BEGIN\$/,/^$PROFILE_END\$/d" "$file"`; linux:560 `  done < <(tac <<<"$state")`; macos:303 `  done < <(tail -r <<<"$state")`].
**How to avoid:** Gate on `uname -s`. The Linux-script profile and uninstall checks run on Linux and the macOS-script ones on Darwin. Print `SKIP: <check> (Linux only)`. These OS-gated skips are not missing tools, so they never fail CI. Each CI job covers its half.

### Pitfall 5: Profile path depends on `$SHELL` / `$ZDOTDIR`
`profile_file` picks `.zshrc` when `basename $SHELL` is `zsh` [VERIFIED: rea-install-linux.sh:276-281]. On a Mac `SHELL=/bin/zsh`. Set `SHELL=/bin/bash` and unset `ZDOTDIR` inside the sandbox so the path is deterministic. Alternatively, pass an explicit file to `remove_profile_block`.

### Pitfall 6: Sample profile must end with a newline
A profile with no trailing newline makes the block's BEGIN marker join the user's last line (`no trailing newline# >>> rea-installer >>>`). `remove_profile_block` then never matches it [VERIFIED: executed this session with the macOS script]. This is a pre-existing bug outside Phase 1 requirements. The TEST-02 sample must end in `\n`. Flag it as a follow-up (Open Question 3).

### Pitfall 7: Rizin and Wakaru extract outside `unpack`
Lines 407-413 and 440-446 `mkdir` the final folder and then `tar` into it directly [VERIFIED: rea-install-linux.sh:410-411 `          run mkdir -p "$rizin_dir"` / `          run tar -xJf "$rizin_tar" -C "$rizin_dir"`; 443-444 the same for Wakaru]. Errexit is on there, so a failure does stop the install. However, the rerun guards are `[ ! -x "$rizin_dir/bin/rizin" ]` and `[ ! -x "$wakaru_dir/wakaru" ]`, and a partial extract can leave a truncated executable that passes them. The archive layouts were checked: Wakaru is a single root file `wakaru`, and Rizin is a root `bin/...` with no top-level folder [VERIFIED: `tar -t` on the real release assets this session]. Recommendation: route both through `unpack` with a "no top-level folder → staging becomes target" rule, and switch `tar -xzf` to `tar -xf`. GNU tar 1.35 and bsdtar auto-detect gzip and xz [VERIFIED: executed this session]. Code Example 3 handles both shapes.

### Pitfall 8: `fetch` failures inside `unpack` are swallowed
`archive="$(fetch "$1")"` inside `unpack` ignores fetch's `die` (checksum mismatch) because errexit is off in `$(...)`. Today the run continues with `archive=""` and still prints the target [VERIFIED: rea-install-linux.sh:242 `    archive="$(fetch "$1")"`; errexit behavior executed]. Add `|| exit 1`.

### Pitfall 9: `make_venv` is called inside `if`
`uv_dir="$(unpack ...)"` (lines 328/330) runs with errexit off, so add `|| return 1` after each. Without it, it still ends in the "could not be installed" warning, but by accident.

### Pitfall 10: CI never passing on skips
On `macos-latest`, shellcheck and Docker are absent (not listed in macos-26-arm64-Readme). Docker absence is expected (D-13). Treat shellcheck as expected-absent on Darwin as well, because the ubuntu job lints both scripts and lint results do not depend on host OS. Alternatively, `brew install shellcheck` in that job. `pwsh` is required on both runners. Probe Docker with `docker info >/dev/null 2>&1`, not `command -v docker`, so a stopped Docker Desktop counts as missing.
**Do not** make container checks "Linux only" as D-13's example suggests: the maintainer's Mac has Docker, and the DRY-01 red proof (D-05) must come from it. Gate on Docker availability instead.

### Pitfall 11: PS 7-only syntax passes the parse check
The parse check uses pwsh 7's parser, so `??`, ternary `?:`, pipeline-chain `&&`/`||`, and `ForEach-Object -Parallel` would parse and then break on Windows PowerShell 5.1. Keep Windows edits to `try/catch`, `Test-Path`, `Move-Item`, `Remove-Item` and `Join-Path` with two arguments (all 5.1-safe).

### Pitfall 12: `rm -rf` of an unset variable in test.sh
Use `rm -rf "${work:?}"` in the trap, and `"${work:?}"/...` anywhere else.

### Pitfall 13: test.sh executable bit
CI runs `./test.sh`, so commit it as mode 100755 (`chmod +x test.sh` before `git add`). The macOS job uses `/bin/bash ./test.sh`; the shebang `#!/bin/bash` resolves to 3.2 on macOS anyway.

## Code Examples

All of these were run in the scratch prototype this session. Values come from the repo files quoted above.

### 1. Counters and tool gating (D-10, D-11)
```bash
#!/bin/bash
# Regression checks for the three installers. Runs locally and in CI: ./test.sh
set -u
root="$(cd "$(dirname "$0")" && pwd)"
LINUX="$root/rea-install-linux.sh" MACOS="$root/rea-install-macos.sh" WIN="$root/rea-install-windows.ps1"
pass=0 fail=0 skip=0
ok()   { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }
skip() { printf 'SKIP: %s\n' "$1"; skip=$((skip + 1)); }
work="$(mktemp -d)"; trap 'rm -rf "${work:?}"' EXIT
STUBS="$work/stubs"; mkdir -p "$STUBS"

# Succeeds when TOOL is usable. Otherwise SKIPs CHECK, or FAILs it in CI unless the tool is absent on this runner by design.
need() {
  local tool="$1" check="$2" present=true
  case "$tool" in
    docker) docker info >/dev/null 2>&1 || present=false ;;
    *) command -v "$tool" >/dev/null 2>&1 || present=false ;;
  esac
  [ "$present" = true ] && return 0
  case "$(uname -s):$tool" in
    Darwin:docker|Darwin:shellcheck) skip "$check ($tool not on this runner)" ;;
    *) if [ "${CI:-}" = true ]; then bad "$check ($tool not found)"; else skip "$check ($tool not found)"; fi ;;
  esac
  return 1
}
# ... checks ...
printf '%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
```

### 2. Portable red checks (bash 3.2 and 5)
```bash
fresh_home() { rm -rf "${work:?}/home"; mkdir -p "$work/home"; }

# FAIL-01: a failed extract stops, leaves no tool folder, and a rerun extracts again.
fresh_home
mkdir -p "$work/src/foo-1.0/bin" "$work/home/.rea-installer/tools"
printf 'real\n' >"$work/src/foo-1.0/bin/tool"
tar -czf "$work/home/.rea-installer/tools/foo-1.0.tar.gz" -C "$work/src" foo-1.0   # fetch skips download when the file exists
# shellcheck disable=SC2016  # expanded by the stub
stub tar 'while [ $# -gt 0 ]; do [ "$1" = -C ] && d="$2"; shift; done; mkdir -p "$d/foo-1.0"; : >"$d/foo-1.0/partial"; exit 1'
sandbox "$LINUX" 'd="$(unpack "https://example.invalid/foo-1.0.tar.gz 00" foo-1.0)"; echo "continued with $d"'
if [ "$rc" -ne 0 ] && [ ! -e "$work/home/.rea-installer/tools/foo-1.0" ]; then ok "FAIL-01 failed unpack stops and leaves no tool folder"; else bad "FAIL-01 failed unpack stops and leaves no tool folder"; fi
rm -f "$STUBS/tar"
sandbox "$LINUX" 'd="$(unpack "https://example.invalid/foo-1.0.tar.gz 00" foo-1.0)"; [ -f "$d/bin/tool" ]'
if [ "$rc" -eq 0 ]; then ok "FAIL-01 rerun extracts again"; else bad "FAIL-01 rerun extracts again"; fi

# FAIL-02: a failed apt-get install stops with the required-tool error and is not recorded.
fresh_home
stub sudo 'exec "$@"'; stub apt-get 'exit 100'; stub apt-cache 'exit 0'
# shellcheck disable=SC2016
stub dpkg-query 'case "$*" in *Status-Abbrev*) echo "ii  base-files";; *) exit 1;; esac'
sandbox "$LINUX" 'pm=apt-get; pkg_install curl || die "curl is required."; echo continued'
if [ "$rc" -ne 0 ] && grep -q 'curl is required' "$work/out" && ! grep -q '^pkg:curl' "$work/home/.rea-installer/installed" 2>/dev/null; then ok "FAIL-02 ..."; else bad "FAIL-02 ..."; fi

# FAIL-03: brew_install returns non-zero and records nothing, whatever the caller's context.
fresh_home
stub brew 'case "$1" in list) exit 1;; install) echo "Error: no such formula" >&2; exit 1;; esac'
sandbox "$MACOS" 'brew_install rea-test-formula || echo "brew_install returned $?"'
if grep -q 'brew_install returned 1' "$work/out" && ! grep -q '^brew:' "$work/home/.rea-installer/installed" 2>/dev/null; then ok "FAIL-03 ..."; else bad "FAIL-03 ..."; fi

# TEST-03: node_supported table, both scripts.
for script in "$LINUX" "$MACOS"; do
  for row in 22.18.0:1 22.19.0:0 24.14.0:1 24.15.0:0 26.0.0:0; do
    stub node "echo ${row%%:*}"
    sandbox "$script" 'node_supported'
    if [ "$rc" = "${row#*:}" ]; then ok "node_supported ${row%%:*} ($(basename "$script"))"; else bad "node_supported ${row%%:*} ($(basename "$script"))"; fi
  done
done
rm -f "$STUBS/node"
```
`fetch` skips the download when the file already exists [VERIFIED: rea-install-linux.sh:222-223 `  path="$TOOLS_DIR/$(basename "$url")"` / `  if [ ! -f "$path" ]; then`]. That is why seeding the archive in `$TOOLS_DIR` avoids network and checksum.

### 3. Fixed Linux `unpack` (staging; handles archives with and without a top-level folder)
```bash
# Usage: unpack "url sha256" DIR -> extracts into $TOOLS_DIR/DIR (unless it exists) and prints that path.
# DIR is the archive's top-level folder, or the folder its files go into when it has none (Rizin, Wakaru).
# Extracts into a staging folder and renames it only on success, so a failed or interrupted extract never
# leaves a DIR that a rerun would trust. Always called inside $(...), where set -e is off: check each step.
unpack() {
  local target="$TOOLS_DIR/$2" staging="$TOOLS_DIR/.staging-$2" archive src
  if [ ! -d "$target" ]; then
    archive="$(fetch "$1")" || exit 1
    run rm -rf "$staging" >&2
    run mkdir -p "$staging" >&2 || die "could not create $staging."
    case "$archive" in
      *.zip) run unzip -q "$archive" -d "$staging" >&2 ;;
      *) run tar -xf "$archive" -C "$staging" >&2 ;;
    esac || { run rm -rf "$staging" >&2; die "could not unpack $(basename "$archive")."; }
    src="$staging"
    [ -d "$staging/$2" ] && src="$staging/$2"
    run mv "$src" "$target" >&2 || { run rm -rf "$staging" >&2; die "could not move $2 into place."; }
    run rm -rf "$staging" "$archive" >&2
  fi
  printf '%s\n' "$target"
}
```
Verified on bash 3.2 with bsdtar and on bash 5.2 with GNU tar 1.35: a nested `.tar.gz`, a flat `.tar.gz`, a flat `.tar.xz`, a failing tar stub (`error: could not unpack bad-1.0.tar.gz.`, rc=1, no folder or staging left, archive kept), and dry run (nothing created). Shellcheck-clean. If the planner keeps Rizin and Wakaru as they are, keep `tar -xzf` and drop the `src` fallback.

### 4. DRY-01/DRY-02 edits (Linux)
```bash
install_node() {
  local base="https://nodejs.org/dist/latest-v24.x" sums line sha file
  # A dry run cannot fetch the checksum list: step 1 only printed the curl install.
  if [ "$dry_run" = true ]; then
    log "Would download Node.js 24 from $base into $STATE_DIR/node"
    PATH="$STATE_DIR/node/bin:$PATH"
    return
  fi
  sums="$(curl -fsSL --proto '=https' "$base/SHASUMS256.txt")"
  ...
  run rm -rf "$STATE_DIR/node"
  ...
}

install_jdk() {
  ...
  if [ ! -d "$STATE_DIR/jdk" ] && [ "$dry_run" = true ]; then
    log "Would download Temurin 21 into $STATE_DIR/jdk"
  elif [ ! -d "$STATE_DIR/jdk" ]; then
    ...                                   # unchanged curl | node -e branch
  fi
  setting JAVA_HOME "$STATE_DIR/jdk"
}

  elif (: </dev/tty) 2>/dev/null; then    # was: elif [ -r /dev/tty ]; then  (line 487)

  [ "$dry_run" = true ] || rmdir "$HOME/.agents/skills" "$HOME/.agents" 2>/dev/null || true   # line 563
```
Also add `|| return 1` after both `uv_dir="$(unpack ...)"` lines in `make_venv` (Pitfall 9).

### 5. TEST-04 container check (D-04)
```bash
if need docker "DRY-01/02 Linux dry run in fresh ubuntu:24.04"; then
  # shellcheck disable=SC2016  # runs inside the container
  docker run --rm --network none --platform linux/amd64 -v "$root:/src:ro" ubuntu:24.04 bash -c '
    mkdir -p ~/.rea-installer/node ~/.agents/skills
    before="$(find ~ | sort)"
    bash /src/rea-install-linux.sh install --dry-run --with-android >/tmp/i.log 2>&1 || { tail -5 /tmp/i.log; exit 1; }
    grep -q "npm install --global" /tmp/i.log || { echo "no plan printed"; exit 1; }
    bash /src/rea-install-linux.sh uninstall --dry-run >/tmp/u.log 2>&1 || { tail -5 /tmp/u.log; exit 1; }
    [ "$(find ~ | sort)" = "$before" ] || { echo "dry run changed the home folder"; exit 1; }
  ' >"$work/out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then ok "DRY-01/02 ..."; else bad "DRY-01/02 ..."; sed 's/^/    /' "$work/out"; fi
fi
```
Original script: fails with `curl: command not found`. Patched: passes, runs in about 1 second with a cached image [VERIFIED: executed this session]. `--network none` proves the dry run downloads nothing. Consider splitting install and uninstall into two `docker run`s so the red log shows the DRY-02 uninstall failure (`~/.agents/skills` deleted) on its own line. Otherwise the install failure exits first and hides it.

### 6. Fixed Windows `Expand-PinnedArchive` and UNIN-01
```powershell
# Extracts an archive with Windows' built-in tar (handles .zip and .tar.gz) and returns $ToolsDir\$Folder.
# Extracts into a staging folder and renames it only on success, so a failed or interrupted extract never leaves a $Folder a rerun would trust.
function Expand-PinnedArchive([string]$Key, [string]$Folder) {
    $target = Join-Path $ToolsDir $Folder
    if (Test-Path $target) { return $target }
    $archive = Get-PinnedFile $Key
    $staging = Join-Path $ToolsDir ".staging-$Folder"
    if ($DryRun) { Write-Host "  > tar -xf $archive -C $staging"; return $target }
    if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
    New-Item -ItemType Directory -Force $staging | Out-Null
    try {
        Invoke-Step tar @('-xf', $archive, '-C', $staging) | Out-Null  # keep tar output out of the return value
        Move-Item (Join-Path $staging $Folder) $target
    } catch {
        Remove-Item -Recurse -Force $staging -ErrorAction SilentlyContinue
        throw "Could not unpack $(Split-Path $archive -Leaf): $_"
    }
    Remove-Item -Recurse -Force $staging
    Remove-Item -Force $archive
    return $target
}

# Invoke-Uninstall, step 1:
        try { Invoke-Step $rea @('uninstall', '--purge-data') }
        catch { Warn "rea uninstall failed; remove agent registrations by hand. ($_)" }
```
Current code for comparison [VERIFIED: rea-install-windows.ps1:137 `    Invoke-Step tar @('-xf', $archive, '-C', $ToolsDir) | Out-Null  # keep tar output out of the return value`; :236 `        Invoke-Step $rea @('uninstall', '--purge-data')`; `Invoke-Step` throws on non-zero at :55 `    if ($LASTEXITCODE -ne 0) { throw "$File $($ArgList -join ' ') failed with exit code $LASTEXITCODE" }`]. Parse errors: 0. Every construct used exists in PS 5.1.

### 7. pwsh driver (generated by test.sh into $work)
```powershell
param([string]$Script, [string]$Work)
. $Script *> $null   # no command: the script only prints its help (discarded) and defines its functions here
$ToolsDir = Join-Path $Work 'tools'; $StateDir = Join-Path $Work 'state'; $StateFile = Join-Path $StateDir 'installed'
$Downloads['fake'] = @{ Url = 'https://example.invalid/foo-1.0.tar.gz'; Sha = '00' }
$env:STUB_TAR = 'fail'
$threw = $false
try { Expand-PinnedArchive 'fake' 'foo-1.0' | Out-Null } catch { $threw = $true }
if ($threw -and -not (Test-Path (Join-Path $ToolsDir 'foo-1.0'))) { 'PASS: FAIL-01 Windows failed extract leaves no folder' } else { 'FAIL: FAIL-01 Windows failed extract leaves no folder' }
$env:STUB_TAR = 'ok'
# ... rerun → Test-Path (Join-Path $t 'bin/tool'); Invoke-Uninstall *> $null inside try with a 'env:REA_TEST_FAKE_VAR' ledger line
```
Invoke it with `PATH="$STUBS:$PATH" pwsh -NoProfile -File "$work/w.ps1" -Script "$WIN" -Work "$work/win"`. Count its `PASS:` and `FAIL:` lines in test.sh. Stubs used: a `tar` that fails when `STUB_TAR=fail` (leaving `foo-1.0/partial`) and otherwise `exec /usr/bin/tar "$@"`; a `rea` that exits 3; an `npm` that prints a nonexistent prefix for `prefix` and exits 1 otherwise. Seed `$Work/tools/foo-1.0.tar.gz` first. Do not put `winget:` lines in the test ledger: `winget` does not exist off Windows. On non-Windows .NET, `SetEnvironmentVariable(..., 'User')` did not throw [VERIFIED: executed this session; original FAIL, patched PASS for all four assertions].

### 8. Workflow (TEST-06)
```yaml
name: test
on: [push, pull_request]
permissions:
  contents: read
jobs:
  linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
      - run: ./test.sh
  macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v7.0.1
      - run: /bin/bash ./test.sh
```
GitHub sets `CI` to `true` on every run ("Always set to `true`") [CITED: docs.github.com/en/actions/reference/workflows-and-actions/variables]. `macos-latest` is macOS 26 arm64; `ubuntu-latest` is Ubuntu 24.04 x64 [VERIFIED: actions/runner-images README via gh api].

### 9. UNIN-01 bash checks (OS-gated)
```bash
# Linux only. Ledger pins the npm stub; rea lives at $HOME/.local/bin/rea (NPM_PREFIX="$HOME/.local").
stub sudo 'exec "$@"'; stub npm 'exit 1'
mkdir -p "$work/home/.local/bin" "$work/home/.agents/skills" "$work/home/.rea-installer"
printf '#!/bin/sh\nexit 3\n' >"$work/home/.local/bin/rea"; chmod +x "$work/home/.local/bin/rea"
printf 'keep me\n# >>> rea-installer >>>\nexport X=1\n# <<< rea-installer <<<\n' >"$work/home/.bashrc"
printf 'npm:%s\nprofile:%s\n' "$STUBS/npm" "$work/home/.bashrc" >"$work/home/.rea-installer/installed"
sandbox "$LINUX" 'do_uninstall'
# expect rc=0, "rea uninstall failed" in $work/out, .bashrc == "keep me", ~/.rea-installer gone

# Darwin only: same, but the npm stub answers `prefix` (rea_bin="$("$npm_bin" prefix --global)/bin/rea"):
# stub npm 'case "$1" in prefix) echo "$HOME/npm-global";; *) exit 1;; esac'  and put rea in $HOME/npm-global/bin
```
[VERIFIED: rea-install-macos.sh:254-256 `  npm_bin="$(sed -n 's/^npm://p' <<<"$state" | tail -1)"` … `  [ -n "$npm_bin" ] && rea_bin="$("$npm_bin" prefix --global)/bin/rea"`; rea-install-linux.sh:511 `  local npm_bin rea_bin="$NPM_PREFIX/bin/rea"`]

## Execution order (D-05)

1. **Commit A:** the source guard in both bash scripts, plus `test.sh`. The guard does not change behavior when the scripts are run, and the guard check passes. Run `./test.sh 2>&1 | tee .planning/phases/01-.../01-RED.log`. It must show FAIL for FAIL-01 (Linux, and Windows via pwsh), FAIL-02 and DRY-01 (Docker must be running). Commit the log in A or right after it.
2. **Commits B…:** the fixes (Linux, macOS, Windows). Rerun until green.
3. **Workflow commit** last, or with the fixes. A push runs CI on the head commit, so the red commit alone never shows as the branch status if pushed together.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `[ "${BASH_SOURCE[0]}" = "$0" ]` main guard | `(return 0 2>/dev/null)` sourced-detection | long-standing idiom | Works when piped, where `BASH_SOURCE` is empty |
| `shopt -s inherit_errexit` | Not available in bash 3.2 (added in 4.4) [ASSUMED] | — | Cannot be used for the macOS script; explicit `|| exit/return` checks are the only portable fix |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `inherit_errexit` was introduced in bash 4.4 and is unavailable on 3.2 | State of the Art | None for the plan; the recommendation does not use it |
| A2 | Treating shellcheck as expected-absent on the macOS runner satisfies D-10's "CI must never pass by skipping checks it was supposed to run", because the ubuntu job lints both scripts | Pitfall 10 | If the user wants lint on both jobs, add `brew install shellcheck` to the macOS job |
| A3 | Changing Linux's `[ -r /dev/tty ]` to an open probe is in scope for DRY-01 (it also changes non-dry, no-tty installs from crash to warning) | Pitfall 2 | Needs user OK if considered scope creep; the alternative `docker run -t` hides a real bug |
| A4 | Routing Rizin and Wakaru through `unpack` is in FAIL-01 scope (FAIL-01 says "extracting a downloaded archive", while HARD-01 names only `unpack`) | Pitfall 7 | If out of scope, keep `tar -xzf` and the strict top-level-folder `mv` |

## Open Questions

1. **FAIL-03 "reported": is brew's own stderr enough?**
   - What we know: with `|| return 1` (D-08), every real caller stops via errexit. The output shows `  $ brew install X` and brew's error, then exits 1. There is no `error:` line.
   - Recommendation: keep D-08's `|| return 1`. If an explicit line is wanted, use `run brew install "$@" || { warn "brew install $name failed."; return 1; }`. Planner's call; it does not affect the tests.
2. **Rizin and Wakaru staging (A4).** Recommended yes. It removes two inline extract blocks.
3. **Profile without a trailing newline (Pitfall 6).** This is a pre-existing uninstall correctness bug against the Core Value. Not in Phase 1 requirements. Suggest capturing it as a todo or a Phase 3 item rather than expanding this phase.
4. **Red log shape for DRY-02.** One container run hides the uninstall failure behind the install failure. Recommend two runs (install, uninstall) so each requirement gets its own FAIL line.

## Environment Availability

| Dependency | Required By | Available (local) | Version | CI ubuntu-latest | CI macos-latest | Fallback |
|------------|------------|-------------------|---------|------------------|-----------------|----------|
| /bin/bash | everything | ✓ | 3.2.57 | 5.2.21 | 3.2.57 | — |
| shellcheck | TEST-01 | ✓ | 0.11.0 | 0.9.0 | ✗ | SKIP (expected absent on Darwin) |
| pwsh | TEST-01, FAIL-01/UNIN-01 Windows | ✓ | 7.6.7 | 7.6.6 | 7.6.5 | SKIP locally; required in CI |
| docker (daemon) | TEST-04, DRY-01/02 | ✓ (Desktop running, context `desktop-linux`) | 29.8.2 | 28.0.4 | ✗ | SKIP (expected absent on Darwin) |
| ubuntu:24.04 image | TEST-04 | ✓ cached (amd64) | — | pulled on first use | — | — |
| GNU sed / tac | Linux profile + uninstall checks | ✗ (BSD sed; `tac` only via Homebrew) | — | ✓ | — | OS-gated SKIP |
| BSD sed / tail -r | macOS profile + uninstall checks | ✓ | — | ✗ | ✓ | OS-gated SKIP |

Local probes: `command -v`, `--version`, `docker version`, `docker context show` [VERIFIED: executed this session]. Runner inventories come from `actions/runner-images` `images/ubuntu/Ubuntu2404-Readme.md` (image 20261004.327.1) and `images/macos/macos-26-arm64-Readme.md` (image 20260907.0351.1) [VERIFIED: gh api].

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** Linux-only checks on the Mac (covered by the ubuntu CI job).

## Security Domain

`security_enforcement: true`, ASVS level 1. This phase handles no auth, sessions, crypto or user input beyond CLI flags. The relevant risks are destructive file operations and CI supply chain.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | minimal | Existing `die "unknown option"` parsing unchanged |
| V6 Cryptography | no change | Existing SHA-256 pin checks; Pitfall 8 makes a checksum failure inside `unpack` fatal again |
| V10/V14 Config, dependencies | yes | Workflow `permissions: contents: read`; action pinned to an exact tag |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Test deletes real user data (real `HOME`, real `~/.rea-installer`, real `brew uninstall`, real `rea uninstall --purge-data`) | Tampering | Temp `HOME` set **before** sourcing; ledger pins stub `npm`; no real formula names in test ledgers; `sudo` always stubbed |
| `rm -rf "$var"` with an empty var | Tampering | `"${work:?}"` in test.sh; installer paths are always `$TOOLS_DIR/...` |
| Partially extracted (unverified) tool trusted on rerun | Tampering | Staging plus rename (D-06) |
| Swallowed checksum mismatch | Tampering | `archive="$(fetch "$1")" \|\| exit 1` |
| Compromised action tag | Tampering | Exact tag per D-12; SHA pin is the stronger option if the user wants it |

## Sources

### Primary (HIGH confidence)
- Repository files read this session: `rea-install-linux.sh`, `rea-install-macos.sh`, `rea-install-windows.ps1`, `.planning/AUDIT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, `codebase/TESTING.md`, `01-CONTEXT.md`
- Executed experiments (scratch copies under `/private/tmp/claude-501/proto`): errexit context matrix on bash 3.2.57 and 5.2.21; source guard in five invocation modes; red/green harness; Docker dry runs with `--network none`; pwsh dot-source checks; shellcheck 0.9.0 (container) and 0.11.0 (local); GNU tar 1.35 xz auto-detect; real Wakaru and Rizin archive layouts
- `gh api repos/actions/checkout/releases/latest`, `repos/actions/runner-images` (README, Ubuntu2404 and macos-26-arm64 readmes)

### Secondary (MEDIUM confidence)
- docs.github.com Actions variables reference: `CI` "Always set to `true`"

### Tertiary (LOW confidence)
- A1 (bash version that introduced `inherit_errexit`): training knowledge, unused by the plan

## Metadata

**Confidence breakdown:**
- Fixes: HIGH. Each one was applied to a copy and run red, then green.
- Harness design: HIGH. The prototype passed under both bash versions and shellcheck.
- CI: HIGH for tool inventory (runner-images readmes). MEDIUM that the readme snapshot matches the image at execution time (images update weekly).

**Research date:** 2026-10-14
**Valid until:** 2026-11-14 (runner images and the `actions/checkout` tag move; recheck if planning slips)
