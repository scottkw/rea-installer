# Phase 3: macOS Unattended Install and README Sync - Research

**Researched:** 2026-10-14
**Domain:** Bash 3.2 terminal detection, Homebrew unattended install, local test harness, README accuracy
**Confidence:** HIGH (every behavior claim below was read in source or reproduced on Bash 3.2.57 and Bash 5.2.21 this session)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### No-terminal behavior (MAC-01)
- **D-01:** macOS step 9 copies Linux exactly. If `assume_yes` is true, run `rea setup --yes --all-detected`. Otherwise, if `(: </dev/tty) 2>/dev/null` succeeds, run `rea setup </dev/tty`. Otherwise `warn "no terminal available; run '$rea_bin setup' yourself."`, and the install finishes with exit 0 (`rea-install-linux.sh:539-546`). There is no automatic `--all-detected` fallback without `--yes`, because the script must not change agent configs the user didn't agree to.
- **D-02:** With no tty, `confirm()` answers **No** and warns, so the `[y/N]` default holds and uninstall finishes instead of dying under `set -e`. The warning names the item it left (e.g. "no terminal available; leaving Homebrew in place."). This applies to **both** bash scripts with the same body (no-shared-code rule: identical copies). `--yes` still returns yes before the tty probe.
- **D-03:** No code change for the Xcode Command Line Tools step. It still stops with "finish the Command Line Tools installer dialog". Document in Known limitations that an unattended install needs CLT installed first.

#### Homebrew under --yes (MAC-02)
- **D-04:** Set `NONINTERACTIVE=1` for the Homebrew installer **only under `--yes`**. Without `--yes`, Homebrew already switches to non-interactive when stdin isn't a TTY (including under `curl | bash`). It must still go through `run` so dry run prints it. Note that `run NONINTERACTIVE=1 ...` doesn't work, because `run` execs `"$@"`. Use `env NONINTERACTIVE=1 /bin/bash -c ...` or similar.
- **D-05:** Under `--yes` with a terminal available, run `sudo -v` once (through `run`) before the Homebrew installer, so Homebrew's non-interactive `sudo -n` check finds a cached ticket. With no tty, skip `sudo -v` and let Homebrew fail.
- **D-06:** If the Homebrew install fails, stop with a sudo hint, e.g. `die "Homebrew install failed; it needs sudo. Run 'sudo -v' and rerun, or install Homebrew first."`. Don't record `homebrew` on failure. Don't rely on `set -e` alone: with Homebrew's output above it, the cause is unclear.

#### README (DOCS-01)
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

#### Testing
- **D-11:** Add a tty-path seam so `test.sh` can reach the no-tty branches on macOS Bash 3.2 (there is no `setsid` there). The scripts read the tty path from a variable that defaults to `/dev/tty`. `test.sh` sources the script, points the variable at a missing path, and asserts the warning plus a successful return for step 9 and for `confirm()` in both scripts.
- **D-12:** Check MAC-02 from dry-run output. Source the macOS script with no `brew` on PATH, run the Homebrew step with `assume_yes=true` under `--dry-run`, and assert that the printed command carries `NONINTERACTIVE=1` and that `sudo -v` is planned when a tty is present. Without `--yes`, it must not carry `NONINTERACTIVE=1`.

### Claude's Discretion
- The seam variable's name and form. Prefer an internal variable that `test.sh` sets after sourcing over a new documented user-facing env var.
- Exact warning and die wording (sentence case, matching existing `warn` style).
- Whether the tty probe becomes a tiny helper shared within each script (step 9 + `confirm`) or stays inline.
- Exact README prose and placement within the chosen sections.

### Deferred Ideas (OUT OF SCOPE)
- Headless Xcode CLT install via `softwareupdate -i` under `--yes`. This is new behavior and fragile, so it's documented as a limitation instead.
- Open audit question: does REA find Ghidra on macOS without `GHIDRA_INSTALL_DIR`? Not discussed. Still open for VERI-01.
- Backlog 999.1 (IN-02, no-npm dry run) and 999.2 (Windows `JAVA_HOME` path checks) stay in the backlog. The README only documents IN-02.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MAC-01 | macOS `install` without a terminal (non-tty ssh, a script or an agent) warns to run `rea setup` manually instead of failing (HARD-09) | Reproduced: current step 9 redirect `</dev/tty` aborts the run, even under `--dry-run` (Finding 1). Prototype with `TTY_PATH` seam + `have_tty` passes on Bash 3.2 and 5.2 (Code Examples). |
| MAC-02 | macOS `install --yes` on a Mac without Homebrew installs Homebrew without waiting for Return (HARD-10) | Homebrew `install.sh` read at HEAD: `wait_for_user` runs only when `NONINTERACTIVE` is empty; with it set, sudo is checked with `-n` (Finding 3). Prototype `install_homebrew` prints `env NONINTERACTIVE=1 /bin/bash -c ...` and `sudo -v` as planned. |
| DOCS-01 | README Status, Testing and Known limitations reflect every fix in this milestone, including the test harness and how to run it locally | README audited line by line against code (README Edit Map). Three D-10 wordings need correcting against current code (Finding 6). |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- `rea-install-macos.sh` must run on Bash 3.2: no `mapfile`, no associative arrays. Empty arrays under `set -u` error on 3.2, so do not build an optional command prefix in an array.
- Each script stays a single self-contained file. Helpers are duplicated across the two bash scripts by design. A new helper (`have_tty`) goes into both with identical bodies.
- Every side effect goes through `run` (prints the command and skips it under `--dry-run`). `sudo -v` and the Homebrew installer must go through `run`.
- Errors: `die "message"` (prints `error: message`, exit 1). Warnings: `warn "message"`. Do not add new `|| true` on required steps.
- Naming: functions `snake_case` verb-first (`install_<tool>` for a new install step); script constants `UPPER_SNAKE_CASE`; runtime flags lower_snake strings `true`/`false`, tested as `[ "$x" = true ]`.
- Style: 2-space indent, `[[ ]]` for regex, `printf` for variable data, quote every expansion. Inline `# shellcheck disable=SCxxxx  # reason` only; no blanket disables.
- User-facing text: sentence case, ends with a period. Prompts use `[y/N]`, default no for destructive actions.
- `usage()` slices the header with a hard-coded range (`sed -n '2,11p'` macOS, `'2,15p'` Linux). Do not change the header comment's length.
- Adding a new install step: a dedicated `install_<tool>` function called from `do_install`, keeping the numbered `# N.` step comments.
- Testing is local only: `/bin/bash ./test.sh` on macOS and `./test.sh` in a local Linux container. No GitHub Actions (memory: local-testing-only).
- Commit messages: short imperative sentence case, no prefix (for code commits).
- GSD: edits happen inside `/gsd-execute-phase`.

