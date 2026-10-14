# Phase 2: Consistent Java Handling - Research

**Researched:** 2026-10-14
**Domain:** Bash 3.2 / Bash 4+ / PowerShell 5.1+7 installer logic: JDK detection, `JAVA_HOME` persistence, Homebrew `openjdk@21`, winget Temurin MSI
**Confidence:** HIGH for bash logic and the macOS/Homebrew facts; MEDIUM for the Windows parts (checked against the winget manifest and the Adoptium WiX source, but not run on real Windows)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### JDK version check (JAVA-02)
- **D-01:** "Usable" means `"$JAVA_HOME/bin/java" -version` (PowerShell: `& "$env:JAVA_HOME\bin\java.exe" -version`) runs and its first line's quoted version has major ≥ 21. Parse `"1.8.0_x"` as 8, `"17.0.2"` as 17, `"21"` / `"21.0.5"` as 21, `"25-ea"` as 25. Missing or non-executable `java`, or unparseable output, counts as unusable (fail closed). Do not use the `release` file or `/usr/libexec/java_home`.
- **D-02:** One small predicate per script (bash: `jdk_usable DIR` returning status, matching `node_supported`; PowerShell: `Test-JdkUsable([string]$Dir)` returning bool). Duplicated in each script, per the no-shared-code rule. Bash version must stay Bash 3.2 safe in the macOS script.
- **D-03:** Only `JAVA_HOME` is consulted to decide reuse. A JDK found some other way (`java` on PATH, `/usr/libexec/java_home`, Machine-scope env var) is not reused. Keeps the rule identical on all three platforms.

#### Too-old or broken JAVA_HOME (JAVA-02)
- **D-04:** If `JAVA_HOME` is set but unusable: `warn "JAVA_HOME points at <dir>, which is not JDK 21 or newer; installing the script's own JDK 21."`, install our JDK, and set this run's `JAVA_HOME` to it. The user's own JDK is never removed or modified.
- **D-05:** Persistence follows each platform's existing mechanism and is removed by `uninstall`: Linux `setting JAVA_HOME` (profile block), macOS `profile_exports` (profile block), Windows `Set-UserEnv` (which warns and leaves an existing *user* variable untouched; the session value is still set so `rea setup` sees JDK 21). — **Reversibility:** reversible — profile block and `env:` ledger entry are already removed by uninstall.

#### macOS reuse and reruns (JAVA-03, JAVA-04)
- **D-06:** macOS step 4 (Ghidra) and step 5 (Android) both go through the same reuse-or-install decision; a usable user `JAVA_HOME` writes no `JAVA_HOME` line to the profile block.
- **D-07:** On rerun, if `JAVA_HOME` already equals the script's own path (`$(brew --prefix "$JDK_FORMULA")/libexec/openjdk.jdk/Contents/Home`), re-add it to `profile_exports` even though `install_jdk` is skipped, so the rewritten block keeps it (AUDIT HARD-11 fix). Exactly one profile block after two runs.

#### Windows JAVA_HOME after Temurin (JAVA-01)
- **D-08:** After `Install-Winget $JdkId` and `Update-SessionPath`, derive the folder from the `java` now on PATH: `Split-Path (Split-Path (Get-Command java).Source)`, check it with `Test-JdkUsable`, then `Set-UserEnv 'JAVA_HOME' <dir>`. Works whether or not the MSI set a Machine `JAVA_HOME`; drop the current `throw "Temurin installed but JAVA_HOME was not set."` path. If the derived folder is not JDK 21+, throw with that folder in the message.
- **D-09:** `-DryRun` keeps a placeholder (`<Temurin JAVA_HOME>`) for the session value and records nothing, as today.

#### Testing
- **D-10:** Extend `test.sh` (no new files): stub `$JAVA_HOME/bin/java` scripts printing version strings to table-test the bash predicate in both scripts (8, 17, 21, 21.0.5, 25-ea, missing, garbage); a macOS check that two sourced profile-block writes with our `JAVA_HOME` leave one block containing `JAVA_HOME`; Windows predicate/derivation covered by the existing pwsh parse plus a pwsh driver check if cheap. Real-Windows confirmation stays deferred to VERI-02.

### Claude's Discretion
- Exact function names and warning wording (sentence case, period, matches existing `warn` style).
- Whether Linux `install_jdk` also tolerates an Adoptium archive whose top folder differs from `release_name` (accepted limitation WR-01); fix only if it falls out naturally from touching `install_jdk`.

### Deferred Ideas (OUT OF SCOPE)
- Real-Windows confirmation of JAVA-01 — VERI-02 (v2).
- Reusing a JDK 21+ discovered without `JAVA_HOME` (`/usr/libexec/java_home -v 21`, `java` on PATH) — possible later polish; out of scope for the one-rule fix.
- Setting `GHIDRA_INSTALL_DIR` on macOS — only if research shows REA needs it; would be its own follow-up.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| JAVA-01 | On Windows, after Temurin is installed, `JAVA_HOME` points at Temurin 21 for the session and is saved as a user variable that uninstall removes, whether or not the MSI set it (HARD-04) | Pattern 3, Pitfalls 4-7, Code Example 3. The winget manifest passes `ADDLOCAL=ALL`, so the MSI *does* set Machine `JAVA_HOME` and prepends `bin` to Machine PATH; deriving from PATH works either way. `Set-UserEnv` returns early without setting the session value, so `Install-Jdk` must set `$env:JAVA_HOME` itself. |
| JAVA-02 | On every platform, an existing `JAVA_HOME` is reused only if it is JDK 21 or newer; otherwise the script installs its own JDK (HARD-05, HARD-06) | Pattern 1 (predicate), Code Examples 1 and 3 (tested this session against stub and real JDK output), Pitfalls 1-3 |
| JAVA-03 | On macOS, a user's existing JDK ≥21 `JAVA_HOME` is never overwritten in the shell profile (HARD-05) | Pattern 2: `install_jdk` stops appending to `profile_exports`; step 7 appends `JAVA_HOME` only when it equals our `openjdk@21` path. Pitfall 8: Homebrew's `ghidra` formula depends on `openjdk@21`. |
| JAVA-04 | On macOS, rerunning `install` (with `--with-extras` or `--with-android`) keeps `JAVA_HOME` in the single profile block when it points at the script's own JDK (HARD-11) | Pattern 2: the same step-7 equality check covers reruns. Testing it needs step 7 pulled out into a function (Pitfall 9). |
</phase_requirements>

## Summary

