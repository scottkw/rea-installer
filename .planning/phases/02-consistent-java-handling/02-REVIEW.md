---
phase: 02-consistent-java-handling
reviewed: 2026-10-14T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - rea-install-linux.sh
  - rea-install-macos.sh
  - rea-install-windows.ps1
  - test.sh
findings:
  critical: 1
  warning: 10
  info: 6
  total: 17
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-10-14
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

I reviewed the Phase 2 diff (`4674cf1c..HEAD`): `jdk_usable`, `install_jdk`, `jdk_home` and `write_profile` in the two bash scripts, `Test-JdkUsable` and `Install-Jdk` in the PowerShell script, and the new JAVA-0x checks in `test.sh`. `./test.sh` passes locally on macOS (73 passed, 0 failed, 2 skipped), so the findings below are in behaviour the tests don't cover.

The bash predicate is sound and Bash 3.2 safe. The Linux same-run guard is correct, because `do_install` unsets inherited `$STATE_DIR` values first. Most of the risk is on Windows:
- `Install-Jdk` stores a version-specific Temurin folder in a persistent user variable. `Set-UserEnv` will not replace that value later, even though the script set it, so a Temurin upgrade leaves a dead `JAVA_HOME` that a rerun cannot fix.
- The folder is taken from whichever `java` comes first on PATH.
- To find it, `Install-Jdk` now always replaces the session PATH.

On macOS, keeping `JAVA_HOME` in the profile on a rerun depends on the caller's environment, not on what the script installed. `jdk_home` turns a missing `brew` into a wrong path without failing. Some of these were recorded as accepted risks in the 02-0x SUMMARY files; I list them anyway because they conflict with the project's core value, "a rerun recovers".

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Windows persists a version-specific Temurin path that a rerun can never repair

**File:** `rea-install-windows.ps1:188-192` (with `Set-UserEnv` at `114-120`)
**Issue:** `Install-Jdk` saves `JAVA_HOME` as the folder of the `java` it finds on PATH, for example `C:\Program Files\Eclipse Adoptium\jdk-21.0.5.11-hotspot`. Temurin's MSI installs each update into a new folder with the version in its name, and a `winget upgrade` of the same major version removes the old one. After a routine upgrade, the user-scope `JAVA_HOME` points at a deleted folder. Java tools that check `JAVA_HOME`, such as Gradle and Maven, then fail in every new terminal. The agent registrations that `rea setup` copied also hold the dead path.

Rerunning `install` does not fix it:
1. `Test-JdkUsable` fails on the dead path.
2. The script warns, derives the new folder and sets the session value.
3. `Set-UserEnv` sees a different existing user value and prints "already set for your user ...; leaving it as-is".

The value it refuses to replace is one the script wrote itself; the ledger holds `env:JAVA_HOME`. This contradicts the core value ("a rerun recovers"). macOS avoids the problem by using Homebrew's stable `opt` path, and Linux by using `~/.rea-installer/jdk`. 02-03-SUMMARY accepts this as T-02-13, but the fix is a few lines.
**Fix:** Let `Install-Jdk` replace a user value the script owns.
```powershell
$owned = (Test-Path $StateFile) -and (Get-Content $StateFile | Where-Object { $_ -eq 'env:JAVA_HOME' })
$userVal = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
$env:JAVA_HOME = $dir
if ($owned -and $userVal -and $userVal -ne $dir -and -not (Test-JdkUsable $userVal)) {
    Write-Host "  > setx JAVA_HOME `"$dir`""
    if (-not $DryRun) { [Environment]::SetEnvironmentVariable('JAVA_HOME', $dir, 'User') }
} else {
    Set-UserEnv 'JAVA_HOME' $dir
}
```
A sturdier option: point `JAVA_HOME` at the MSI-maintained Machine `JAVA_HOME`, or at the registry path `HKLM:\SOFTWARE\Eclipse Adoptium\JDK\21.*\hotspot\MSI` (value `Path`). Either one tracks upgrades.

## Warnings

### WR-01: Windows takes the first `java` on PATH as Temurin and throws when it is anything else

**File:** `rea-install-windows.ps1:186-189`
**Issue:** `Get-Command java ... | Select-Object -First 1` returns whichever `java.exe` comes first on the Machine+User PATH. The users who reach this branch have no JDK 21 `JAVA_HOME`, so many of them have an older Java on PATH. Two common cases:
- Temurin 21 was already installed and is left as-is, and an Oracle JDK or JRE installed later put `C:\Program Files\Common Files\Oracle\Java\javapath` at the front of the Machine PATH.
- An older JDK's own `bin` comes first on PATH.

Either way the derived folder fails `Test-JdkUsable` and the script throws. The `javapath` parent has no `bin\java.exe` at all. Every rerun throws the same way, so the user cannot install Ghidra or Android support without editing PATH by hand. RESEARCH Pitfall 6 and assumption A2 name this risk; the test `JAVA-01 Windows Install-Jdk throws when the java on PATH is not JDK 21+` turns it into expected behaviour.
**Fix:** Check every candidate, not only the first, or skip PATH entirely.
```powershell
$dir = Get-Command java -CommandType Application -All -ErrorAction SilentlyContinue |
    ForEach-Object { Split-Path (Split-Path $_.Source) } |
    Where-Object { Test-JdkUsable $_ } | Select-Object -First 1