## Summary

The phase is three small code changes and one documentation pass. All code paths were prototyped on a scratch copy of `rea-install-macos.sh` and checked under `/bin/bash` 3.2.57 (this Mac) and Bash 5.2.21 (`ubuntu:24.04`). `shellcheck` 0.11.0 is clean on the prototype.

Three findings change how the plan should read CONTEXT. First, the current macOS step 9 does more than "fail at the end". `run "$rea_bin" setup </dev/tty` is a plain statement under `set -e`, and the redirect fails before `run` executes. So a no-tty `install --dry-run` also exits 1, and `run` prints nothing. Second, D-02's premise that a no-tty `confirm` "kills uninstall" is not true at today's call sites. Every `confirm` call sits in an `if` / `&&` condition, where `set -e` is suspended. The `read` redirect fails, `confirm` returns 1, and uninstall goes on, but bash prints the raw error `/dev/tty: Device not configured` (macOS) and no message naming the item. D-02 is still the right change, but the regression check has to assert the warning text, not survival. Third, macOS `sudo` keeps its credential cache per terminal by default and falls back to per-parent-process with no terminal. A `--yes` run with no terminal therefore cannot reuse a ticket the user cached elsewhere. In practice it needs passwordless sudo or Homebrew already installed. D-10's wording "needs cached sudo" should say that.

The README was last edited at commit 894cf00, before any milestone code change. None of the 19 milestone fixes or the test harness appear in it. Its Linux "tested end to end" status describes container runs that ran before seven Linux-changing commits.

**Primary recommendation:** Add `TTY_PATH="/dev/tty"` (unconditional internal constant) plus `have_tty()` to both bash scripts. Route `confirm` (now taking an ITEM argument) and every tty read through them. Extract macOS step 2 into `install_homebrew` and step 9's setup branch into a small function so `test.sh` can call each directly. Test both tty branches by pointing `TTY_PATH` at a missing path (no terminal) or at a regular file holding `y` (a terminal that answers yes).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Terminal detection (`have_tty`) | Installer script helpers (both bash scripts) | test.sh (overrides `TTY_PATH`) | One choke point per script, like `run`; the test seam lives where the probe lives |
| No-tty `rea setup` skip (MAC-01) | macOS `do_install` step 9 | REA CLI (`rea setup`) | Installer decides whether setup can be interactive; REA owns registration |
| Uninstall prompts without tty (D-02) | `confirm` in both bash scripts | `do_uninstall` call sites (pass ITEM) | Default-no policy belongs in the prompt helper, not each caller |
| Unattended Homebrew (MAC-02) | macOS `install_homebrew` (new) | Homebrew `install.sh` (upstream, HEAD) | Installer chooses the mode (`NONINTERACTIVE`, `sudo -v`); Homebrew enforces sudo |
| Regression checks | `test.sh` (sourced-function sandbox) | Linux container run | Existing harness pattern; no new framework |
| User contract | `README.md` | — | Status/Testing/Known limitations are the documented promise |

## Standard Stack

No new libraries or tools. The phase uses only what the repo already uses.

| Tool | Version (verified) | Purpose |
|------|--------------------|---------|
| `/bin/bash` | 3.2.57(1)-release (macOS 27.0.1) [VERIFIED: `/bin/bash --version`] | macOS script runtime and the macOS test run |
| Bash in `ubuntu:24.04` | 5.2.21(1)-release [VERIFIED: container run] | Linux script and Linux test run |
| shellcheck | 0.11.0 [VERIFIED: `shellcheck --version`] | TEST-01 lint |
| pwsh | 7.6.7 [VERIFIED] | Windows parse plus function checks |
| docker | 29.8.2, daemon running [VERIFIED] | DRY-01/02 container checks, Linux test run |
| sudo (macOS) | 1.9.17p2 [VERIFIED: `sudo -V`] | `sudo -v` before Homebrew |
| Homebrew `install.sh` | HEAD, commit 7a3f48c (2026-10-10), 1243 lines, sha256 `5f333bbe…cb148` [VERIFIED: downloaded and read this session] | Upstream installer the script runs |

**Installation:** none.

## Package Legitimacy Audit

Not applicable. This phase installs no packages. The Homebrew installer is already fetched by the current script (`rea-install-macos.sh:280`), and this phase does not add it.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Key Findings (verified)

### Finding 1: Current macOS step 9 aborts without a terminal, including under `--dry-run`

Current code [VERIFIED: rea-install-macos.sh:333-338]:
```
  log "Running rea setup"
  if [ "$assume_yes" = true ]; then
    run "$rea_bin" setup --yes --all-detected
  else
    run "$rea_bin" setup </dev/tty
  fi
```
Reproduction on Bash 3.2 with no controlling terminal (the redirect is on the `run` call, so it fails before `run` prints or checks `dry_run`) [VERIFIED: executed]:
```
before
r.sh: line 8: /dev/tty: Device not configured
exit=1
```
`echo "after"` never ran. In the real script this leaves `npm:` recorded and REA installed but unregistered. This is Phase 1 review WR-07.

### Finding 2: `confirm` without a terminal already answers "no" at today's call sites, but with a raw bash error