All three scripts get the same small predicate: run `DIR/bin/java -version`, capture stderr, find the first `version "N…"` token, map `1.x` to `x`, and accept major ≥ 21. I tested the bash version under `/bin/bash` 3.2.57 against stub JDKs and a real Homebrew JDK 17. It works without `mapfile`, `grep -m`, or pipes that could hit SIGPIPE under `pipefail`. I also tested the PowerShell version under pwsh 7.6.7 with stub `java.exe` scripts. Two output details matter. Real `java -version` output goes **only to stderr**, and a `Picked up JAVA_TOOL_OPTIONS:` / `NOTE: Picked up JDK_JAVA_OPTIONS:` line can come **before** the version line (both observed here). So the parser must search all of the output, not just the first line. Recent builds also print four-part versions such as `"17.0.20.1"`.

On each platform the change is about where the decision lives, not how big it is. **Linux** already survives reruns (it unsets settings that point into `$STATE_DIR`, then rewrites them). It only needs the predicate plus a guard so a second `install_jdk` call in the same run (Ghidra, then Android) doesn't warn or add a duplicate profile line during `--dry-run`. **macOS** should stop writing `JAVA_HOME` inside `install_jdk`. Instead, step 7 adds `export JAVA_HOME=…` once, and only when `JAVA_HOME` equals `$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home`. That one check covers JAVA-03 (a user JDK is never written), JAVA-04 (reruns keep ours) and deduplication. **Windows** derives the folder from `Get-Command java` after `Update-SessionPath`. It must set `$env:JAVA_HOME` directly, because `Set-UserEnv` returns *before* `Set-Item env:` whenever a different user value exists. It must also run `java -version` with a function-local `$ErrorActionPreference = 'Continue'`, because Windows PowerShell 5.1 turns redirected native stderr into ErrorRecords, and with `Stop` the first one is a terminating error.

The research turned up five facts the planner needs:
1. The winget manifest for `EclipseAdoptium.Temurin.21.JDK` passes `Custom: ADDLOCAL=ALL`. The MSI therefore *does* set Machine `JAVA_HOME` and prepends `[INSTALLDIR]bin` to Machine PATH (`Part="first"`). HARD-04's premise is correct about the MSI's default (`FeatureJavaHome Level="2"`, off) but wrong for winget. D-08 still works and is still the right fix.
2. Homebrew `ghidra` is a **formula** (not a cask) that `depends_on "openjdk@21"`. On macOS, `brew install ghidra` installs `openjdk@21` even when the user's JDK is reused (Pitfall 8).
3. REA does **not** find Homebrew's Ghidra without `GHIDRA_INSTALL_DIR`. Its PATH discovery takes `dirname(realpath(ghidraRun))` and needs `Ghidra/application.properties` and `support/analyzeHeadless` in that folder. Homebrew's `bin/ghidraRun` is a wrapper script in `Cellar/ghidra/<v>/bin/`, and the Ghidra tree is in `libexec/`. Per CONTEXT this goes in as a follow-up, not into this phase.
4. A full `do_install` sandbox test on a dev Mac is dangerous: `load_brew` puts the real `/opt/homebrew/bin` ahead of the stubs. The JAVA-04 test must call an extracted step-7 function directly.
5. On Unix pwsh, `Update-SessionPath` sets `PATH` to `;`, because Machine and User scopes read as empty. The pwsh driver must redefine it as a no-op before calling `Install-Jdk`.

**Primary recommendation:** Add `jdk_usable` / `Test-JdkUsable` exactly as in Code Examples 1 and 3. On macOS, move the `JAVA_HOME` profile line out of `install_jdk` into one equality-checked append inside a new `write_profile` function (step 7). On Windows, set `$env:JAVA_HOME` before calling `Set-UserEnv`. Guard every second-call and dry-run path so no warning repeats and no line is duplicated.

## Architectural Responsibility Map

This project has no web tiers. The relevant "tiers" are the parts of each installer script.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Decide whether `JAVA_HOME` is usable | Environment-detection helpers (`jdk_usable` / `Test-JdkUsable`, next to `node_supported` / `Test-NodeSupported`) | — | A pure predicate, like the Node gate; returns status/bool, prints nothing |
| Install the script's own JDK | Install phase (`install_jdk` / `Install-Jdk`) | Download/package layer (`unpack`, `brew_install`, `Install-Winget`) | Uses the existing pinned-download / package wrappers so dry run and the ledger keep working |
| Session `JAVA_HOME` for `rea setup` | Install phase (`export JAVA_HOME` / `$env:JAVA_HOME`) | — | `rea setup` copies valid detected JDK settings into agent registrations |
| Persist `JAVA_HOME` | Linux `setting` → `profile_lines`; macOS step 7 → `profile_exports`; Windows `Set-UserEnv` → `env:JAVA_HOME` ledger entry | Uninstall phase removes the profile block / `env:` entry | Reuses existing mechanisms, so no new ledger kind is needed |
| Regression checks | `test.sh` (sourced functions, PATH stubs, pwsh driver) | GitHub Actions `linux` + `macos` jobs | Same harness as Phase 1 |

## Project Constraints (from CLAUDE.md)

- `rea-install-macos.sh` must run on **Bash 3.2**: no `mapfile`, no associative arrays. `rea-install-linux.sh` may use Bash 4+. The Windows script must run on **PowerShell 5.1 and 7**.
- Each script stays a **single self-contained file**, with no shared helper module. The predicate is copied into all three.
- **Dry run must change nothing. Uninstall must remove only what the script added.**
- CI exercises only Linux containers, shellcheck, and PowerShell parsing/driver checks. There are no real macOS/Windows installs.
- Side effects go through `run` / `Invoke-Step`. Ledger writes go through `record` / `Add-Record`. Session env changes (`export`, `$env:`) are not side effects on disk, so they are fine outside the wrappers.
- Bash style: 2-space indent, `set -euo pipefail`, `[[ ]]` for regex, `local` for every function variable, `printf` (not `echo`) for variable data, predicates return status and print nothing, `snake_case` verb-first names, `warn` messages in sentence case ending with a period. Never add a blanket `shellcheck disable`; annotate inline with a reason.
- PowerShell style: 4-space indent, `Verb-Noun` names (`Test-JdkUsable`), typed params `function X([string]$Dir)`, `throw` for fatal paths (not `Write-Error`), `Warn` for warnings, `Write-Host` for output, keep `Set-StrictMode -Version Latest` / `$ErrorActionPreference = 'Stop'`.
- Don't add `|| true` on steps the install needs in order to be correct; fail loudly instead.
- `usage()` slices the header with `sed -n '2,11p'` (macOS) / `'2,15p'` (Linux). Don't change the header line count.
- Commit messages: short imperative sentence case, no prefix.
- GSD workflow enforcement: edits only through GSD commands. Ponytail curbs over-building in the executor: keep the diff minimal.