if (-not $dir) { throw 'Temurin installed but no JDK 21+ java was found on PATH.' }
```
A better source is the Adoptium registry key or the Machine `JAVA_HOME` that the MSI sets (Open Question 2 in RESEARCH).

### WR-02: `Install-Jdk` now always replaces the session PATH

**File:** `rea-install-windows.ps1:184` (`Update-SessionPath` at `71-74`)
**Issue:** `Update-SessionPath` sets `$env:Path` to Machine;User and drops every entry that exists only in this session. Before this phase it ran only after winget actually installed something. Now `Install-Jdk` calls it whenever `JAVA_HOME` is not JDK 21+, even when Temurin was already installed. Two effects:
- Node set up for the session only, for example with fnm (`fnm env | Invoke-Expression`), loses its PATH entry. Step 5 (`Invoke-Step npm`) then fails with "command not found", after Temurin and Ghidra have already been installed.
- Run in-process as `.\rea-install-windows.ps1 install`, the form in the script's header, it also overwrites the caller's interactive PATH, including pwsh 7's `$PSHOME` entry and activated venvs.

**Fix:** Add the Machine and User entries to the current PATH without dropping what is already there, at least in `Install-Jdk`:
```powershell
$env:Path = (@($env:Path -split ';') + ([Environment]::GetEnvironmentVariable('Path','Machine') -split ';') +
             ([Environment]::GetEnvironmentVariable('Path','User') -split ';') | Where-Object { $_ } | Select-Object -Unique) -join ';'