Current code, identical in both scripts [VERIFIED: rea-install-macos.sh:48-53, rea-install-linux.sh:62-67]:
```
confirm() {
  [ "$assume_yes" = true ] && return 0
  local reply
  read -r -p "$1 [y/N] " reply </dev/tty
  [[ "$reply" =~ ^[Yy] ]]
}
```
Call sites, all inside conditions [VERIFIED: rea-install-macos.sh:378, 408, 411; rea-install-linux.sh:594]:
```
        if [ -e "$line" ] && confirm "Remove $line (installed by rea setup)?"; then
  if grep -qxF homebrew <<<"$state" && confirm "Remove Homebrew (installed by this script)?"; then
  if grep -qxF clt <<<"$state" && confirm "Remove Xcode Command Line Tools (installed by this script)?"; then
        if pkg_installed "$line" && confirm "Remove Hopper package $line (installed by rea setup)?"; then
```
Bash suspends `set -e` for a function called from an `if` or `&&` condition. Reproduced on Bash 3.2 with the current `confirm` [VERIFIED: executed]:
```
    /Users/ken/dev/rea-installer/rea-install-macos.sh: line 51: /dev/tty: Device not configured
    no
```
So uninstall does not die today. It silently keeps Homebrew/CLT/Hopper/apps and prints a bash error instead of a warning. D-02 still applies. The check must assert the new warning line and the absence of `Device not configured`, so that it fails before the fix and passes after. A check that only asserts "returns non-zero and continues" would already pass today.

`[ -r /dev/tty ]` is the wrong probe. In `ubuntu:24.04` with no terminal, `/dev/tty` exists (`crw-rw-rw- 1 root root 5, 0`), but opening it fails (`probe=1`) [VERIFIED: container run]. The `(: <path) 2>/dev/null` open probe is correct on both OSes. Phase 1 already moved Linux to it.

### Finding 3: Homebrew `install.sh` non-interactive and sudo behavior

All from Homebrew/install HEAD `install.sh` (commit 7a3f48c, downloaded 2026-10-14) [VERIFIED: file read]:

- **Mode selection (lines 129-147):** if `NONINTERACTIVE` is empty, it becomes 1 when `CI` is set, or when `[[ ! -t 0 ]]` (stdin not a TTY) unless `INTERACTIVE` is set. Otherwise it prints `Running in non-interactive mode because $NONINTERACTIVE is set.` So a plain `./rea-install-macos.sh install --yes` from Terminal (stdin is a TTY) runs Homebrew interactively. That is HARD-10. `curl | bash` is already non-interactive.
- **The Return prompt (lines 810-814):** `if [[ -z "${NONINTERACTIVE-}" ]]; then ring_bell; wait_for_user; fi`. `wait_for_user` reads one key and does `exit 1` on anything but Return. With `NONINTERACTIVE=1`, it is never called.
- **Sudo check (`have_sudo_access`, lines 287-337):** with `NONINTERACTIVE` set (and no `SUDO_ASKPASS`), sudo runs as `/usr/bin/sudo -n`: `"${SUDO[@]}" -l mkdir`. With no cached ticket and a password-protected sudo, this fails. Without `NONINTERACTIVE` it runs `sudo -v` (password prompt) first. If `sudo -n -v` fails at check time, it sets `trap '/usr/bin/sudo -k' EXIT`. When our `sudo -v` already cached a ticket, `sudo -n -v` succeeds, so Homebrew does not reset it.
- **Failure without sudo (lines 593-596):** `if ! [[ -d "${prefix_parent}" && -w ... ]] && ! have_sudo_access; then abort "Insufficient permissions to install Homebrew to \"${HOMEBREW_PREFIX}\"."`. `abort` exits 1, so `run` returns 1 and D-06's `|| die` fires.
- **Conflict (lines 31-34):** if both `INTERACTIVE` and `NONINTERACTIVE` are set, it aborts with "Both `$INTERACTIVE` and `$NONINTERACTIVE` are set." A user with `INTERACTIVE` exported who passes `--yes` would hit this. This is rare. Note it only as a pitfall and do not code around it.
- **Docs:** "If you want a non-interactive run of the Homebrew installer that doesn't prompt for passwords … prepend NONINTERACTIVE=1 to the installation command." [CITED: docs.brew.sh/Installation]

### Finding 4: sudo ticket scope on macOS (affects D-05 and the D-10 wording)

`man sudoers` on this Mac (sudo 1.9.17p2) [VERIFIED: man page read]: `timestamp_type` "The default value is tty". For `tty`: "One time stamp record is used for each terminal … If no terminal is present, the behavior is the same as ppid". For `ppid`: "Commands run via sudo with a different parent process ID, for example from a shell script, will be authenticated separately."

Consequences:
- **With a terminal (D-05 path):** our `run sudo -v` caches a per-terminal ticket. Homebrew's later `sudo -n` runs in the same terminal and reuses it. This holds even under `curl | bash`, because the record is keyed to the controlling terminal, not stdin [ASSUMED: sudo resolves the session's controlling tty, not fd 0; consistent with the man page but not run on a real Mac].
- **Without a terminal:** records are per parent process. Homebrew's `sudo` runs with Homebrew's bash as parent, so no ticket cached elsewhere (another Terminal window, an earlier `sudo -v`) applies. A `--yes` no-tty Homebrew install therefore succeeds only with passwordless sudo (`NOPASSWD`) or `HOMEBREW_PREFIX`'s parent already writable. Otherwise it stops with D-06's hint. **D-10's "`--yes` without a tty needs cached sudo for Homebrew" should read "needs Homebrew installed first (or passwordless sudo)".**

### Finding 5: How `run` prints the new commands (for test assertions)

`run` is `printf '  $'; printf ' %q' "$@"; printf '\n'` [VERIFIED: rea-install-macos.sh:37-40]. Prototype output, the same on Bash 3.2.57 and 5.2.21 [VERIFIED: executed both]:
```
==> Installing Homebrew
  $ sudo -v
  $ env NONINTERACTIVE=1 /bin/bash -c echo\ brew-installer
```
and without `--yes`: `  $ /bin/bash -c echo\ brew-installer`. Assert with `grep -qF 'env NONINTERACTIVE=1 /bin/bash -c'` and `grep -qx '  \$ sudo -v'`. The script body after `-c` is `%q`-escaped and changes with the stub, so never assert on it. The real Homebrew script prints as one long `$'…'` string. That is existing behavior.