## Standard Stack

This phase adds no libraries or packages. It uses only tools the scripts already depend on.

### Core
| Tool | Version (observed) | Purpose | Why |
|------|--------------------|---------|-----|
| `/bin/bash` (macOS) | 3.2.57 [VERIFIED: `/bin/bash --version` this session] | Runs `rea-install-macos.sh` and the CI `macos` job (`/bin/bash ./test.sh`) | Lowest common shell; the predicate must parse here |
| Homebrew `openjdk@21` | 21.0.12.1, keg-only (`versioned_formula`) [VERIFIED: `brew info --json=v2 openjdk@21`] | macOS JDK | Already the script's `JDK_FORMULA` |
| Homebrew `ghidra` | 12.1.4, **formula** in `homebrew/core`, `depends_on "openjdk@21"` [VERIFIED: `brew info --json=v2 ghidra` + formula source] | macOS Ghidra | Already used by `brew_install ghidra` |
| winget `EclipseAdoptium.Temurin.21.JDK` | 21.0.12.101 manifest, `InstallerType: wix`, `Scope: machine`, `Custom: ADDLOCAL=ALL`, x64-only installer [VERIFIED: microsoft/winget-pkgs manifest via `gh api`] | Windows JDK | Already the script's `$JdkId` |
| Adoptium API v3 | `https://api.adoptium.net/v3/assets/latest/21/hotspot?...` (unchanged) | Linux JDK download | Already used by Linux `install_jdk` |
| `pwsh` | 7.6.7 [VERIFIED: `pwsh --version`] | Local / CI parse and driver checks | Already used by `test.sh` |
| `shellcheck` | present at `/opt/homebrew/bin/shellcheck` [VERIFIED] | Lint | TEST-01 |

**Installation:** none.

## Package Legitimacy Audit

