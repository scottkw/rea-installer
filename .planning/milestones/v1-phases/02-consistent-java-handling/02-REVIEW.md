---
phase: 02-consistent-java-handling
reviewed: 2026-10-15T02:17:45Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - rea-install-linux.sh
  - rea-install-macos.sh
  - rea-install-windows.ps1
  - test.sh
findings:
  critical: 1
  warning: 2
  info: 2
  total: 5
status: issues_found
---

# Phase 2: Code Review Report (re-review after gap closure 02-08, 02-09 and 02-10)

**Reviewed:** 2026-10-15T02:17:45Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This re-review covers `git diff 5e1e32f..HEAD` for the four source files. That is plan 02-08 (the macOS `write_profile` if/elif chain and the block-only `jdk_owned`), plan 02-09 (the Linux `Picked up` filter and the Windows "has no java.exe" replace rule), and plan 02-10 (test.sh comment wording only). Findings that 02-REVIEW-DISPOSITION.md records as deferred are not raised again.

Baseline: `/bin/bash ./test.sh` passes on macOS (96 passed, 0 failed, 2 skipped). The new code is Bash 3.2 safe: the here-strings and `BASH_REMATCH` work on 3.2, and there is no `mapfile` or `declare -A`. The Windows change uses only cmdlets that exist in PowerShell 5.1. I reproduced each defect below in a scratch sandbox with a real Homebrew `openjdk@17`, `/bin/bash` 3.2, or pwsh 7.6. None is inferred only.

Status of each prior finding:

| Prior finding | Verdict |
|---|---|
| WR-01 (macOS replaced a JDK 17 `JAVA_HOME` silently) | Fixed. The D-04 warning is printed once, and the test asserts it. |
| WR-02 (Windows kept a leftover folder without `java.exe`) | Fixed for the stated case. The new `Join-Path` on the saved value repeats an existing crash on a missing drive (WR-02 below). |
| WR-03 (macOS dead owned JDK, result depended on the shell) | Only partly fixed. It works only when another export (`--with-extras`) forces the block to be rewritten, which is the only case the test covers. On a plain `--no-ghidra` rerun, the old block keeps the dead `JAVA_HOME`, the warning says the opposite, and `rea setup` still gets the dead value from a shell that sourced the block. See WR-01. |
| IN-01 (`jdk_owned` matched user lines) | Fixed. The sed range plus here-string avoids the pipefail SIGPIPE trap, and the test runs against a failing `brew` stub, so it can fail. |
| T-02-02 (credentials in `Picked up` lines, 02-09 G-02-1) | Only partly fixed. Real JDKs prefix `JDK_JAVA_OPTIONS` with `NOTE: `, so the filter misses it. The test uses a made-up format. See CR-01. |

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: The Linux "does not run" error still prints `JDK_JAVA_OPTIONS`, including proxy passwords, because real JDKs prefix that line with `NOTE: `

**File:** `rea-install-linux.sh:379-381`; test at `test.sh:349-358`
**Issue:** The 02-09 fix (T-02-02, G-02-1) drops lines matching `^Picked up`. The JVM prints that form for `JAVA_TOOL_OPTIONS` and `_JAVA_OPTIONS`. The `java` launcher prints `JDK_JAVA_OPTIONS` differently: `NOTE: Picked up JDK_JAVA_OPTIONS: ...` (`ARG_INFO_ENVVAR` in the launcher). `grep -v '^Picked up'` keeps that line, and because it comes first, `head -3` keeps it too.

Reproduced with a real Homebrew OpenJDK 17:
```
$ JDK_JAVA_OPTIONS='-Dhttps.proxyPassword=hunter2 -Xbogus' java -version 2>&1 | grep -v '^Picked up' | head -3
NOTE: Picked up JDK_JAVA_OPTIONS: -Dhttps.proxyPassword=hunter2 -Xbogus
Unrecognized option: -Xbogus
Error: Could not create the Java Virtual Machine.
```
I also ran the exact `die` line from `rea-install-linux.sh:381` against a stub JDK that prints the real `NOTE:` form. It printed `error: ... java -version printed: NOTE: Picked up JDK_JAVA_OPTIONS: -Dhttps.proxyPassword=hunter2`. Stopping this credential leak was the purpose of the change, and it still happens for one of the three variables.