### Finding 6: D-10 wording checked against current code

| D-10 item | Current code | Accurate wording |
|---|---|---|
| WR-01 "`unpack` fails when an archive's top folder doesn't match" | **Inaccurate: it does not fail.** `src="$staging"; [ -d "$staging/$2" ] && src="$staging/$2"; run mv "$src" "$target"` [VERIFIED: rea-install-linux.sh:252-254]. A mismatched top folder is moved whole, so the tool lands one folder deeper and the run continues. `install_jdk` handles this for the JDK (moves a one-level-deeper `bin/java` into place, else dies) [VERIFIED: rea-install-linux.sh:360-377]. Other callers: Node (`:324`), uv (`:393/395`), Ghidra (`:446`), Rizin (`:473`), WABT (`:482`), Wakaru (`:501`), all with pinned names. | "Linux: if a pinned download's top-level folder ever differs from the expected name, the tool is unpacked one folder deeper and its setting points at the wrong place; the install does not stop. The JDK is checked and handled." |
| WR-02 "Rizin and Wakaru trust an existing folder" | Accurate. `unpack` skips when `[ ! -d "$target" ]` is false [VERIFIED: rea-install-linux.sh:244]. Staging means a failed extract from this version no longer leaves `rizin-0.9.1/`, so the exposure is a folder left by an older script version or edited by hand. | "Linux: an existing `~/.rea-installer/tools/rizin-0.9.1` or `wakaru-1.14.0` folder is reused without checking the binary inside. If REA can't find Rizin or Wakaru, delete the folder and rerun." |
| WR-05 "a partial package install records no dependencies" (labelled Linux) | Accurate, and **macOS too**. Linux: `run sudo_cmd … install … "$name" || return 1` comes before `added=…; record` [VERIFIED: rea-install-linux.sh:170-179]. macOS: `run brew install "$@" || { warn …; return 1; }` comes before `record` [VERIFIED: rea-install-macos.sh:118-119]. | "Linux and macOS: if a package install fails partway, the dependencies it already installed aren't recorded, so uninstall leaves them." |
| Windows stale `JAVA_HOME` | Accurate, narrowed by Phase 2. A ledger-owned user value is replaced only when `$userJava\bin\java.exe` is not a file [VERIFIED: rea-install-windows.ps1:204-208]. | "Windows: if a Temurin upgrade leaves the old folder (with `java.exe`) in place, the user `JAVA_HOME` the script saved keeps pointing at it; this run and `rea setup` use the new JDK." |
| macOS unattended prerequisites | CLT: `[ "$dry_run" = true ] \|\| die "finish the Command Line Tools installer dialog, then rerun this script."` [VERIFIED: rea-install-macos.sh:274]. Sudo: see Finding 4. | "CLT must already be installed; without a terminal, Homebrew must already be installed (or sudo must need no password); without a terminal and without `--yes`, `rea setup` is skipped with a warning and uninstall prompts are answered no." |
| IN-02 no-npm dry run | Accurate, and broader on macOS. `rea_bin="$(npm prefix --global)/bin/rea"` is a plain assignment [VERIFIED: rea-install-macos.sh:325-326]; Windows `Join-Path (npm prefix --global) 'rea.cmd'` [VERIFIED: rea-install-windows.ps1:266]. On a Mac **without Homebrew** and without a supported Node, the dry run stops even earlier at step 3 `PATH="$(brew --prefix)/bin:$PATH"` [VERIFIED: rea-install-macos.sh:292; reproduced `brew: command not found`, rc=127]. | "A dry run on a Mac or Windows PC without Node.js stops at the npm step (on a Mac without Homebrew, at the Node.js step) instead of printing the whole plan." |

## README Edit Map (DOCS-01)

README has not changed since 894cf00 ("Document project status…"), which came before every milestone commit [VERIFIED: `git log -- README.md`; `git log -- rea-install-linux.sh` shows 7 Linux changes after e639540].

| Section (lines) | Current text (verbatim excerpt) | Change |
|---|---|---|
| Status (29-31) [VERIFIED: README.md:29-31] | macOS: "**Dry runs only:** lint and dry runs pass, but no real install has been run yet"; Windows: "**Dry runs only:** parsed and dry-run with a stubbed `winget`, but never run on real Windows" | D-09: "Dry runs and `test.sh` only: no real install has been run yet" (Windows: "…never run on real Windows"). **Linux row (open question):** the "Tested end to end" container runs predate this milestone's Linux changes. Since then, only the DRY-01/02 container dry runs and `test.sh` function checks have run. Recommend a short qualifier, e.g. "Tested end to end before this round of fixes; since then, dry runs and `test.sh`". |
| Options `--yes` row (130) [VERIFIED: README.md:130] | "Non-interactive. Runs `rea setup --yes --all-detected`, which registers REA with **every** agent it detects, and accepts uninstall prompts." | Add: on macOS it also installs Homebrew unattended (asks for the sudo password once first when a terminal is available). Add to line 133: without `--yes` and without a terminal, `rea setup` is skipped with a warning and uninstall prompts are answered no. |
| Uninstalling step 1 and step 5 (143, 149) | "Runs `rea uninstall --purge-data`…"; "Asks before removing Hopper, Homebrew or the Xcode Command Line Tools…" | Step 1: if `rea uninstall` fails, it warns and goes on (UNIN-01). Step 5: with no terminal it keeps them and warns. |
| How the scripts were engineered (163, 165, 174-177, 181) [VERIFIED: README.md:163] | "…a supported Node.js (including one managed by nvm), a JDK in `JAVA_HOME`, Ghidra on `PATH`…" | "a JDK 21 or newer in `JAVA_HOME`" (JAVA-02; noted in 02-RESEARCH and 02-02-SUMMARY). "Verify every download": extraction is staged, so a failed extract leaves no partial folder and a rerun extracts again (FAIL-01). "Reruns are safe": macOS keeps its own `JAVA_HOME` in the single block and never writes a user's JDK (JAVA-03/04); Linux replaces its own broken JDK. "Fail loudly": a failed required package or brew install stops and is not recorded (FAIL-02/03); dry runs change nothing (DRY-01/02). Optional: on macOS, installing Ghidra installs and records Homebrew `openjdk@21` even when a user JDK 21+ is reused (Homebrew dependency; 02-02-SUMMARY). |
| Testing table (189-191) [VERIFIED: README.md:189-190] | macOS row: "`bash -n` and `shellcheck` under the system `/bin/bash` 3.2. Dry runs of install and uninstall. Profile-block removal in a sandboxed home directory. The JADX checksum against the real download." | D-08: name `test.sh` in both rows (macOS: sourced-function checks under Bash 3.2 for profile round trip, `node_supported`, JDK selection, no-terminal prompts, unattended Homebrew plan; Windows: pwsh parse plus a dot-sourced driver for extraction, uninstall and `Install-Jdk`). |
| New "Running the tests" subsection (after line 199) | — | Commands: `/bin/bash ./test.sh` on macOS; `docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" -w /src ubuntu:24.04 bash ./test.sh` for the Linux run (the command proven in Phases 1-2). One `PASS:`/`FAIL:`/`SKIP:` line per check, exit 1 on any FAIL. SKIP rule [VERIFIED: test.sh:48-62]: a missing tool SKIPs the checks that need it (docker not running counts as missing; on a Mac, shellcheck and docker are expected-optional); with `CI=true`, a missing tool FAILs instead. Some checks are OS-specific (BSD vs GNU `sed -i`, `tail -r` vs `tac`) and SKIP on the other OS. Baselines this session: macOS 97 passed / 0 failed / 2 skipped; ubuntu container 63 / 0 / 12. |
| "Not yet run on a real machine" callout (201-205) | macOS full install; real Windows | Keep. Add "an unattended (`--yes`, no terminal) macOS install". |
| Known limitations (207-222) | — | Add the six D-10 items with the corrected wording from Finding 6. |

