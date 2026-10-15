---
phase: 02-consistent-java-handling
reviewed: 2026-10-14T22:10:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - rea-install-linux.sh
  - rea-install-macos.sh
  - rea-install-windows.ps1
  - test.sh
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 2: Code Review Report (re-review after gap closure 02-06 and 02-07)

**Reviewed:** 2026-10-14T22:10:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This re-review covers `git diff e1ada43..HEAD` for the four source files: plan 02-06 (commits 2fd5825, d4021ad: macOS `JAVA_HOME` ownership, the nested Linux Temurin layout, and the `java -version` output in the Linux error) and plan 02-07 (commits 6b0fd4f, 8d0cbb5: the Windows "replace only a gone folder" rule and the dry-run `Path` fix). Findings that 02-REVIEW-DISPOSITION.md records as deferred are not raised again.

Baseline: `./test.sh` passes on macOS (91 passed, 0 failed, 2 skipped). The new code is Bash 3.2 safe, and every new side effect goes through `run`/`record` or a `$DryRun` guard. Each defect below was reproduced in a scratch sandbox (`/bin/bash` 3.2 or pwsh 7 with the same stubs `test.sh` uses), not inferred.

Status of each prior finding:

| Prior finding | Verdict |
|---|---|
| WR-01 (Windows overwrote a user-chosen `JAVA_HOME`) | Fixed for a user value that points at an existing JDK. The new test for "is it gone" checks only that the folder exists, so a leftover Temurin folder brings the CR-01 symptom back. See WR-02. |
| WR-02 (dry run refreshed the session `Path`) | Fixed. `Install-Winget` returns before `Add-Record`/`Update-SessionPath` in a dry run, and the stub flag makes the test able to fail. |
| WR-03 (macOS `--no-ghidra` rerun depended on the environment) | Fixed when the owned JDK runs. The new branch replaces a JDK 17 `JAVA_HOME` without the D-04 warning (WR-01). When the owned JDK is gone, the result still depends on the environment (WR-03). |
| WR-04 (Linux "rerun" advice) | Fixed. The nested layout is now used, and any other layout dies with "report this". |
| IN-03 (`brew --prefix` needed with Ghidra present) | Fixed for profiles without a `JAVA_HOME` line. The probe matches any user `export JAVA_HOME=` line, not only the block. See IN-01. |
| IN-04 (no `java -version` output) | Fixed: the final `die` now shows the output. |
| IN-05 (test gaps) | Fixed: empty release, nested layout, `java -version` output, dry-run `Path`, the owned-but-existing Windows value, and the macOS `--no-ghidra` rerun are now tested. |

No critical issues.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: A macOS `--no-ghidra` rerun now replaces a JDK 17 `JAVA_HOME` without warning, and the user's own line stops taking effect

**File:** `rea-install-macos.sh:224-232`
**Issue:** The second clause added for WR-03 (`owned && ! jdk_usable "$JAVA_HOME" && jdk_usable "$ours"`) also matches a `JAVA_HOME` that is set but is not JDK 21+. Then `write_profile` sets `JAVA_HOME` to ours and writes it in the block, and prints nothing. `install_jdk` takes the same decision but prints the warning that locked decision D-04 requires ("JAVA_HOME points at ..., which is not JDK 21 or newer; installing the script's own JDK 21."). On a `--no-ghidra` run without `--with-android`, `install_jdk` never runs, so there is no warning at all.

The effect on the profile is larger than the session change. `remove_profile_block` deletes the old block and the new block is appended at the end of the file. A user who added `export JAVA_HOME=<jdk17>` after the block (for other work) had their line win before this rerun. After the rerun, the block comes last and overrides their line in every new shell. Before 02-06 this rerun left `JAVA_HOME` out of the block, so the user's line kept winning.

Reproduced (bash 3.2, `test.sh` brew stub, ledger `brew:openjdk@21`, profile = old block plus a user `export JAVA_HOME=".../jdk17"` after it, session `JAVA_HOME` = that JDK 17): `write_profile` exits 0 and prints only "Adding REA settings". The profile becomes the user's line followed by a block that exports our `JAVA_HOME`, and the session `JAVA_HOME` is now ours. This violates D-04 and the project rule that the machine is never altered silently.
**Fix:** Split the clause and warn when a set value is replaced, matching `install_jdk`:
```bash
if [ "${JAVA_HOME:-}" = "$ours" ]; then
  :
elif [ "$owned" = true ] && ! jdk_usable "${JAVA_HOME:-}" && jdk_usable "$ours"; then
  [ -z "${JAVA_HOME:-}" ] ||
    warn "JAVA_HOME points at $JAVA_HOME, which is not JDK 21 or newer; using the script's own JDK 21 at $ours."
else
  ours=""
fi
if [ -n "$ours" ]; then
  export JAVA_HOME="$ours"
  profile_exports+=("export JAVA_HOME=\"$ours\"")
fi
```
Add a `test.sh` case: ledger `brew:openjdk@21`, `export JAVA_HOME="$work/jdks/17"`, `write_profile` only. Expect the block to export ours and the output to contain `not JDK 21 or newer`.

### WR-02: Windows keeps a dead `JAVA_HOME` when the old Temurin folder is not fully removed, so CR-01 can come back