The regression test makes this look fixed. `test.sh:351` writes `Picked up JDK_JAVA_OPTIONS: -Xss2m` without the `NOTE: ` prefix, which no real JDK prints. It also puts the fake password only in the `JAVA_TOOL_OPTIONS` line. So the test passes while the real leak is still there.
**Fix:**
```bash
die "the JDK at $STATE_DIR/jdk does not run; java -version printed: $("$STATE_DIR/jdk/bin/java" -version 2>&1 | grep -Ev '^(NOTE: )?Picked up ' | head -3)"
```
In `test.sh:351`, emit the real format and put the secret in that line: `echo 'NOTE: Picked up JDK_JAVA_OPTIONS: -Dhttps.proxyPassword=hunter2' >&2`. Also update the comment at line 379 and the `jdk_usable` comments (`rea-install-linux.sh:284`, `rea-install-macos.sh:92`, `rea-install-windows.ps1:85`) to name the `NOTE: Picked up` form.

## Warnings

### WR-01: On a plain macOS `--no-ghidra` rerun, a dead owned JDK stays in the profile even though the warning says it was left out, and `rea setup` still receives it

**File:** `rea-install-macos.sh:231-234`, `245-256`; test at `test.sh:481-496`
**Issue:** Branch 1 of the new chain sets `ours=""` and warns "JAVA_HOME is left out of <profile>". It changes nothing else. Two things then go wrong:

1. **The profile is not changed.** `write_profile` rewrites the block only when `profile_exports` is non-empty (line 245). On macOS only `--with-extras` and the `JAVA_HOME` line add entries. A `--no-ghidra` rerun without `--with-extras` therefore leaves the old block alone, and that block still has `export JAVA_HOME="<dead ours>"`. Every new shell keeps getting the dead value, and the warning has just told the user the opposite. The comment at `test.sh:384` already says "without one, write_profile leaves the old block alone". The WR-03 test adds `export REA_TEST=1` in both modes, so it never covers this default rerun.
2. **The session is not changed.** From a shell that sourced the old block, `JAVA_HOME` is still the dead path after `write_profile`. Step 9 (`rea setup`) copies `JAVA_HOME` into the agent registrations (see the comment in `install_jdk`). From a shell that did not source the block, `JAVA_HOME` is unset. The previous review's WR-03 named this exact case ("`rea setup` copies that dead value into the agent registrations"), and the plan's goal was "the same from any shell". The registrations still depend on the caller's shell.

Reproduced (bash 3.2, the `test.sh` brew stub, ledger `brew:openjdk@21`, no JDK under the prefix, profile = old block exporting ours, `write_profile` only):
```
== mode: export JAVA_HOME="$ours"
warning: the script's openjdk@21 at .../Contents/Home does not run; JAVA_HOME is left out of .../.bash_profile. ...
session JAVA_HOME=.../Contents/Home        <- dead path, passed on to rea setup
profile: unchanged, still exports JAVA_HOME=".../Contents/Home"
== mode: unset JAVA_HOME
(same warning)
session JAVA_HOME=<unset>
profile: unchanged, still exports the dead JAVA_HOME
```
**Fix:** When branch 1 drops ours, clear the session copy if it is ours, and make sure the old block is removed even when nothing else is queued:
```bash
if [ "$jdk_chosen" = false ] && ! jdk_usable "$ours"; then
  jdk_usable "${JAVA_HOME:-}" ||
    warn "the script's $JDK_FORMULA at $ours does not run; JAVA_HOME is left out of $(profile_file). ..."
  [ "${JAVA_HOME:-}" = "$ours" ] && unset JAVA_HOME
  ours=""
  drop_block=true
...
if ((${#profile_exports[@]} > 0)); then
  ...
elif [ "${drop_block:-false}" = true ]; then
  remove_profile_block "$(profile_file)"
fi
```
Add a test case without `REA_TEST=1`. It should expect no `export JAVA_HOME=` in the profile in both modes, and `JAVA_HOME` unset in the session in both modes.