## Architecture Patterns

### Data flow after the change

```
install --yes (macOS)                       install (no --yes)
      │                                            │
 step 1 CLT present? ── no ──► die "finish the CLT dialog" (D-03, unchanged)
      │ yes
 step 2 load_brew? ── yes ──► continue
      │ no
 install_homebrew
   ├─ curl install.sh into a variable ── fail ──► die "could not download…"
   ├─ assume_yes? ── yes ─► have_tty? ── yes ─► run sudo -v ── fail ─► die (sudo hint)
   │                  │                 └ no ──► (skip; Homebrew's sudo -n decides)
   │                  └─► run env NONINTERACTIVE=1 /bin/bash -c "$script" ── fail ─► die (sudo hint), no record
   └─ no ──────────────► run /bin/bash -c "$script" ── fail ─► die (sudo hint), no record
   record homebrew; load_brew || die
 steps 3-8 unchanged
 step 9 assume_yes? ── yes ─► run rea setup --yes --all-detected
            │ no
         have_tty? ── yes ─► run rea setup <"$TTY_PATH"
            │ no
         warn "no terminal available; run '<rea> setup' yourself."   (exit 0)

uninstall: confirm QUESTION ITEM
   assume_yes ─► yes
   have_tty? ── no ─► warn "no terminal available; leaving ITEM in place." ; return 1
            └ yes ─► read -r -p "QUESTION [y/N] " reply <"$TTY_PATH"
```

### Pattern 1: Internal tty seam + one probe helper (both bash scripts, identical)

**What:** a script constant and a predicate next to `confirm`. `have_tty` has 3 callers on macOS (confirm, step 9, `sudo -v` gate) and 2 on Linux (confirm, step 9), which meets the "3 real examples" bar on macOS. Identical copies keep the scripts in step.

**Why unconditional assignment (not `${REA_TTY:-/dev/tty}`):** an env-overridable path would let any caller pre-answer "yes" to "Remove Homebrew?" by pointing it at a file containing `y`. An assignment at the top of the script overwrites any inherited value. `test.sh` can still override it, because it sets the variable after sourcing.

### Pattern 2: Extract steps that tests must reach

`do_install` cannot run under `test.sh` on a dev Mac: `load_brew` evaluates the real `/opt/homebrew/bin/brew shellenv`, which puts real brew before the stubs (test.sh:375 already warns "Never call load_brew or do_install here"). So:
- `install_homebrew` holds the body of step 2. `do_install` keeps the `load_brew ||` decision: `load_brew || install_homebrew`.
- Step 9's setup branch becomes a small function (name at the planner's discretion, e.g. `register_agents REA_BIN`). The Hopper before/after lines stay in `do_install`.
- Linux step 9 can stay inline. Switch its `(: </dev/tty)` and `</dev/tty` to `have_tty` / `"$TTY_PATH"` so the seam covers the whole script.

### Anti-Patterns to Avoid
- **`run NONINTERACTIVE=1 /bin/bash -c …`:** `run` execs `"$@"`, so the assignment is treated as a command name. Use `env NONINTERACTIVE=1`.
- **An optional prefix array (`pre=(); [ yes ] && pre=(env NONINTERACTIVE=1); run "${pre[@]}" …`):** on Bash 3.2 with `set -u`, an empty `"${pre[@]}"` is an unbound-variable error. Use an if/else with two `run` lines.
- **`[ -r /dev/tty ]` as the probe:** true in a no-tty container (Finding 2). Open the file instead.
- **`run … "$(curl …)"` with the curl inline (current code):** a failed download is an argument substitution, so its status is lost. `/bin/bash -c ""` exits 0, `homebrew` is **recorded**, and the run dies later with "Homebrew installed but brew was not found". A later uninstall would then offer to remove a Homebrew the script never installed. Fetch into a variable with a plain assignment and `|| die`. This is part of D-06's "don't record `homebrew` on failure".
- **Leaving `confirm`'s ITEM optional with `"$2"`:** under `set -u`, a missing `$2` is fatal even inside an `if` (expansion errors are not suspended like `set -e`). Every call site must pass it, or use `${2:-…}`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Unattended Homebrew | Answering Homebrew's prompt via `yes \|`, `expect`, or feeding stdin | `NONINTERACTIVE=1` (documented upstream) | `wait_for_user` uses `stty raw` and `read -n 1`; stdin tricks break and still prompt for sudo |
| Pre-authorising sudo | A custom `SUDO_ASKPASS` helper or storing a password | `sudo -v` once, in the user's terminal | Homebrew's `sudo -n` honors the tty ticket |
| Faking "no terminal" in tests | `setsid`, `script`, or a Python `start_new_session` wrapper | `TTY_PATH` pointed at a missing path, or at a regular file with `y` | `setsid` doesn't exist on macOS; the seam is deterministic whether or not `test.sh` itself has a terminal |
| Headless CLT install | `softwareupdate -i` parsing | Nothing (deferred, D-03) | Fragile, out of scope |