```
Alternatively, find Temurin through the registry (see WR-01) and skip the PATH refresh.

### WR-03: A Windows dry run overwrites the caller's `JAVA_HOME` with a placeholder

**File:** `rea-install-windows.ps1:182`
**Issue:** With `-DryRun`, `$env:JAVA_HOME = '<Temurin JAVA_HOME>'` now runs even when the user already had a `JAVA_HOME`, such as a JDK 17. The old code returned early on any set `JAVA_HOME`. PowerShell runs `.\rea-install-windows.ps1 install -DryRun` in the caller's process, so after the dry run that terminal's `JAVA_HOME` is the literal placeholder and Java tools there break until it is closed. The project's rule is that a dry run changes nothing. Only the `powershell -File` form, which starts a child process, is safe.
**Fix:** Track the dry-run state in a script variable, not in the environment:
```powershell
if ($script:JdkPlanned) { return }
...
if ($DryRun) { $script:JdkPlanned = $true; return }
```
`Set-UserEnv`'s `Set-Item "env:$Name"` before its `$DryRun` check has the same problem (pre-existing). Moving that line below the check fixes the rest.

### WR-04: A user-scope `JAVA_HOME` older than 21 stays persistent on Windows, unlike on Linux and macOS

**File:** `rea-install-windows.ps1:190-192`
**Issue:** When the user has a user-scope `JAVA_HOME` pointing at a JDK 17, Linux and macOS write the script's JDK into the profile block, which overrides it in new shells. Windows sets only the session value and `Set-UserEnv` warns and leaves the persistent value alone. The agent registrations made in that session get JDK 21, but every new terminal, including the one where the user runs `rea doctor` as the final message says, still uses JDK 17. This is the opposite of the "consistent Java handling" this phase aims for. D-05 chose this deliberately, but it is not consistent across platforms.
**Fix:** Either overwrite with an explicit warning, as the bash scripts effectively do through the profile block, or make the final "Done" message tell Windows users that new terminals will still use the old `JAVA_HOME` and how to change it.

### WR-05: Windows uninstall deletes the user's `JAVA_HOME` even if the user changed it after install

**File:** `rea-install-windows.ps1:301-305` (record written at `125` through `Install-Jdk:192`)
**Issue:** The ledger stores only `env:JAVA_HOME`, not the value. Uninstall deletes the user variable whatever it holds. `JAVA_HOME`, unlike the `REA_*` variables, is something users often change themselves, for example to switch JDKs after installing REA. Uninstall then removes the user's own setting, which breaks the rule "uninstall must not remove anything the script didn't add".
**Fix:** For `JAVA_HOME`, delete only when the current user value is still a Temurin folder the script derived. Either record the value (`env:JAVA_HOME=<dir>`) and compare, or at least check the current value against `*\Eclipse Adoptium\jdk-21*`. Otherwise warn and leave it.

### WR-06: The JDK check accepts a JRE, which REA rejects

**File:** `rea-install-linux.sh:285-293`, `rea-install-macos.sh:92-100`, `rea-install-windows.ps1:84-95`
**Issue:** `jdk_usable` / `Test-JdkUsable` only run `bin/java -version`. A `JAVA_HOME` pointing at a Java 21 JRE (for example Temurin JRE 21) is reused with "Using JDK at ...". Per RESEARCH Open Question 1 and A4, REA's doctor and `GhidraInstallation.ts` check for `javac`/`javac.exe` and treat a home without it as `"jre"`. The script's own comments say "JADX needs a full JDK". The script reports success and REA then reports the JDK as unhealthy. JAVA-02 promised that the script installs its own JDK in exactly this case. The plan left `javac` out on purpose (`02-01-PLAN.md:134`), but the result is wrong behaviour, not a matter of style.
**Fix:** Add one condition to each predicate:
```bash
[ -n "$1" ] && [ -x "$1/bin/java" ] && [ -x "$1/bin/javac" ] || return 1
```
```powershell
if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $Dir 'bin') 'javac.exe') -PathType Leaf)) { return $false }
```
Then add a `jre` row (java without javac, which should be rejected) to the test tables.

### WR-07: macOS `jdk_home` turns a missing `brew` into a wrong path without failing

**File:** `rea-install-macos.sh:135`
**Issue:** `printf '%s/libexec/...' "$(brew --prefix "$JDK_FORMULA")"` exits 0 even when `brew` fails, because the substitution is an argument to `printf`. On a Mac without Homebrew, a dry run (where step 2 cannot load brew) prints "brew: command not found" three times. It sets `JAVA_HOME=/libexec/openjdk.jdk/Contents/Home` and shows `export JAVA_HOME="/libexec/openjdk.jdk/Contents/Home"` in the planned profile block (reproduced with `env -i PATH=/usr/bin:/bin`). In a real run, a failing `brew --prefix` gives the confusing "Homebrew openjdk@21 at /libexec/... does not run.". The project rules (CLAUDE.md "Silent Fallbacks") say to let such failures crash.
**Fix:**
```bash
jdk_home() {
  local prefix
  prefix="$(brew --prefix "$JDK_FORMULA")" || return 1
  printf '%s/libexec/openjdk.jdk/Contents/Home' "$prefix"
}
```
For dry runs without brew, fall back to the default prefix (`/opt/homebrew` on arm64, `/usr/local` on Intel) and say so, rather than printing a path that starts with `/libexec`.

### WR-08: On a macOS rerun, the profile's `JAVA_HOME` depends on the caller's environment, not on what was installed

**File:** `rea-install-macos.sh:173-175`, `222-225`
**Issue:** JAVA-04 keeps our `JAVA_HOME` only if the shell running the rerun inherited it. On a rerun where Ghidra is already available (`ghidraRun` from the Homebrew Ghidra installed by run 1) and Android support is not requested, `install_jdk` is never called. Suppose a line added to the user's config after our block now sets `JAVA_HOME` to something else, for example SDKMAN's init block, which is appended to the end of `.zshrc`, or the user's own `export JAVA_HOME=$(/usr/libexec/java_home -v 17)`. Then `write_profile` rewrites the block without `JAVA_HOME`, prints no warning and runs no JDK check, and `rea setup` copies JDK 17 into the agent registrations. Linux does not have this problem: its loop unsets the `GHIDRA_INSTALL_DIR` that points into `$STATE_DIR`, so `install_jdk` runs again and warns. The two platforms behave differently in the case this phase was meant to make consistent.
**Fix:** Base the decision on what was installed: if `brew:openjdk@21` is in the ledger, or the old block contained `export JAVA_HOME=`, call `install_jdk` (or at least `jdk_usable "$JAVA_HOME"`, with a warning) before `write_profile`. Alternatively, always run the JDK check whenever Ghidra or Android support is present, not only when they are being installed.

### WR-09: A broken `~/.rea-installer/jdk` on Linux makes every rerun die

**File:** `rea-install-linux.sh:340-351`
**Issue:** The new self-check runs after `run mv "$dir" "$STATE_DIR/jdk"`. If the extracted layout is wrong, the folder still becomes the trusted path. One case is the accepted WR-01 limitation: Adoptium's `release_name` does not match the archive's top-level folder, so `unpack` moves the whole staging folder and `bin/java` ends up one level deeper. Every later run sees that `$STATE_DIR/jdk` exists, skips the download and dies with "the downloaded JDK at ... does not run.", without saying how to recover. Stopping loudly is correct, but a rerun never recovers.
**Fix:** Check the extracted folder before it is moved into place:
```bash
dir="$(unpack "$link $sha" "$release")"
[ -x "$dir/bin/java" ] || { run rm -rf "$dir"; die "Temurin archive layout unexpected (no bin/java under $dir)."; }
run mv "$dir" "$STATE_DIR/jdk"
```
Also make the final message say what to do, for example "remove $STATE_DIR/jdk and rerun", or remove it automatically when `jdk_usable` fails.

### WR-10: The last Windows test cannot fail on its winget-ledger assertion

**File:** `test.sh:432-456`
**Issue:** The "wrong java" test (lines 432-438) and the "no java" test (440-446) both run `Install-Jdk` for real (`$DryRun = $false`). `Install-Winget` therefore runs `Add-Record 'winget:EclipseAdoptium.Temurin.21.JDK'` into `$StateFile` before throwing (confirmed in a scratch driver). The final test (448-456) asserts `$ledger -contains 'winget:EclipseAdoptium.Temurin.21.JDK'`, but that line is already in the ledger, so the check passes even if the final `Install-Jdk` call never records the install.
**Fix:** Reset the ledger before the final case, for example `Remove-Item -Force $StateFile -ErrorAction SilentlyContinue` right before line 448, or give each case its own `$StateDir`.

## Info

### IN-01: The macOS dry run lists `brew install openjdk@21` twice

**File:** `rea-install-macos.sh:137-151`, `226`, `237`
**Issue:** macOS has no same-run guard like Linux (`JAVA_HOME = $STATE_DIR/jdk`) or Windows (the placeholder). With Ghidra and `--with-android`, step 5 calls `brew_install "$JDK_FORMULA"` again. The dry-run plan shows the install twice, and a real run logs "openjdk@21 already installed (left as-is)" for something it installed seconds earlier. 02-02-SUMMARY accepts this as cosmetic. The dry run is still the only preview the user gets.
**Fix:** In `install_jdk`, after `ours="$(jdk_home)"`, add `[ "${JAVA_HOME:-}" = "$ours" ] && [ "${jdk_done:-}" = true ] && return`, and set `jdk_done=true` at the end.

### IN-02: A reused JDK logs "Using JDK at ..." twice

**File:** `rea-install-linux.sh:335-338`, `rea-install-macos.sh:141-143`, `rea-install-windows.ps1:177`
**Issue:** When the user's JDK 21+ is reused, the Ghidra step and the Android step each run the predicate and log the line again. Only the script's own JDK is protected against the second call.
**Fix:** Track a same-run "JDK decided" flag and return early on the second call.

### IN-03: macOS writes the user's own `JAVA_HOME` when it matches Homebrew's path

**File:** `rea-install-macos.sh:172-175`
**Issue:** The comment says a reused user `JAVA_HOME` is never written (JAVA-03). If the user had set `JAVA_HOME` to `$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home` themselves, it is indistinguishable from ours and gets written into the block. Nothing breaks, because the value is the same, but the comment claims more than the code does.
**Fix:** Change the comment to "a user JAVA_HOME other than Homebrew's openjdk@21 path is never written".

### IN-04: The Windows warning says it will install a JDK when Temurin is already installed

**File:** `rea-install-windows.ps1:178-181`
**Issue:** "installing the script's own JDK 21" is printed even when `Install-Winget` then logs that Temurin is already installed and left as-is, for example on the rerun after an upgrade in CR-01.
**Fix:** Change the wording to "...; using JDK 21 (Temurin) instead."

### IN-05: The Windows Apktool launcher ignores the JDK the script chose

**File:** `rea-install-windows.ps1:235`
**Issue:** `apktool.bat` runs `@java -jar`, which uses whichever Java comes first on PATH, not `%JAVA_HOME%`. After this phase checks `JAVA_HOME` carefully, Apktool can still run on a Java 8 found on PATH. Recorded as follow-up 3 in RESEARCH.
**Fix:** `"@`"%JAVA_HOME%\bin\java`" -jar `"$jar`" %*"`, with `java` on PATH as the fallback when `JAVA_HOME` is empty.

### IN-06: Gaps in test coverage

**File:** `test.sh:240-337`
**Issue:**
- The failure paths of the real (non-dry) self-checks are not tested: Linux `rea-install-linux.sh:351` and macOS `rea-install-macos.sh:150`.
- The macOS same-run double plan (IN-01) is not asserted.
- No test covers the JRE case (WR-06).
- No test covers the macOS rerun where `install_jdk` is skipped and `JAVA_HOME` is not ours (WR-08).

**Fix:** Add a stub JDK whose `java` exits 1 at `$ours` and at `$STATE_DIR/jdk` and assert the `die`. Add a `jre` row to the predicate tables.

---

_Reviewed: 2026-10-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