**File:** `rea-install-windows.ps1:204-207`
**Issue:** `$gone` is true only when the saved folder is missing (`Test-Path -LiteralPath $userJava -PathType Container`). Windows Installer removes the files it installed, but it does not remove a folder that still holds other files. That happens when files were in use during the upgrade (for example, Ghidra or an IDE was running the old JDK, so deletion waits for a reboot), or when a file was created after install (CDS `.jsa` archives, `hs_err_pid*.log`, a copied `cacerts`). In those cases the folder exists but has no `bin\java.exe`. The rule then keeps the persistent value and warns "leaving it as-is" on every rerun, which is the CR-01 symptom. The earlier review's suggested fix checked for `bin\java.exe` specifically for this reason. The implementation checks the folder instead.

Reproduced in pwsh with the `test.sh` driver stubs: the ledger has `env:JAVA_HOME`, the user value points at `leftover/jdk-21.0.4.7-hotspot` (which contains only `lib/`), and Temurin is first on PATH. Output: `JAVA_HOME is already set for your user to .../leftover/jdk-21.0.4.7-hotspot; leaving it as-is.` The session gets Temurin, but every new terminal and every agent started outside this session gets a `JAVA_HOME` with no Java in it.
**Fix:** Treat the saved value as dead when it has no `java.exe`. A JDK 17 the user chose has one, so WR-01/D-05 still hold:
```powershell
$userJava = Get-UserEnv 'JAVA_HOME'
$gone = $userJava -and -not (Test-Path -LiteralPath (Join-Path (Join-Path $userJava 'bin') 'java.exe') -PathType Leaf)
```
Update the `Set-UserEnv` comment (line 122) and the log text (line 130) to say "has no java.exe" instead of "no longer exists". Add a driver case with a leftover folder that has `lib/` but no `bin/java.exe`, and expect the `setx` line.

### WR-03: When the owned JDK no longer runs, a macOS `--no-ghidra` rerun either writes a dead `JAVA_HOME` or drops it silently, depending on the caller's shell

**File:** `rea-install-macos.sh:228`
**Issue:** The first clause, `[ "${JAVA_HOME:-}" = "$ours" ]`, accepts our path without checking that it runs. When `install_jdk` ran in this run (`jdk_chosen=true`), that check already happened. On a `--no-ghidra` rerun it did not happen. Take the ledger case `brew:openjdk@21` where the formula has since been removed (for example, the user removed Ghidra and then `openjdk@21` with brew):
- From a shell that sourced the old block (`JAVA_HOME` = ours), the block is rewritten with a `JAVA_HOME` that has no Java, and `rea setup` copies that dead value into the agent registrations.
- From a shell that did not source it, `JAVA_HOME` is dropped without a message.

This is the same machine state giving two different results, which is the defect class WR-03 was meant to close. Neither result warns. Reproduced with the `test.sh` brew stub and no JDK under the prefix: `export JAVA_HOME=<ours>` writes 1 `JAVA_HOME` line, and `unset JAVA_HOME` writes 0. Both exit 0 with no warning.
**Fix:** Outside `jdk_chosen`, require `jdk_usable "$ours"` for both clauses, and warn when the script owns the JDK but it does not run:
```bash
if [ "$jdk_chosen" = false ] && [ "$owned" = true ] && ! jdk_usable "$ours"; then
  warn "the script's $JDK_FORMULA at $ours does not run; JAVA_HOME is left out of $(profile_file). Rerun without --no-ghidra to reinstall it."
elif ...
```

## Info

### IN-01: `jdk_owned`'s profile probe matches any `export JAVA_HOME=` line, not only the script's block

**File:** `rea-install-macos.sh:156`, `160-163`; test at `test.sh:477-488`
**Issue:** The comment says `brew --prefix` runs "only when an old block exports a JAVA_HOME (IN-03)". But `grep -q '^export JAVA_HOME='` and the exact-match `grep -qxF` search the whole profile. Two results follow:
1. Many macOS users have `export JAVA_HOME=$(/usr/libexec/java_home -v 21)` in their profile. For them, both `install_ghidra` (with Ghidra already present) and every `write_profile` still require `brew --prefix openjdk@21`. Reproduced with a failing brew stub: `install_ghidra` dies with "brew --prefix failed". Real `brew --prefix` fails only for an unknown formula, so the risk is low. The IN-03 test cannot catch this, because none of its cases has a profile.
2. A user line identical to Homebrew's path counts as ownership, even though the script never chose that JDK. This is mostly harmless: the same value is written again, as in the accepted IN-103.

**Fix:** Search only inside the block: `sed -n "/^$PROFILE_BEGIN\$/,/^$PROFILE_END\$/p" "$profile" | grep ...` for both greps. Add an IN-03 case whose profile contains a user `export JAVA_HOME=...` line.

### IN-02: Dry runs on a machine without npm die at the REA CLI step (pre-existing, outside this phase)

**File:** `rea-install-macos.sh:308`, `rea-install-windows.ps1:266`
**Issue:** Both scripts run `npm prefix --global` directly, even in a dry run. On a Mac that has Homebrew but no Node, the dry run plans `brew install node` and then exits 127 at `rea_bin="$(npm prefix --global)/bin/rea"`, because a plain assignment passes the failure to `set -e`. On Windows without Node, `npm` is not recognized and `$ErrorActionPreference = 'Stop'` ends the dry run. This is not new in 02-06 or 02-07, and it is not in the AUDIT. It is listed only because the 02-07 dry-run work is near it.
**Fix:** In a dry run with no npm, use a placeholder prefix (as Linux does with `NPM_PREFIX`). For example, on macOS: `rea_bin="$( { npm prefix --global 2>/dev/null || { [ "$dry_run" = true ] && brew --prefix; }; } )/bin/rea"`. On Windows, guard with `Get-Command npm` and use the `$env:APPDATA\npm` default in a dry run.

---

_Reviewed: 2026-10-14T22:10:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