## Common Pitfalls

### Pitfall 1: A test that "passes before the fix"
**What goes wrong:** a `confirm` no-tty check that asserts only "returns non-zero and uninstall continues" passes on today's code (Finding 2).
**How to avoid:** assert `warning: no terminal available; leaving Homebrew in place.` is present **and** `Device not configured` / `No such device` is absent. For step 9, assert rc=0 plus the warning. Calling the old inline code would exit 1.

### Pitfall 2: A test that can run the real Homebrew uninstaller or install
**What goes wrong:** test.sh keeps `stub sudo 'exec "$@"'` for the rest of the run (test.sh:176, 237 "sudo and tar stay"). A `do_uninstall` check with `homebrew` or `clt` in the ledger, a non-dry run and a `confirm` regression would run `/bin/bash -c "$(curl … uninstall.sh)"` or `rm -rf /Library/Developer/CommandLineTools` on the developer's Mac.
**How to avoid:** test `confirm` directly, not through `do_uninstall` with `homebrew`/`clt` lines. Any `install_homebrew` check that is not a dry run must stub both `curl` (prints a harmless script) **and** `env` (exits 1), so neither the real installer nor the stub script runs. Remove the `env` stub right after. A `sudo -v` under the `sudo` stub becomes `exec -v` and fails, so keep `sudo -v` checks to dry runs.

### Pitfall 3: The seam's "terminal present" branch
**What goes wrong:** when `test.sh` is run from a terminal, `/dev/tty` opens; from an agent or Claude's shell it doesn't. A check that leaves `TTY_PATH` at `/dev/tty` gives different results by caller.
**How to avoid:** every new check sets `TTY_PATH` explicitly: a missing path for "no terminal", a regular file containing `y` for "terminal that answers yes". `(: <file)` succeeds and `read <file` reads `y` [VERIFIED: prototype "confirm fake tty y" → `yes` on 3.2 and 5.2].