### WR-02: A `JAVA_HOME` on a drive that is not available crashes the Windows install with "Cannot find drive"

**File:** `rea-install-windows.ps1:205` (new in 02-09), same pattern at `rea-install-windows.ps1:88`
**Issue:** `Join-Path` checks that the drive qualifier exists, even though it only builds a string. With `$ErrorActionPreference = 'Stop'`, `Join-Path 'Q:\jdk-17' 'bin'` throws `Cannot find drive. A drive with the name 'Q' does not exist.` (reproduced in pwsh 7.6). `Test-Path -LiteralPath` returns `$false` for the same path. The 02-09 change replaced a `Test-Path -LiteralPath $userJava` that was safe here with `Join-Path (Join-Path $userJava 'bin') 'java.exe'`. Now a saved user `JAVA_HOME` on a missing drive aborts `Install-Jdk` before the ledger check, even when the script never set that value.

`Test-JdkUsable` (line 88, from d69aca5, earlier in this phase) has the same pattern and runs first on the session value, so in most sessions the crash happens there. I extracted `Test-JdkUsable` and called it with `Q:\jdk-17`, and it threw the same error. A realistic trigger is a `JAVA_HOME` on a mapped network drive or a removable disk. Mapped drives are not visible in an elevated PowerShell. In that case the user gets an obscure provider error instead of the D-04 warning and a Temurin install, which breaks "a failure stops loudly with a specific cause" and the D-04 contract.
**Fix:** Build the path with .NET, which does no drive lookup, in both places:
```powershell
$java = [IO.Path]::Combine($Dir, 'bin', 'java.exe')                       # Test-JdkUsable
$gone = $userJava -and -not (Test-Path -LiteralPath ([IO.Path]::Combine($userJava, 'bin', 'java.exe')) -PathType Leaf)
```
`[IO.Path]::Combine` with three arguments works in .NET Framework 4.x (PowerShell 5.1) and in .NET (PowerShell 7). Add a driver case with `$env:JAVA_HOME = 'Q:\jdk-17'` that expects the "not JDK 21 or newer" warning, not a throw.

## Info

### IN-01: The macOS warning tells the user to "Rerun without --no-ghidra", which installs Ghidra they opted out of

**File:** `rea-install-macos.sh:233`
**Issue:** The ledger can own `openjdk@21` from an earlier `--no-ghidra --with-android` run. If that JDK later stops running, a `--no-ghidra` rerun prints "Rerun without --no-ghidra to reinstall it." Following the advice runs `install_ghidra`, which runs `brew_install ghidra` when Ghidra is not present. That installs a large tool the user explicitly declined, just to repair the JDK. If the formula is still listed but broken, the rerun reaches `brew_install` ("already installed (left as-is)") and then dies with "does not run", so it does not reinstall anything.
**Fix:** Name the operations that actually repair it, for example "Run `brew reinstall openjdk@21`, or rerun with --with-android or without --no-ghidra."

### IN-02: `Set-UserEnv` is a generic helper, but its replace message now hard-codes `java.exe`

**File:** `rea-install-windows.ps1:122`, `130`
**Issue:** `Set-UserEnv` also sets `GHIDRA_INSTALL_DIR` and other variables. Only `Install-Jdk` passes `-Replace` today, but the comment and log text ("which has no java.exe") now describe a JAVA_HOME-specific rule inside a generic setter. A future `-Replace` caller would print a wrong reason.
**Fix:** Pass the reason from the caller (`-Reason 'which has no java.exe'`), or move the replace log line into `Install-Jdk`.

---

_Reviewed: 2026-10-15T02:17:45Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
