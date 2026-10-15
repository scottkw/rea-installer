# Phase 3: macOS Unattended Install and README Sync - Context

**Gathered:** 2026-10-14
**Status:** Ready for planning

<domain>
## Phase Boundary

The macOS installer completes unattended. With no terminal it warns that `rea setup` must be run by hand instead of failing (MAC-01). Under `--yes` on a Mac without Homebrew, the Homebrew installer never waits for Return (MAC-02). The README's Status, Testing and Known limitations sections accurately describe every fix in this milestone and how to run `test.sh` locally, and they still say that macOS and Windows are verified by dry run and lint only (DOCS-01).

Verification is by code analysis, dry runs and `test.sh`. No real Mac run happens this milestone (VERI-01).

</domain>

<decisions>
## Implementation Decisions

### No-terminal behavior (MAC-01)
- **D-01:** macOS step 9 copies Linux exactly. If `assume_yes` is true, run `rea setup --yes --all-detected`. Otherwise, if `(: </dev/tty) 2>/dev/null` succeeds, run `rea setup </dev/tty`. Otherwise `warn "no terminal available; run '$rea_bin setup' yourself."`, and the install finishes with exit 0 (`rea-install-linux.sh:539-546`). There is no automatic `--all-detected` fallback without `--yes`, because the script must not change agent configs the user didn't agree to.
- **D-02:** With no tty, `confirm()` answers **No** and warns, so the `[y/N]` default holds and uninstall finishes instead of dying under `set -e`. The warning names the item it left (e.g. "no terminal available; leaving Homebrew in place."). This applies to **both** bash scripts with the same body (no-shared-code rule: identical copies). `--yes` still returns yes before the tty probe.
- **D-03:** No code change for the Xcode Command Line Tools step. It still stops with "finish the Command Line Tools installer dialog". Document in Known limitations that an unattended install needs CLT installed first.

### Homebrew under --yes (MAC-02)
- **D-04:** Set `NONINTERACTIVE=1` for the Homebrew installer **only under `--yes`**. Without `--yes`, Homebrew already switches to non-interactive when stdin isn't a TTY (including under `curl | bash`). It must still go through `run` so dry run prints it. Note that `run NONINTERACTIVE=1 ...` doesn't work, because `run` execs `"$@"`. Use `env NONINTERACTIVE=1 /bin/bash -c ...` or similar.
- **D-05:** Under `--yes` with a terminal available, run `sudo -v` once (through `run`) before the Homebrew installer, so Homebrew's non-interactive `sudo -n` check finds a cached ticket. With no tty, skip `sudo -v` and let Homebrew fail.
- **D-06:** If the Homebrew install fails, stop with a sudo hint, e.g. `die "Homebrew install failed; it needs sudo. Run 'sudo -v' and rerun, or install Homebrew first."`. Don't record `homebrew` on failure. Don't rely on `set -e` alone: with Homebrew's output above it, the cause is unclear.

### README (DOCS-01)
- **D-07:** Fold each fix into the section where users look for it: behavior in "How the scripts were engineered" / "Uninstalling", tests in "Testing", accepted gaps in "Known limitations". Don't add a changelog section.
- **D-08:** Add a "Running the tests" subsection under Testing: `/bin/bash ./test.sh` on macOS (Bash 3.2), `./test.sh` in a local Linux container, what it covers (shellcheck, `bash -n`, pwsh parse, sourced-function checks, the `ubuntu:24.04` dry run), and the SKIP rule for a missing docker/pwsh/shellcheck. Update the macOS and Windows rows of the Testing table. No GitHub Actions.
- **D-09:** Status rows for macOS and Windows stay "Dry runs only" and add that `test.sh` covers them, e.g. "Dry runs and `test.sh` only: no real install has been run yet". The unverified state stays front and center.
- **D-10:** Known limitations adds all of these:
  - Linux WR-01: `unpack` fails when an archive's top folder doesn't match.
  - Linux WR-02: Rizin and Wakaru trust an existing folder.
  - Linux WR-05: a partial package install records no dependencies.
  - Windows: a user `JAVA_HOME` the script set stays stale after a Temurin upgrade while the old folder still exists.
  - macOS unattended prerequisites: CLT installed first, `--yes` without a tty needs cached sudo for Homebrew, and no tty skips `rea setup` with a warning.
  - IN-02 / backlog 999.1: macOS and Windows dry runs die on a machine with no npm.
  - Check each wording against the current code before writing it.