### Pitfall 4: Dry run still fetches Homebrew's script
**What goes wrong:** `curl … install.sh` runs even under `--dry-run` (it's a read, not wrapped by `run`). That is existing behavior. Without a curl stub, a test hits the network and prints 1243 lines.
**How to avoid:** stub `curl` in every `install_homebrew` check. Use `PATH="$STUBS:/usr/bin:/bin"` as test.sh:567 does.

### Pitfall 5: `usage()` header ranges
Adding `TTY_PATH` near the constants (after line 23 macOS / 24 Linux) does not move the header. Do not edit lines 2-11 (macOS) or 2-15 (Linux).

### Pitfall 6: sudo ticket left behind
After `sudo -v` succeeds, Homebrew sees a valid ticket and does not `sudo -k` it. The ticket stays valid for that terminal for the sudoers timeout (5 minutes by default) [VERIFIED: man sudoers]. This is acceptable under `--yes`, which already means "proceed without asking". Note it in the threat model. No `sudo -k` is needed.

### Pitfall 7: `curl | bash` without `--yes`
Homebrew sees stdin is not a TTY and goes non-interactive (Finding 3). D-05 runs `sudo -v` only under `--yes`, so this case can still fail on sudo. D-06's hint ("Run 'sudo -v' and rerun") is the right recovery: a ticket cached in the same terminal is honored. No code change. Mention it in the README `--yes` text or limitations.

## Code Examples

Prototype verified on Bash 3.2.57 and 5.2.21. `shellcheck` 0.11.0 is clean, and `bash -n` is clean [VERIFIED: executed on a scratch copy]. Wording is at the planner's discretion.

```bash
# near the constants (both scripts)
TTY_PATH="/dev/tty" # test.sh points this at a missing file to reach the no-terminal branches

# next to confirm (both scripts, identical)
# Opening the terminal is the only reliable test: [ -r /dev/tty ] passes even when there is none.
have_tty() { (: <"$TTY_PATH") 2>/dev/null; }

# Usage: confirm QUESTION ITEM. Without a terminal the [y/N] default holds.
confirm() {
  [ "$assume_yes" = true ] && return 0
  if ! have_tty; then
    warn "no terminal available; leaving $2 in place."
    return 1
  fi
  local reply
  read -r -p "$1 [y/N] " reply <"$TTY_PATH"
  [[ "$reply" =~ ^[Yy] ]]
}
```

```bash
# macOS, with the other install_* helpers; do_install step 2 becomes: load_brew || install_homebrew
install_homebrew() {
  local script hint="Homebrew install failed; it needs sudo. Run 'sudo -v' and rerun, or install Homebrew first."
  log "Installing Homebrew"
  # A plain assignment, so a failed download stops here instead of running an empty script and recording homebrew.
  script="$(curl -fsSL --proto '=https' https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ||
    die "could not download the Homebrew installer."
  if [ "$assume_yes" = true ]; then
    # Homebrew checks sudo with -n when non-interactive, so cache a ticket while a terminal can still ask for it.
    if have_tty; then run sudo -v || die "$hint"; fi
    run env NONINTERACTIVE=1 /bin/bash -c "$script" || die "$hint"
  else
    run /bin/bash -c "$script" || die "$hint"
  fi
  record "homebrew"
  [ "$dry_run" = true ] || load_brew || die "Homebrew installed but brew was not found."
}
```

```bash
# macOS step 9 branch (inside a small function or inline)
  if [ "$assume_yes" = true ]; then
    run "$rea_bin" setup --yes --all-detected
  elif have_tty; then
    run "$rea_bin" setup <"$TTY_PATH"
  else
    warn "no terminal available; run '$rea_bin setup' yourself."
  fi
```

Call sites pass the item: `confirm "Remove $line (installed by rea setup)?" "$line"`, `… "Homebrew"`, `… "the Xcode Command Line Tools"`, Linux `… "Hopper package $line"`.

Prototype results [VERIFIED: executed, Bash 3.2.57]:
```
== MAC-02 --yes, tty present      rc=0   $ sudo -v / $ env NONINTERACTIVE=1 /bin/bash -c echo\ brew-installer
== MAC-02 --yes, no tty           rc=0   $ env NONINTERACTIVE=1 /bin/bash -c echo\ brew-installer
== MAC-02 no --yes                rc=0   $ /bin/bash -c echo\ brew-installer
== installer fails (real run)     rc=1   error: Homebrew install failed; it needs sudo. ... (no ~/.rea-installer created)
== curl failure                   rc=1   error: could not download the Homebrew installer.
== confirm no tty                 rc=0   warning: no terminal available; leaving Homebrew in place. / no
== confirm fake tty y             rc=0   yes
```

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `[ -r /dev/tty ]` probe | Open probe `(: </dev/tty) 2>/dev/null` | Linux moved in Phase 1; macOS moves now |
| Older Homebrew aborted with "Need sudo access on macOS" | Current HEAD aborts with "Insufficient permissions to install Homebrew to …" only when the prefix parent isn't writable and `sudo -n` fails | The die hint should not quote Homebrew's text; HEAD is mutable [VERIFIED: install.sh:593-596] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | sudo keys the `tty` timestamp to the controlling terminal, not stdin, so `sudo -v` then Homebrew's `sudo -n` works under `curl \| bash --yes` | Finding 4 | Homebrew would fail under `curl \| bash -s install --yes` with a terminal; D-06 hint still shows; confirm in VERI-01 |
| A2 | No real-Mac run: Homebrew HEAD may change its non-interactive or sudo logic before users run this | Finding 3 | `NONINTERACTIVE` is documented upstream, so low; the D-06 die still catches failures |

## Open Questions (RESOLVED)

1. **Linux "Tested end to end" status row.** It describes container runs from before 7 Linux-changing milestone commits. Recommendation: add a short qualifier (see README Edit Map). D-09 doesn't cover the Linux row, so the planner should state the choice in the plan.
   RESOLVED: add the qualifier. 03-02-PLAN "Planner decisions recorded here" (open question 1); Task 2 step 1 writes `**Tested end to end before the current round of fixes:**`.
2. **Extra accepted limitations not in D-10.** The Phase 2 dispositions also accepted: a JRE 21 `JAVA_HOME` is reused (WR-06); the Windows ledger stores only the `JAVA_HOME` name, so a value the user later repointed is removed by uninstall (WR-05); macOS installs and records `openjdk@21` with Ghidra even when a user JDK 21+ is reused. D-10 is a minimum. Recommendation: add the `openjdk@21` note under "How the scripts were engineered" (it's behavior, not a bug) and leave the others out unless the planner wants completeness.
   RESOLVED: include all of them. 03-02-PLAN "Planner decisions recorded here" (open question 2); Task 2 step 4a adds the `openjdk@21` note, Task 3 step 2 adds the `**JDK check:**` bullet (WR-06) and the WR-05/WR-104 sentences in the Windows `JAVA_HOME` bullet.
3. **macOS `GHIDRA_INSTALL_DIR`** (02-02-SUMMARY says REA does not find Homebrew's Ghidra without it). Deferred by CONTEXT and out of scope. Do not document it as fact until VERI-01.
   RESOLVED: deferred to VERI-01, not documented. 03-02-PLAN "Planner decisions recorded here" ("Deferred and not documented as fact"); Task 2 forbids mentioning it and its verify requires `grep -c 'GHIDRA_INSTALL_DIR' README.md` = 0.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `/bin/bash` 3.2 | macOS script and test run | ✓ | 3.2.57 | — |
| docker (daemon) | DRY-01/02, Linux test run | ✓ | 29.8.2 | SKIP |
| shellcheck | TEST-01 | ✓ (Mac) / ✗ (ubuntu image) | 0.11.0 | SKIP in container |
| pwsh | Windows checks | ✓ (Mac) / ✗ (ubuntu image) | 7.6.7 | SKIP in container |
| `/usr/bin/env` | `env NONINTERACTIVE=1` | ✓ | BSD env | — |
| curl | Homebrew installer fetch (stubbed in tests) | ✓ | system | — |

**Missing dependencies with no fallback:** none.

## Validation Architecture

(`workflow.nyquist_validation` is `false` in config. This section is included because the orchestrator asked for the requirement-to-check map.)

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `test.sh` (plain bash, PASS/FAIL/SKIP lines; `ok`/`bad`/`skip` at test.sh:13-15) |
| Config file | none |
| Quick run command | `/bin/bash ./test.sh 2>&1 \| grep -E '^(FAIL\|PASS: MAC-)\|passed'` |
| Full suite command | `T="$(mktemp -d)"; /bin/bash ./test.sh >"$T/mac" 2>&1; a=$?; docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" -w /src ubuntu:24.04 bash ./test.sh >"$T/linux" 2>&1; b=$?; tail -1 "$T/mac" "$T/linux"; [ "$a$b" = 00 ] && ! grep -q '^FAIL:' "$T/mac" "$T/linux"` |

### Phase Requirements → Test Map
New checks go in a section `# ---- MAC-01/02 macOS unattended install`, placed before `# ---- DRY-01/02 fresh container` (test.sh:575). They use `sandbox`, a curl stub, and `PATH="$STUBS:/usr/bin:/bin"`. None of them need `sed -i` or `tail -r`, so they run on both OSes.

| Req ID | Behavior | Check name (suggested) | Assertion |
|--------|----------|-----------------------|-----------|
| MAC-01 | macOS step 9 without a terminal warns and returns 0 | `MAC-01 macOS rea setup without a terminal warns and continues` | `TTY_PATH=$work/missing; assume_yes=false; <step-9 fn> /x/rea; echo continued` → rc 0, `no terminal available; run '/x/rea setup' yourself.`, `continued` |
| MAC-01 | macOS step 9 with a terminal plans interactive setup | `MAC-01 macOS rea setup with a terminal runs it interactively` | `TTY_PATH=<file y>; dry_run=true` → `  $ /x/rea setup` printed, no warning |
| MAC-01 / D-02 | macOS `confirm` without a terminal answers no with a named warning | `MAC-01 confirm without a terminal answers no and warns (rea-install-macos.sh)` | `if confirm "Remove Homebrew…?" Homebrew; then echo yes; else echo no; fi` → `no`, `leaving Homebrew in place.`, no `Device not configured`/`No such device` |
| D-02 | Linux `confirm` same body | `MAC-01 confirm without a terminal answers no and warns (rea-install-linux.sh)` | same, on `$LINUX` |
| D-02 | `confirm` with a terminal still reads the answer | `MAC-01 confirm with a terminal reads the answer (<script>)` | `TTY_PATH=<file y>` → `yes` |
| D-02 | `--yes` short-circuits before the probe | (fold into the row above) `assume_yes=true; TTY_PATH=missing` → `yes`, no warning |
| MAC-02 | `--yes` with a terminal plans `sudo -v` then `NONINTERACTIVE=1` | `MAC-02 macOS --yes installs Homebrew with NONINTERACTIVE=1 after sudo -v` | dry run; `sudo -v` line before the `env NONINTERACTIVE=1 /bin/bash -c` line |
| MAC-02 | `--yes` without a terminal skips `sudo -v` | `MAC-02 macOS --yes without a terminal skips sudo -v` | dry run; NONINTERACTIVE line present, no `sudo -v` |
| MAC-02 / D-04 | no `--yes` → no NONINTERACTIVE | `MAC-02 macOS Homebrew without --yes is not forced non-interactive` | dry run; `/bin/bash -c` present, `NONINTERACTIVE` absent |
| D-06 | failed Homebrew install stops with the hint and records nothing | `MAC-02 macOS failed Homebrew install stops with a sudo hint and records nothing` | real run with `env` stub `exit 1` + curl stub, `TTY_PATH` missing → rc≠0, hint text, no `continued`, no `homebrew` in ledger |
| DOCS-01 | README text | manual review in verification (grep checks: `grep -q '/bin/bash ./test.sh' README.md`, `grep -q 'Dry runs and .test.sh. only' README.md`, the six limitation keywords) | — |

The existing `TEST-01 shellcheck`/`bash -n` checks cover the edited scripts and the new test.sh section.

### Sampling Rate
- **Per task commit:** `/bin/bash ./test.sh` (about 1 minute on this Mac)
- **Phase gate:** the full suite command above, both runs 0 failed

### Wave 0 Gaps
None. The harness exists. The new checks are written red first: on today's code the step-9 function doesn't exist and `confirm` prints no warning, so the checks fail before the fix.

## Security Domain

### Applicable ASVS Categories (Level 1)

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (sudo is the OS's) | `sudo -v` in the user's own terminal; no password handling in the script |
| V3 Session Management | partly | sudo ticket scoped per terminal (default `timestamp_type=tty`), 5-minute timeout |
| V4 Access Control | yes | Destructive removals default to "no" without a terminal (D-02) |
| V5 Input Validation | yes | `TTY_PATH` not read from the environment; flags parsed by the existing `case` |
| V6 Cryptography | no | — |
| V14 Configuration | yes | `NONINTERACTIVE` scoped to the Homebrew child via `env`, not exported |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Env var pre-answers destructive prompts (e.g. a `TTY_PATH`/`REA_TTY` pointing at a file with `y`) | Elevation / Tampering | Assign `TTY_PATH` unconditionally in the script; never `${VAR:-/dev/tty}` |
| Failed download recorded as an install → later uninstall offers to remove the user's Homebrew | Tampering (ledger integrity) | Fetch into a variable with `\|\| die`; record only after a successful `run` |
| Unpinned remote script (`Homebrew/install/HEAD`) run with sudo | Tampering (supply chain) | Pre-existing, out of scope (Homebrew's official method). Note under VERI/SUPP |
| Sudo ticket reused by later steps in the same terminal | Elevation | Accepted under `--yes`; times out by default |
| Printing secrets | Information disclosure | `run` prints the Homebrew script text, never credentials; `sudo -v` prompts on the terminal itself |

## Sources

### Primary (HIGH confidence)
- `rea-install-macos.sh`, `rea-install-linux.sh`, `rea-install-windows.ps1`, `test.sh`, `README.md`: read this session with line numbers
- Homebrew/install `install.sh` at HEAD (commit 7a3f48c, 2026-10-10): downloaded and read, lines 22-34, 125-147, 287-337, 393-419, 593-600, 810-814, 912-920
- `man sudoers` (sudo 1.9.17p2, this Mac): `timestamp_type`
- Executed reproductions: Bash 3.2.57 (macOS, no controlling terminal) and Bash 5.2.21 (`ubuntu:24.04`); test.sh baselines 97/0/2 (macOS) and 63/0/12 (ubuntu)
- `.planning/AUDIT.md` HARD-09/10; `01-REVIEW.md` WR-01/02/05/07; `01-REVIEW-DISPOSITION.md`; `02-REVIEW-DISPOSITION.md`; 02-02/02-03/02-04/02-05 SUMMARY known-limitation notes

### Secondary (MEDIUM confidence)
- docs.brew.sh/Installation: `NONINTERACTIVE=1` for unattended installs

## Metadata

**Confidence breakdown:**
- Code changes (MAC-01, D-02, MAC-02): HIGH. Prototyped, linted and run on both Bash versions.
- Homebrew behavior: HIGH for the HEAD read this session; MEDIUM over time (HEAD is mutable).
- sudo-under-pipe detail (A1): MEDIUM. Man page only, no real-Mac run.
- README map: HIGH. Every edit is tied to a quoted line or verified code.

**Research date:** 2026-10-14
**Valid until:** 2026-11-13 (Homebrew HEAD can change; recheck lines 129-147 and 287-337 if planning slips)