No external packages are installed by this phase, so no legitimacy check was needed.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (none) | — | — | — | — | — | — |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
                      install (Ghidra step / Android step)
                                   |
                                   v
                 +-----------------------------------+
                 | JAVA_HOME already ours this run?  |--yes--> (Linux/Win: return; macOS: brew_install ours, export)
                 +-----------------------------------+
                                   | no
                                   v
                 +-----------------------------------+
                 | jdk_usable "$JAVA_HOME" ?         |--yes--> log "Using JDK at …"  (no install, no persist)
                 |  run DIR/bin/java -version 2>&1   |
                 |  regex: version "N(.M)?  1.x->x   |
                 |  major >= 21                      |
                 +-----------------------------------+
                                   | no
                                   v
             JAVA_HOME non-empty? --yes--> warn "JAVA_HOME points at …, which is not JDK 21 or newer; …"
                                   |
                                   v
     +-------------------+-------------------------+-------------------------------------------+
     | Linux             | macOS                   | Windows                                   |
     | unpack Adoptium → | brew_install openjdk@21 | Install-Winget Temurin → Update-SessionPath|
     | $STATE_DIR/jdk    | (records brew:…)        | dir = Split-Path×2 (Get-Command java)     |
     | setting JAVA_HOME | export JAVA_HOME=ours   | Test-JdkUsable dir || throw "…$dir…"      |
     | (export+profile)  |                         | $env:JAVA_HOME=dir; Set-UserEnv JAVA_HOME  |
     +-------------------+-------------------------+-------------------------------------------+
                                   |
                                   v
   macOS step 7 (write_profile): if JAVA_HOME == $(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home
                                   then profile_exports += export JAVA_HOME   (once; covers first run AND reruns)
                                   |
                                   v
                       rea setup (copies JAVA_HOME into agent registrations)
```

### Current code (verbatim, read this session)

Linux `install_jdk` [VERIFIED: rea-install-linux.sh:318-336]:
```bash
# Temurin 21 JDK from Adoptium into ~/.rea-installer/jdk, verified against the checksum Adoptium publishes.
install_jdk() {
  if [ -n "${JAVA_HOME:-}" ]; then
    log "Using JDK at $JAVA_HOME"
    return
  fi
  if [ ! -d "$STATE_DIR/jdk" ] && [ "$dry_run" = true ]; then
    log "Would download Temurin 21 into $STATE_DIR/jdk"
  elif [ ! -d "$STATE_DIR/jdk" ]; then
    ...
  fi
  setting JAVA_HOME "$STATE_DIR/jdk"
}
```
The Linux rerun reset [VERIFIED: rea-install-linux.sh:361-365]:
```bash
  # Settings that point into $STATE_DIR came from our own profile block; drop them so this run rewrites it whole.
  local v
  for v in $(compgen -e); do
    [ "$v" != PATH ] && [[ "${!v}" == "$STATE_DIR"/* ]] && unset "$v"
  done
```
Linux `setting` [VERIFIED: rea-install-linux.sh:71-75]: `setting() { export "$1=$2"; profile_lines+=("export $1=\"$2\""); }` (multi-line in the file). Linux callers: `install_jdk` at line 395 (Ghidra step) and line 404 (Android step). The Apktool launcher at line 412 embeds `${JAVA_HOME:-%s}` with the current `$JAVA_HOME`.

macOS `install_jdk` [VERIFIED: rea-install-macos.sh:123-129]:
```bash
install_jdk() {
  brew_install "$JDK_FORMULA"
  # REA validates the JDK via JAVA_HOME; setup copies it into agent registrations.
  export JAVA_HOME
  JAVA_HOME="$(brew --prefix "$JDK_FORMULA")/libexec/openjdk.jdk/Contents/Home"
  profile_exports+=("export JAVA_HOME=\"$JAVA_HOME\"")
}
```
`JDK_FORMULA="openjdk@21"` [VERIFIED: rea-install-macos.sh:17]. Callers [VERIFIED: rea-install-macos.sh:181-196]: step 4 runs `install_jdk` only in the `else` branch of `if command -v ghidraRun >/dev/null 2>&1 || [ -n "${GHIDRA_INSTALL_DIR:-}" ]; then`; step 5 runs `[ -n "${JAVA_HOME:-}" ] || install_jdk`. Step 7 [VERIFIED: rea-install-macos.sh:207-219] is inline in `do_install`: `if ((${#profile_exports[@]} > 0)); then … remove_profile_block "$profile" … printf '%s\n' "$PROFILE_BEGIN" "${profile_exports[@]}" "$PROFILE_END" >>"$profile"; record "profile:$profile"; fi`.

Windows `Install-Jdk` [VERIFIED: rea-install-windows.ps1:160-167]:
```powershell
function Install-Jdk {
    if ($env:JAVA_HOME) { Log "Using JDK at $env:JAVA_HOME"; return }
    Install-Winget $JdkId
    # Temurin's installer sets a machine-wide JAVA_HOME; load it into this session for rea setup.
    $env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    if ($DryRun -and -not $env:JAVA_HOME) { $env:JAVA_HOME = '<Temurin JAVA_HOME>' }
    if (-not $env:JAVA_HOME) { throw "Temurin installed but JAVA_HOME was not set." }
}
```
`$JdkId = 'EclipseAdoptium.Temurin.21.JDK'` [VERIFIED: rea-install-windows.ps1:34]. `Set-UserEnv` [VERIFIED: rea-install-windows.ps1:100-112]:
```powershell
function Set-UserEnv([string]$Name, [string]$Value) {
    $existing = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ($existing -eq $Value) { return }
    if ($existing) {
        Warn "$Name is already set for your user to $existing; leaving it as-is."
        return
    }
    Write-Host "  > setx $Name `"$Value`""
    Set-Item "env:$Name" $Value
    if ($DryRun) { return }
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    Add-Record "env:$Name"
}
```
`Install-Winget` [VERIFIED: rea-install-windows.ps1:88-97] calls `Update-SessionPath` **only** after an actual install; the "already installed (left as-is)" branch returns without refreshing PATH. Callers: line 196 (Ghidra, x64 only) and line 203 (Android, also on ARM64).

### Pattern 1: Version-gate predicate (all three scripts)
**What:** A status-returning function with no output, modeled on `node_supported`.
**When to use:** Before trusting any `JAVA_HOME`, and after installing our own (optional loud self-check, see Pitfall 10).
**Key details:**
- Capture with `out="$("$1/bin/java" -version 2>&1)" || return 1`. This avoids a `| grep -m1` pipe that can hit SIGPIPE under `pipefail`.
- Match with a regex stored in a variable: `local re='version "([0-9]+)(\.([0-9]+))?'` and `[[ "$out" =~ $re ]]`. A quoted regex on the right-hand side of `=~` is matched literally in Bash 3.2+, so it must sit in a variable.
- `=~` scans the whole multi-line string and takes the leftmost match, so `Picked up …` lines before the version line are skipped automatically.
- Use `${BASH_REMATCH[3]:-0}` so `set -u` is safe when the optional group didn't match (as with `"21"`).
- Callers must use it inside `if` / `||` / `&&`. The function's last command is `((major >= 21))`, so calling it as a bare statement under `set -e` would exit the script on false.

### Pattern 2: macOS "write `JAVA_HOME` only when it's ours" at profile-write time
**What:** `install_jdk` no longer touches `profile_exports`. Step 7 becomes a function (for example `write_profile`) whose first action is:
```bash
if [ -n "${JAVA_HOME:-}" ] && [ "$JAVA_HOME" = "$(jdk_home)" ]; then
  profile_exports+=("export JAVA_HOME=\"$JAVA_HOME\"")
fi
```
**Why one place:** it covers the first install (we just exported ours), the rerun (the old block exported ours and `install_jdk` is skipped because Ghidra is on PATH), deduplication (Ghidra and Android both call `install_jdk`) and JAVA-03 (a user's usable JDK never equals ours).
**`jdk_home`:** `printf '%s/libexec/openjdk.jdk/Contents/Home' "$(brew --prefix "$JDK_FORMULA")"`. `brew --prefix openjdk@21` prints the stable `opt` path even when the formula is **not installed** (observed: `/opt/homebrew/opt/openjdk@21`, rc=0, while `brew list --versions openjdk@21` returned rc=1). The `libexec/openjdk.jdk/Contents/Home` layout is confirmed by the formula: `libexec.install Dir["build/*/images/jdk-bundle/*"].first => "openjdk.jdk"; jdk /= "openjdk.jdk/Contents/Home"` [CITED: homebrew-core Formula/o/openjdk@21.rb].
**Check `[ -n "${JAVA_HOME:-}" ]` first** so `brew --prefix` is never run when no JDK is involved. Otherwise `--no-ghidra` without Android on a Mac without brew (dry run) prints `brew: command not found`.

### Pattern 3: Windows derive, check, set the session value, then persist
**What:** In `Install-Jdk`, after the reuse check fails: `Install-Winget $JdkId`. In dry run, set the placeholder and return (D-09). Otherwise `Update-SessionPath` (always, because `Install-Winget` skips it when Temurin is already installed), then `$cmd = Get-Command java -CommandType Application -ErrorAction SilentlyContinue`; throw if there is none; `$dir = Split-Path (Split-Path $cmd.Source)`; `Test-JdkUsable $dir` or throw with `$dir` in the message; `$env:JAVA_HOME = $dir`; `Set-UserEnv 'JAVA_HOME' $dir`.
**Why this works with the MSI:** with `ADDLOCAL=ALL`, the MSI's `FeatureEnvironment` writes `<Environment Id="PATH_SYSTEM" Name="PATH" Value="[INSTALLDIR]bin" … Part="first" Action="set" System="yes" />` [CITED: github.com/adoptium/installer wix/Main.wxs.template:109-110]. Temurin's `bin` goes to the **front** of Machine PATH, and `Update-SessionPath` puts Machine before User, so `Get-Command java` (first match only; `-All` is needed for more) resolves to Temurin right after a fresh install.

### Anti-Patterns to Avoid
- **Parsing only the first line of `java -version`:** `JAVA_TOOL_OPTIONS` / `JDK_JAVA_OPTIONS` add a line above it (observed this session). Search the whole output.
- **`& $java -version 2>&1` under `$ErrorActionPreference = 'Stop'` in PS 5.1:** the first stderr line becomes a terminating NativeCommandError. Set `$ErrorActionPreference = 'Continue'` **inside the function**. That creates a function-local copy; the script-level value stayed `Stop` in the test this session.
- **Relying on `Set-UserEnv` to set the session value:** it returns before `Set-Item` when any different user value exists, or when the value is equal.
- **Re-adding `JAVA_HOME` inside `install_jdk` on macOS:** it would still lose the line on reruns where step 4 skips (Ghidra on PATH) and Android is off. That is HARD-11's exact scenario.
- **Making an `a && b && c` list the last line of a function:** under `set -e` a false test makes the function return 1 and kills the caller. Use `if … then … fi`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Finding the macOS JDK path | `ls /opt/homebrew/Cellar/openjdk@21/*/…` or `/usr/libexec/java_home` (forbidden by D-01) | `$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home` | `opt` symlink is stable across `brew upgrade`; works for Intel `/usr/local` and Apple silicon `/opt/homebrew` |
| Running a native command and capturing stderr in PS 5.1 | `cmd /c "\"$java\" -version 2>&1"` (quoting differs between 5.1 and 7.3+ argument passing) | `& $java -version 2>&1 \| ForEach-Object { "$_" }` with function-local `$ErrorActionPreference = 'Continue'` | No cmd.exe quoting rules; tested on pwsh 7.6 |
| Persisting a Windows user env var | direct `[Environment]::SetEnvironmentVariable` in `Install-Jdk` | existing `Set-UserEnv` (prints `setx`, honors `-DryRun`, records `env:NAME`) | Uninstall already handles `env:` entries |
| Persisting a Linux setting | new profile-writing code | existing `setting JAVA_HOME …` | Already exported, queued, and reset on rerun |
| Removing duplicates from `profile_exports` | a dedupe loop (Bash 3.2 has no associative arrays) | append `JAVA_HOME` exactly once, in step 7 | No loop needed |

**Key insight:** every persistence and ledger mechanism this phase needs already exists. The phase is about *where* the decision is made (one predicate, one append point), not about new plumbing.

## Common Pitfalls

### Pitfall 1: Second `install_jdk` call in the same run (Linux and Windows dry run)
**What goes wrong:** With `--with-android` and Ghidra, `install_jdk` runs twice. In `--dry-run` on a fresh machine, the first call sets `JAVA_HOME=$STATE_DIR/jdk` (Linux) or `'<Temurin JAVA_HOME>'` (Windows), and neither exists. The second call's predicate fails, so the user sees a false "JAVA_HOME points at … not JDK 21" warning, the download/`winget install` plan prints twice, and Linux adds `export JAVA_HOME=` to `profile_lines` twice.
**How to avoid:** Linux: start `install_jdk` with `[ "${JAVA_HOME:-}" = "$STATE_DIR/jdk" ] && return`, written as an `if` because it is the first statement and an `&&` list here is fine, but keep it out of last position. This is safe because `do_install` unsets any inherited `$STATE_DIR/*` value before step 1, so equality can only come from this run. Windows: `if ($env:JAVA_HOME -eq '<Temurin JAVA_HOME>') { return }`, or check `Test-JdkUsable` after the placeholder check. macOS: `install_jdk`'s "already ours" branch only re-runs `brew_install` (idempotent) and does not warn.
**Warning signs:** a dry-run log with two "Would download Temurin 21" lines or a warning naming the script's own path.

### Pitfall 2: Bash 3.2 regex quoting and `BASH_REMATCH` under `set -u`
**What goes wrong:** `[[ $out =~ "version \"([0-9]+)" ]]` is a literal match in Bash 3.2+ and never matches. `${BASH_REMATCH[3]}` for an optional group that didn't take part can trip `set -u` on some versions.
**How to avoid:** Store the regex in `local re=…`; use `${BASH_REMATCH[3]:-0}`. Tested under 3.2.57 this session.

### Pitfall 3: macOS `/usr/bin/java` stub and other non-JDK `JAVA_HOME`s
**What goes wrong:** `JAVA_HOME=/usr` runs Apple's stub, which prints "Unable to locate a Java Runtime" and exits 1 (observed). It may also open a GUI prompt.
**How to avoid:** Fail closed on a non-zero exit (`|| return 1`). This is already in the predicate. Nothing more needed.

### Pitfall 4: Windows `Set-UserEnv` skips the session value
**What goes wrong:** If the user has a *user-scope* `JAVA_HOME` (JDK 17), `Set-UserEnv 'JAVA_HOME' $dir` warns and returns before `Set-Item env:`, so `rea setup` sees JDK 17. D-05 says the session value must still be set.
**How to avoid:** `$env:JAVA_HOME = $dir` in `Install-Jdk` before `Set-UserEnv`. Don't change `Set-UserEnv` itself; its other callers rely on its behavior.

### Pitfall 5: Windows PS 5.1 NativeCommandError on `java -version`
**What goes wrong:** Before PowerShell 7.1, native stderr is wrapped as ErrorRecords, so with `$ErrorActionPreference = 'Stop'` "any text written to stderr would cause your script execution to be impacted". In 7.1+, stderr "is not affected by `$ErrorActionPreference`" [CITED: devblogs.microsoft.com/powershell/powershell-7-1-preview-6/]. pwsh 7 in CI will **not** reproduce the 5.1 failure.
**How to avoid:** Function-local `$ErrorActionPreference = 'Continue'`, convert records to strings with `"$_"`, and decide on `$LASTEXITCODE` plus the regex. Whether `"$_"` of a 5.1 NativeCommandError equals the raw line is [ASSUMED] (it is the exception message); confirm under VERI-02.

### Pitfall 6: `Get-Command java` might not be Temurin
**What goes wrong:** If Temurin was *already installed* (left as-is) and another JDK or Oracle's `…\Oracle\Java\javapath` shim was installed later with its own `Part="first"`-style prepend, `Get-Command java` resolves there. The derived folder then fails `Test-JdkUsable` and D-08 throws. A newer usable JDK on PATH would be accepted even though it isn't Temurin.
**How to avoid:** Follow D-08 as written, so the failure is loud and names the folder. See Open Question 2 for an optional fallback to Machine `JAVA_HOME`, which `ADDLOCAL=ALL` sets.

### Pitfall 7: Stale user `JAVA_HOME` after a Temurin upgrade (Windows)
**What goes wrong:** The run-1 user `JAVA_HOME` points at `…\jdk-21.0.12.1-hotspot`. `winget upgrade` moves Temurin to a new folder. On rerun, the predicate fails and we warn, derive the new folder and set the session value, but `Set-UserEnv` refuses to replace "an existing user value", even one the script recorded (`env:JAVA_HOME` in the ledger). New terminals keep the dead path.
**How to avoid:** Out of scope for D-05 as written. See Open Question 3.

### Pitfall 8: Homebrew `ghidra` pulls in `openjdk@21` anyway (macOS)
**What goes wrong:** `ghidra.rb` has `depends_on "openjdk@21"`, and `bin/ghidraRun` is written with `Language::Java.overridable_java_home_env("21")`, which is `JAVA_HOME="${JAVA_HOME:-<openjdk@21 home>}"` [CITED: homebrew-core Formula/g/ghidra.rb; Homebrew/brew Library/Homebrew/language/java.rb]. If the user's JDK is reused (so `install_jdk` installs nothing), `brew install ghidra` still installs `openjdk@21` as a dependency. It is **not** recorded (only `brew:ghidra` is), so uninstall leaves it behind. Success criterion 1 ("installs no JDK") cannot literally hold on macOS with Ghidra.
**How to avoid:** In step 4, call `brew_install "$JDK_FORMULA"` before `brew_install ghidra` whenever Ghidra is being installed. That records `brew:openjdk@21` only when it is new, and uninstall's reverse order removes `ghidra` first, then `openjdk@21` (guarded by `brew uses --installed`). Keep `install_jdk` purely about which `JAVA_HOME` to use. Confirm with the user (Assumption A3).

### Pitfall 9: Testing JAVA-04 by running macOS `do_install` in the sandbox
**What goes wrong:** `load_brew` evals the real `/opt/homebrew/bin/brew shellenv` (present on dev Macs and the `macos-latest` runner), which puts the real brew ahead of the stubs. A sandboxed `do_install` could really `brew install`. Phase 1 already hit this ("on a dev Mac load_brew puts the real brew before the stubs").
**How to avoid:** Pull step 7 out into a function (for example `write_profile`) and call that directly, plus `install_jdk`, with a stub `brew` whose `--prefix` prints a path under the temp HOME. Never call `load_brew` or `do_install` in tests. The two-write check needs BSD `sed -i ''`, so it is macOS-only like TEST-02.

### Pitfall 10: Our own JDK doesn't actually run
**What goes wrong:** A partial or odd Adoptium layout (WR-01), or a broken brew keg, gets set as `JAVA_HOME` and the run still prints "Done".
**How to avoid (discretion):** After a real (non-dry) install, `jdk_usable "$STATE_DIR/jdk" || die "the downloaded JDK at $STATE_DIR/jdk does not run."`. On macOS, the same check on `$(jdk_home)`. This mirrors `node_supported || die` after `install_node`. It costs one line and is the cheap version of the WR-01 hardening the discretion clause allows.

### Pitfall 11: Unix pwsh `Update-SessionPath` wipes PATH in the driver
**What goes wrong:** On macOS/Linux pwsh, `[Environment]::GetEnvironmentVariable('Path','Machine'|'User')` both return empty (observed), so `Update-SessionPath` sets `$env:Path = ';'` and every later stub lookup fails.
**How to avoid:** In the `test.sh` pwsh driver, after dot-sourcing, add `function Update-SessionPath {}`. `[Environment]::SetEnvironmentVariable(…, 'User')` is a silent no-op on Unix pwsh (observed), so `Set-UserEnv` can run in the driver and still `Add-Record "env:JAVA_HOME"` into the driver's redirected `$StateFile`.

## Code Examples

These were tested this session in the scratchpad, not in the repo.

### 1. Bash predicate (Bash 3.2 safe; same text in both scripts)
```bash
# Ghidra 12 and REA need JDK 21+. Reads `java -version` (stderr); a JAVA_TOOL_OPTIONS "Picked up" line may come first.
jdk_usable() {
  local out major re='version "([0-9]+)(\.([0-9]+))?'
  [ -n "$1" ] && [ -x "$1/bin/java" ] || return 1
  out="$("$1/bin/java" -version 2>&1)" || return 1
  [[ "$out" =~ $re ]] || return 1
  major="${BASH_REMATCH[1]}"
  [ "$major" = 1 ] && major="${BASH_REMATCH[3]:-0}"   # "1.8.0_402" -> 8
  ((major >= 21))
}
```
Results under `/bin/bash` 3.2.57 with stubs: `1.8.0_402`→no, `17.0.2`→no, `21`→yes, `Picked up…`+`21.0.5`→yes, `25-ea`→yes, garbage→no, version 21 but exit 1→no, missing `bin/java`→no, empty arg→no. Real Homebrew JDK 17 (`openjdk version "17.0.20.1"`) with `JAVA_TOOL_OPTIONS` set→no. `/usr` (Apple stub)→no. `shellcheck -s bash` clean.

### 2. macOS `install_jdk` and step-7 append (sketch)
```bash
jdk_home() { printf '%s/libexec/openjdk.jdk/Contents/Home' "$(brew --prefix "$JDK_FORMULA")"; }

# Reuses a JAVA_HOME that is JDK 21+; otherwise installs openjdk@21 and points this run at it.
install_jdk() {
  local ours
  ours="$(jdk_home)"
  if [ "${JAVA_HOME:-}" != "$ours" ]; then
    if jdk_usable "${JAVA_HOME:-}"; then
      log "Using JDK at $JAVA_HOME"
      return
    fi
    [ -z "${JAVA_HOME:-}" ] || warn "JAVA_HOME points at $JAVA_HOME, which is not JDK 21 or newer; installing the script's own JDK 21."
  fi
  brew_install "$JDK_FORMULA"
  export JAVA_HOME="$ours"
}
# Step 7, first lines of write_profile (Pattern 2):
#   if [ -n "${JAVA_HOME:-}" ] && [ "$JAVA_HOME" = "$(jdk_home)" ]; then profile_exports+=("export JAVA_HOME=\"$JAVA_HOME\""); fi
# Step 5 becomes plain `install_jdk` (the predicate lives inside it).
```

### 3. PowerShell predicate (PS 5.1-compatible constructs)
```powershell
# Ghidra 12 and REA need JDK 21+. java -version writes to stderr; a JAVA_TOOL_OPTIONS "Picked up" line may come first.
function Test-JdkUsable([string]$Dir) {
    if (-not $Dir) { return $false }
    $java = Join-Path (Join-Path $Dir 'bin') 'java.exe'
    if (-not (Test-Path -LiteralPath $java -PathType Leaf)) { return $false }
    # Windows PowerShell 5.1 turns redirected native stderr into errors that 'Stop' would make terminating.
    $ErrorActionPreference = 'Continue'
    $out = (& $java -version 2>&1 | ForEach-Object { "$_" }) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $out -notmatch 'version "(\d+)(?:\.(\d+))?') { return $false }
    $major = [int]$Matches[1]
    if ($major -eq 1 -and $Matches[2]) { $major = [int]$Matches[2] }
    return $major -ge 21
}
```
Results under pwsh 7.6.7 (macOS) with `bin/java.exe` shebang stubs: the same table as Example 1. Script-level `$ErrorActionPreference` was still `Stop` afterwards.

### 4. test.sh additions (shape)
- Stub JDKs: `mkjdk NAME 'printf …>&2'` writes `$work/jdks/NAME/bin/java` (and `java.exe` for the pwsh driver). Table: `8 17 21 21.0.5 25-ea missing garbage` (D-10), plus `picked-up` (a `Picked up JAVA_TOOL_OPTIONS:` line before `21.0.5`). Run `sandbox "$script" 'jdk_usable "$work/jdks/17"'` for both bash scripts on every OS. `sandbox` runs in a `( … )` subshell, so `$work` is visible.
- Linux `install_jdk` decisions (any OS, `dry_run=true`, so no curl): JDK 17 → warning printed, `JAVA_HOME=$STATE_DIR/jdk`, exactly one `export JAVA_HOME=` in `profile_lines` after **two** calls. JDK 21 → `JAVA_HOME` unchanged, no `JAVA_HOME` entry in `profile_lines`.
- macOS (Darwin only, BSD sed): stub `brew` (`--prefix` → `$HOME/brew/opt/openjdk@21`; `list` → exit 0), create a stub JDK 21 at that `…/libexec/openjdk.jdk/Contents/Home`, set `JAVA_HOME` to it, run `write_profile` in two separate sandboxes. Expect `grep -c '^# >>> rea-installer >>>$'` = 1 and `grep -c '^export JAVA_HOME='` = 1. Negative case: `JAVA_HOME` = a user JDK 21 elsewhere → `install_jdk; write_profile` writes no `JAVA_HOME` line (JAVA-03).
- pwsh driver: the `Test-JdkUsable` table; then `$DryRun = $true` + stub `winget` (`list` → exit 1) + JAVA_HOME→JDK 17 → `Install-Jdk` twice → `$env:JAVA_HOME -eq '<Temurin JAVA_HOME>'`, no ledger. Optional non-dry case: redefine `Update-SessionPath {}`, prepend a fake `$work/temurin/bin` (containing `java` and `java.exe`) to `$env:PATH` using `[IO.Path]::PathSeparator` → expect `$env:JAVA_HOME` = `$work/temurin` and `env:JAVA_HOME` + `winget:EclipseAdoptium.Temurin.21.JDK` in the ledger.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Native stderr → ErrorRecords honoring `$ErrorActionPreference` | stderr treated like an information stream, not affected by EAP | PowerShell 7.1 [CITED: PS 7.1 preview 6 blog] | Script must still handle 5.1; CI pwsh 7 can't catch it |
| Ghidra on Homebrew as a cask (per AUDIT/ROADMAP wording) | `ghidra` is a `homebrew/core` **formula** built from source, `depends_on "openjdk@21"` | — [VERIFIED: brew info; formula source] | Fix the "cask" wording in planning docs; see Pitfall 8 |
| Temurin MSI default features (FeatureJavaHome off, Level 2) | winget manifest overrides with `ADDLOCAL=ALL` | manifests 21.0.11.10 and 21.0.12.101 both [VERIFIED: winget-pkgs] | Machine `JAVA_HOME` *is* set under winget; D-08 still correct and robust |

**Deprecated/outdated:** none relevant.

## Follow-ups found (not this phase's scope; record them, don't plan them)

1. **macOS `GHIDRA_INSTALL_DIR` is needed.** REA's `discoverGhidraInstallationOnPath` does `root = dirname(realpathSync(candidate))` and accepts it only if `root/Ghidra/application.properties` is a file and `root/support/analyzeHeadless` is executable [CITED: github.com/morluto/rea src/ghidra/GhidraInstallation.ts:976-1012]. Homebrew writes `bin/ghidraRun` as an env script in the keg's `bin/` and installs the Ghidra tree into `libexec` (`libexec.install (buildpath/"build/dist/ghidra_#{version}_PUBLIC").children`) [CITED: homebrew-core Formula/g/ghidra.rb]. So REA won't discover Homebrew Ghidra. Fix: `profile_exports+=("export GHIDRA_INSTALL_DIR=\"$(brew --prefix ghidra)/libexec\"")` plus an export for this run. Per CONTEXT "Deferred Ideas", this is its own follow-up (could be added to Phase 3 or a new requirement). Not executed against a real install: confidence MEDIUM-HIGH, from code reading.
2. **winget `ADDLOCAL=ALL` also enables `FeatureOracleJavaSoft`.** That writes `HKLM\SOFTWARE\JavaSoft` keys, and Adoptium warns this can "break Oracle java start launch from PATH when Adoptium is uninstalled" [CITED: adoptium/installer wix/README.md:116]. That is an uninstall side effect on machines with Oracle Java. Candidate future fix: winget `--override` with an explicit `ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJavaHome,FeatureJarFileRunWith` (unverified).
3. **Windows `apktool.bat` runs `@java -jar`** (PATH java, not `%JAVA_HOME%`) [VERIFIED: rea-install-windows.ps1:209]. **Linux Apktool launcher** prefers the *runtime* `${JAVA_HOME:-baked}` [VERIFIED: rea-install-linux.sh:412]. Either can pick a pre-21 Java at run time. Out of scope.
4. **README line 163** says each script checks "a JDK in `JAVA_HOME`". DOCS-01 (Phase 3) should say "a JDK 21+ in `JAVA_HOME`".
5. **Windows ARM64:** the Temurin 21 winget manifest lists only an `x64` installer, so `-WithAndroid` on ARM64 relies on x64 emulation. README already says this.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | In Windows PowerShell 5.1, `"$_"` of a redirected native-stderr ErrorRecord is the raw stderr line, so the regex sees `openjdk version "21…"` | Pitfall 5, Code Example 3 | Predicate always false on 5.1 → script always installs Temurin, then throws after deriving. Mitigation: also try `$_.Exception.Message`; confirm under VERI-02 |
| A2 | `Get-Command java` right after a fresh winget Temurin install resolves to Temurin's `bin\java.exe` (relies on `Part="first"` + Machine-before-User in `Update-SessionPath`) | Pattern 3, Pitfall 6 | D-08 throws on machines with a later-prepended JDK/shim (loud, not silent) |
| A3 | User accepts that on macOS, Homebrew installs `openjdk@21` as Ghidra's dependency even when their JDK 21+ is reused, and that recording it via an explicit `brew_install` before `ghidra` is the right fix | Pitfall 8 | Criterion 1 judged unmet on macOS, or uninstall leaves `openjdk@21` behind |
| A4 | Requiring `bin/javac` in the predicate is acceptable (REA's doctor rejects JREs: "presence of `javac`/`javac.exe`") | Open Question 1 | Without it, a JRE 21 `JAVA_HOME` is reused and `rea doctor` reports it unhealthy |
| A5 | Apktool 3.x's minimum Java (relevant to follow-up 3) | Follow-ups | Informational only |

## Open Questions

1. **Should "usable" also require `bin/javac` (a full JDK)?**
   - What we know: REA's doctor "validates … the presence of `javac`/`javac.exe`" and classifies a home without `javac` as `"jre"` [CITED: rea docs/installation.md; GhidraInstallation.ts]. D-01 only checks `java -version`.
   - Recommendation: add `[ -x "$1/bin/javac" ]` / `Test-Path …\bin\javac.exe` to the predicate. It is one condition and matches the requirement's wording ("JDK 21"). Because it tightens a locked decision, the planner should note it as a small deviation for user confirmation, or leave it out.
2. **Windows fallback when the PATH-derived folder isn't JDK 21+?**
   - What we know: with `ADDLOCAL=ALL`, Machine `JAVA_HOME` = `[INSTALLDIR]` (with a trailing backslash) [CITED: Main.wxs.template:134].
   - Recommendation: keep D-08 (throw). Optionally try `[Environment]::GetEnvironmentVariable('JAVA_HOME','Machine')` as a second candidate before throwing. That doesn't conflict with D-03, which is about *reusing the user's* JDK, not locating the one we just installed. Planner's call; default is D-08 as written.
3. **Stale script-owned user `JAVA_HOME` on Windows after a Temurin upgrade (Pitfall 7)?**
   - Recommendation: out of scope; record it as a known limitation. A fix would let `Install-Jdk` overwrite the user var when the ledger already holds `env:JAVA_HOME`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `/bin/bash` 3.2 | macOS predicate parity | ✓ | 3.2.57 | — |
| shellcheck | TEST-01 on edited scripts | ✓ | (Homebrew) | CI ubuntu job |
| pwsh | parse + driver checks | ✓ | 7.6.7 | — (5.1 not available anywhere in CI: A1 stays open) |
| brew | Pitfall 8 / `brew --prefix` facts | ✓ | — | tests use a stub `brew` |
| docker | existing DRY-01/02 checks | ✓ (CLI present) | — | SKIP locally if the daemon is stopped |
| Real JDK for sampling output | predicate validation | ✓ Homebrew `openjdk@17` | 17.0.20.1 | stubs |
| Windows PowerShell 5.1 / real Windows | JAVA-01 confirmation | ✗ | — | Deferred to VERI-02 (per CONTEXT) |

**Missing dependencies with no fallback:** none that block this phase (real Windows is explicitly deferred).

## Validation Architecture

Skipped: `workflow.nyquist_validation` is `false` in `.planning/config.json`. Test design for the planner is in Code Example 4. The commands are `./test.sh` locally and the GitHub Actions `linux` (`./test.sh`) and `macos` (`/bin/bash ./test.sh`) jobs [VERIFIED: .github/workflows/test.yml].

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | Treat `JAVA_HOME` and `java -version` output as untrusted: anchored regex on captured output, fail closed, no `eval` |
| V6 Cryptography | no new use | Linux Temurin still verified against Adoptium's published checksum (unchanged) |
| V7 Error handling and logging | yes | Never print captured `java -version` output: a `Picked up JAVA_TOOL_OPTIONS:` line can echo proxy credentials (`-Dhttp.proxyPassword=…`). Warnings name only the folder |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Executing `$JAVA_HOME/bin/java` from a user-controlled path | Elevation (only if the script were run as root with an inherited env) | Script runs as the user; Linux elevates only package-manager calls via `sudo_cmd`, and `sudo` resets env by default. No change needed |
| Profile injection via a crafted `JAVA_HOME` | Tampering | Only script-owned paths are ever written to the profile block (`$STATE_DIR/jdk`, `$(jdk_home)`); the user's value is never written |
| Leaking secrets from `JAVA_TOOL_OPTIONS` into logs | Information disclosure | Don't print `$out`; warn with the folder only |
| Silent wrong JDK (too old) reported as "Done" | Repudiation / integrity | The predicate, plus optional post-install self-check (Pitfall 10) |

## Sources

### Primary (HIGH confidence)
- Repo files read this session: `rea-install-linux.sh` (71-75, 318-336, 361-365, 395, 404, 411-412), `rea-install-macos.sh` (17, 22-23, 115-129, 180-219), `rea-install-windows.ps1` (34, 71-74, 88-112, 160-167, 189-212), `test.sh` (17-39, 264-314), `.github/workflows/test.yml`, `.planning/AUDIT.md`, CONTEXT, REQUIREMENTS, ROADMAP
- Local probes: `/bin/bash` 3.2.57 predicate run; pwsh 7.6.7 predicate run; real Homebrew JDK 17 `-version` output with `JAVA_TOOL_OPTIONS` / `JDK_JAVA_OPTIONS`; `brew --prefix openjdk@21` without the formula installed; `brew info --json=v2 ghidra|openjdk@21`; Unix pwsh Machine/User env behavior
- microsoft/winget-pkgs `manifests/e/EclipseAdoptium/Temurin/21/JDK/21.0.12.101/…installer.yaml` and `21.0.11.10` (via `gh api`): `Custom: ADDLOCAL=ALL`
- adoptium/installer `wix/Main.wxs.template` (feature levels, `PATH_SYSTEM Part="first"`, `JAVA_HOME_SYSTEM`) and `wix/README.md` (feature list, JavaSoft warning)
- Homebrew/homebrew-core `Formula/g/ghidra.rb`, `Formula/o/openjdk@21.rb`; Homebrew/brew `Library/Homebrew/language/java.rb`
- morluto/rea `docs/installation.md` (Ghidra section) and `src/ghidra/GhidraInstallation.ts` (`discoverGhidraInstallationOnPath`, `javaMajor`)

### Secondary (MEDIUM confidence)
- [PowerShell 7.1 preview 6 release notes](https://devblogs.microsoft.com/powershell/powershell-7-1-preview-6/): native stderr no longer affected by `$ErrorActionPreference`
- [PowerShell PR #13361](https://github.com/PowerShell/PowerShell/pull/13361) (from search results)

### Tertiary (LOW confidence)
- Exact Windows PowerShell 5.1 string form of NativeCommandError records (A1). No 5.1-specific doc found.

## Metadata

**Confidence breakdown:**
- Bash predicate and Linux/macOS flow: HIGH. Tested under Bash 3.2 against stub and real output; the Homebrew paths come from formula source and local `brew`.
- Windows flow: MEDIUM. Manifest and WiX source read; pwsh 7 tested; 5.1 and real-MSI behavior not observed.
- Pitfalls: HIGH for 1-4 and 8-11 (from code reading and probes), MEDIUM for 5-7.
- REA Ghidra discovery follow-up: MEDIUM-HIGH (source read, not executed).

**Research date:** 2026-10-14
**Valid until:** 2026-11-13. Winget manifests and Homebrew formulas move quickly; re-check `ADDLOCAL` and `depends_on` if planning slips.