### Testing
- **D-11:** Add a tty-path seam so `test.sh` can reach the no-tty branches on macOS Bash 3.2 (there is no `setsid` there). The scripts read the tty path from a variable that defaults to `/dev/tty`. `test.sh` sources the script, points the variable at a missing path, and asserts the warning plus a successful return for step 9 and for `confirm()` in both scripts.
- **D-12:** Check MAC-02 from dry-run output. Source the macOS script with no `brew` on PATH, run the Homebrew step with `assume_yes=true` under `--dry-run`, and assert that the printed command carries `NONINTERACTIVE=1` and that `sudo -v` is planned when a tty is present. Without `--yes`, it must not carry `NONINTERACTIVE=1`.

### Claude's Discretion
- The seam variable's name and form. Prefer an internal variable that `test.sh` sets after sourcing over a new documented user-facing env var.
- Exact warning and die wording (sentence case, matching existing `warn` style).
- Whether the tty probe becomes a tiny helper shared within each script (step 9 + `confirm`) or stays inline.
- Exact README prose and placement within the chosen sections.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and findings
- `.planning/REQUIREMENTS.md`: MAC-01, MAC-02, DOCS-01
- `.planning/AUDIT.md` §HARD-09, §HARD-10: location, fix and acceptance check for each
- `.planning/ROADMAP.md` Phase 3: the success criteria
- `.planning/STATE.md` Decisions: the full list of milestone fixes the README must reflect
- `.planning/phases/01-loud-failures-safe-dry-run-and-regression-tests/01-REVIEW-DISPOSITION.md`: the accepted WR-01/02/05 wording source
- `.planning/phases/01-loud-failures-safe-dry-run-and-regression-tests/01-CONTEXT.md`, `.planning/phases/02-consistent-java-handling/02-CONTEXT.md`: prior decisions (test.sh conventions D-01..D-11, Java rule)

### Code
- `rea-install-macos.sh`: `confirm` (~48), Homebrew step 2 (~277-283), `rea setup` step 9 (~330-338), uninstall prompts (~378, ~408-411)
- `rea-install-linux.sh`: `confirm` (~62), `rea setup` no-tty branch (~539-546), Hopper prompt (~594)
- `test.sh`: the existing harness (source guard, stub PATH, temp HOME, PASS/FAIL/SKIP lines)
- `README.md`: Status (~25), How the scripts were engineered (~154), Testing (~185), Known limitations (~207)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Linux `(: </dev/tty) 2>/dev/null` probe plus warn branch: the pattern to copy into macOS step 9.
- `run` wrapper prints `%q`-quoted commands under dry run, so the MAC-02 check can assert on its output.
- `test.sh` source guard, stub `PATH` and temp `HOME` (Phase 1 D-01..D-03): new checks plug into the same structure.

### Established Patterns
- `run` execs `"$@"`, so env-prefix assignments need `env VAR=val cmd`.
- `confirm` short-circuits on `assume_yes`, then reads `/dev/tty`. Under `set -e` with no tty, the `read` failure kills uninstall.
- macOS script must stay Bash 3.2 safe. Both bash scripts duplicate helpers by design.

### Integration Points
- macOS `do_install` steps 2 and 9. `confirm` in both bash scripts. README sections listed above.

</code_context>

<specifics>
## Specific Ideas

- The warning text for no-tty `rea setup` should match Linux: "no terminal available; run '<rea> setup' yourself."

</specifics>

<deferred>
## Deferred Ideas

- Headless Xcode CLT install via `softwareupdate -i` under `--yes`. This is new behavior and fragile, so it's documented as a limitation instead.
- Open audit question: does REA find Ghidra on macOS without `GHIDRA_INSTALL_DIR`? Not discussed. Still open for VERI-01.
- Backlog 999.1 (IN-02, no-npm dry run) and 999.2 (Windows `JAVA_HOME` path checks) stay in the backlog. The README only documents IN-02.

</deferred>

---

*Phase: 03-macos-unattended-install-and-readme-sync*
*Context gathered: 2026-10-14*
