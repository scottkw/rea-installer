# Phase 1: Loud Failures, Safe Dry Run, and Regression Tests - Context

**Gathered:** 2026-10-14
**Status:** Ready for planning

<domain>
## Phase Boundary

A failed install step (archive extraction, Linux package install, macOS `brew install`) stops loudly and leaves nothing that a rerun would mistake for a finished install. Linux `install --dry-run` / `uninstall --dry-run` change nothing on disk and succeed on a fresh machine with no Node.js. Uninstall finishes on all three platforms even when the `rea` CLI is broken. A single `./test.sh` proves all of this locally and in GitHub Actions.

Requirements: FAIL-01, FAIL-02, FAIL-03, DRY-01, DRY-02, UNIN-01, TEST-01..TEST-06. Java handling (Phase 2), macOS no-tty/`--yes` Homebrew and README sync (Phase 3) are out of this phase.

The per-line fixes are already specified in `.planning/AUDIT.md` (HARD-01, 02, 03, 07, 08, 12). The decisions below refine or override them where noted.

</domain>

<decisions>
## Implementation Decisions

### Test access to script functions
- **D-01:** Add a source guard to `rea-install-linux.sh` and `rea-install-macos.sh` so `test.sh` can `source` a script and call its real functions (`node_supported`, `remove_profile_block`, `pkg_install`, `unpack`, `brew_install`) without running the bottom `main` dispatch. **Constraint:** the guard must still run main under `curl | bash`, where `BASH_SOURCE[0]` is empty and `$0` is `bash`. A naive `[ "${BASH_SOURCE[0]}" = "$0" ]` breaks the documented install path. Use a check that detects "being sourced" (e.g. `(return 0 2>/dev/null)`) rather than "being run as a file", and keep it Bash 3.2 and `set -u` safe. `test.sh` must include a check that the script still runs main when piped into bash (e.g. `bash < rea-install-linux.sh --help`-style or `cat script | bash -s -- --help` prints usage). — **Reversibility:** costly — the `curl | bash` contract is the published install path; a guard regression breaks every user install.
- **D-02:** Force failures with fake commands on `PATH`: `test.sh` writes stub `apt-get`/`dnf`/`pacman`/`unzip`/`tar`/`brew`/`rea`/`sudo` executables (exit 1 or record-and-succeed as needed) into a `mktemp -d` bin folder at the front of `PATH`, with a temporary `HOME`, then sources the script and calls the function. Do not redefine `run`; the real `run` wrapper must be on the tested path.
- **D-03:** One file: `./test.sh` in the repo root. Stubs, temp `HOME` and sample profiles are generated at runtime in `mktemp` dirs and cleaned up by a `trap`. No `tests/` directory, no tracked fixtures.
- **D-04:** TEST-04 runs via `docker run` from `test.sh`: mount the repo read-only into `ubuntu:24.04`, seed `~/.rea-installer/node/` and an empty `~/.agents/skills/`, run `install --dry-run --with-android` (no Node present) and `uninstall --dry-run`, assert exit 0 and that the seeded folders still exist. The same command works locally and in CI.
- **D-05:** TEST-05 red proof: commit `test.sh` (plus the source guard it needs) on its own **before** any FAIL/DRY fix, run it, and save the failing output to `.planning/phases/01-loud-failures-safe-dry-run-and-regression-tests/01-RED.log` in that commit or the next one. Then commit the fixes. The FAIL-01, FAIL-02 and DRY-01 checks must show FAIL in that log.

### Extraction and failure semantics
- **D-06:** Overrides the AUDIT HARD-01 fix: **extract to a staging folder, then rename**. Linux `unpack` extracts into `$TOOLS_DIR/.staging-<name>` (deleted first if left over from an earlier run), then moves the expected top-level folder to `$target` only after the extract succeeds. On error: remove staging and `die "could not unpack <archive>"`. Windows `Expand-PinnedArchive` does the same with `try`/`catch`/`Remove-Item` and rethrow. A Ctrl-C or kill leaves only a staging folder, which the next run deletes, never a `$target` that a rerun would trust. Mirrors the existing `.part` download pattern. Must honor dry run (`run` / `Invoke-Step`, no real mkdir/mv/rm under `--dry-run`).
- **D-07:** No rollback. A failure stops the install. Items already recorded stay in the ledger so `uninstall` can remove them, and a rerun continues from there.
- **D-08:** Required tools: `pkg_install X || die "X is required ..."` (existing messages). Optional tools: replace `|| true` with `|| warn "<tool> could not be installed; skipping it."` (the existing pwntools pattern). A failed package is never recorded (`pkg_install`/`brew_install` get `|| return 1` on the install command, per AUDIT HARD-02). macOS `brew_install` failures are reported the same way (FAIL-03).
- **D-09:** UNIN-01 is as AUDIT HARD-07 specifies: bash `run "$rea_bin" uninstall --purge-data || warn "rea uninstall failed; remove agent registrations by hand."`. Windows wraps it in `try { ... } catch { Warn ... }`. Uninstall then continues through the rest of the ledger.

### test.sh behavior with missing tools
- **D-10:** If `docker`, `pwsh` or `shellcheck` is missing, print `SKIP: <check> (<tool> not found)` and continue locally. When `CI=true`, a missing tool fails the run unless that tool is expected to be absent on that runner (see D-13). CI must never pass by skipping checks it was supposed to run.
- **D-11:** Output is one `PASS`/`FAIL`/`SKIP` line per check. Every check runs even after a failure, followed by a summary count. Exit 1 if any check failed. Plain bash, no test framework.

### CI
- **D-12:** `.github/workflows/` workflow on every push and pull request with two jobs: `ubuntu-latest` runs the whole of `test.sh` (shellcheck, `bash -n`, pwsh parse, function checks, docker dry run); `macos-latest` runs `test.sh` under `/bin/bash` 3.2 so `bash -n` and the sourced-function checks for `rea-install-macos.sh` run on the real Bash 3.2.
- **D-13:** The macOS job does **not** run the macOS script's own `install --dry-run` (the runner already has Homebrew/Node, so it doesn't represent a fresh Mac). Docker is expected to be absent there; `test.sh` needs a per-OS rule (e.g. container checks only on Linux) so that skip is not a CI failure.

### Claude's Discretion
- Exact source-guard idiom (it must satisfy D-01's `curl | bash` constraint).
- Stub mechanics: which stubs log calls versus fail, and how the staging folder name maps to the archive's top-level folder.
- Whether `test.sh` itself uses `set -e` internally, as long as D-11 holds.
- How `test.sh` runs the bash 3.2 vs Linux-script checks (e.g. Linux-script functions are sourced only under bash 4+).
- Workflow file name and action versions (pin to exact tags).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Findings and fixes
- `.planning/AUDIT.md` — HARD-01, HARD-02, HARD-03, HARD-07, HARD-08, HARD-12: location, scenario, fix and acceptance check for each item; the errexit root cause (bash 3.2.57 repro). D-06 overrides the HARD-01 fix.

### Scope and acceptance
- `.planning/REQUIREMENTS.md` — FAIL-01..03, DRY-01..02, UNIN-01, TEST-01..06 wording
- `.planning/ROADMAP.md` §Phase 1 — five success criteria and notes (tests red first; Bash 3.2 / PS 5.1+7 compatibility; single-file scripts)

### Codebase maps
- `.planning/codebase/TESTING.md` — current manual verification commands (pwsh parser one-liner, dry-run commands)
- `.planning/codebase/CONVENTIONS.md` — `run`/`record`/`warn`/`die` usage, dry-run rules, shellcheck inline-disable rule
- `.claude/CLAUDE.md` — project constraints and conventions (single self-contained files, Bash 3.2 for macOS, commit message style)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `run` / `record` / `warn` / `die` helpers in both bash scripts; `Invoke-Step` / `Add-Record` / `Warn` in PowerShell. All fixes go through these.
- The `.part` download-then-`mv` pattern in Linux `fetch` and Windows `Get-PinnedFile` is the model for D-06 staging.
- The pwntools `warn "... could not be installed; skipping it."` fallback is the model for D-08 optional tools.
- The pwsh parse one-liner in `.planning/codebase/TESTING.md` is ready for TEST-01.

### Established Patterns
- `unpack` (`rea-install-linux.sh:239`) is always called inside `$(...)`, so `set -e` is off there: rely on explicit `|| die`, not errexit. The same applies to any function on the left of `||`/`&&` or in `if` (`pkg_install`, `brew_install`).
- Archives extract into `$TOOLS_DIR` and the archive decides the top-level folder name (`$2` in `unpack`, `$Folder` in `Expand-PinnedArchive`); `$target` existing = "already installed" on rerun.
- macOS script's platform check (`uname` → die) lives inside `do_install` (line ~149), not at top level, so sourcing it on Linux is safe.
- Main dispatch is the bottom `cmd=... while ... case "$cmd"` block (`rea-install-linux.sh:572-593`, `rea-install-macos.sh:320-340`); D-01 wraps this.
- `usage()` slices the header with `sed -n '2,Np' "$0"`. Under `curl | bash`, `$0` is `bash`; don't make it worse, and don't fix it in this phase.

### Integration Points
- Known dry-run violations to fix: `rm -rf "$STATE_DIR/node"` in Linux `install_node` (~line 297); `rmdir ~/.agents/skills ~/.agents` in Linux `do_uninstall` (~line 563); `install_jdk` pipes JSON to `node -e` under dry run (~lines 305-313).
- `rea uninstall --purge-data`: `rea-install-linux.sh:517`, `rea-install-macos.sh:260`, Windows `Invoke-Uninstall` (~line 234).
- New files: `test.sh` (root), `.github/workflows/<name>.yml`.

</code_context>

<specifics>
## Specific Ideas

- `test.sh` must check that the source guard did not break `curl | bash` (pipe the script into bash and expect usage output).
- The red log is evidence for TEST-05; keep it in the phase folder, not the repo root.

</specifics>

<deferred>
## Deferred Ideas

- Fixing `usage()`'s `sed -n '2,Np' "$0"` under `curl | bash` (`$0` is `bash` there, so sed reads a nonexistent file; not verified). This is a pre-existing issue outside Phase 1; it could go in Phase 3 polish.
- Rolling back a partial install on failure (D-07 rejected for this milestone).

</deferred>

---

*Phase: 01-loud-failures-safe-dry-run-and-regression-tests*
*Context gathered: 2026-10-14*
