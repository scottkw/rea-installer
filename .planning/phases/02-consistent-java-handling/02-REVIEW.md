---
phase: 02-consistent-java-handling
reviewed: 2026-10-14T21:26:58Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - rea-install-linux.sh
  - rea-install-macos.sh
  - rea-install-windows.ps1
  - test.sh
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 2: Code Review Report (re-review after gap closure 02-04 and 02-05)

**Reviewed:** 2026-10-14T21:26:58Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This re-review covers the diff `6cad0bef..HEAD` for the four source files: the gap-closure fixes for WR-07, WR-08, WR-09 (plan 02-04) and CR-01, WR-03, WR-10 (plan 02-05). Earlier findings that 02-REVIEW-DISPOSITION.md lists as accepted are not raised again. The one exception is WR-01 below: the CR-01 fix makes the accepted WR-05 limitation worse.

Baseline: `./test.sh` passes on macOS (83 passed, 0 failed, 2 skipped). `shellcheck` is clean on all three bash files and `bash -n` passes under `/bin/bash` 3.2. Every defect below was reproduced in a scratch sandbox (bash 3.2 or pwsh with the same stubs `test.sh` uses), not inferred.

Status of each fix:

| Prior finding | Verdict |
|---|---|
| CR-01 (Windows stale `JAVA_HOME`) | The stale case is fixed, but the fix now replaces any user value whenever the ledger has `env:JAVA_HOME`, including a JDK the user chose on purpose. See WR-01. |
| WR-03 (dry run changes the session) | `JAVA_HOME` and `Set-UserEnv` are fixed. `Install-Winget` still rewrites the session `Path` during a dry run. See WR-02. |
| WR-07 (`jdk_home` hides a missing brew) | Fixed. `die` reaches `set -e` at every call site. The dry-run fallback is only partly reachable and its warning repeats. See IN-01 and IN-02. |
| WR-08 (macOS rerun depends on the caller's environment) | Fixed for the Ghidra path only. The `--no-ghidra` rerun still depends on the caller's environment. See WR-03. |
| WR-09 (broken Linux JDK blocks every rerun) | Fixed: a broken `~/.rea-installer/jdk` is replaced, and an unexpected archive layout no longer becomes the trusted JDK. The error message's recovery advice is wrong. See WR-04. |
| WR-10 (Windows ledger assertion cannot fail) | Fixed: the ledger is reset before the final case. |

No critical issues. The new code is Bash 3.2 safe. It sends every new side effect through `run`/`record`, or guards it with `$DryRun`, except the `Path` case in WR-02.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: The CR-01 fix overwrites a `JAVA_HOME` the user chose, and says the script set it

**File:** `rea-install-windows.ps1:200-202` (with `Set-UserEnv` at `121-134`, message at `128`)
**Issue:** `$owned` is true whenever the ledger has `env:JAVA_HOME`. The ledger has that line after any earlier successful install. `-Replace:$owned` then replaces whatever the user value is now, not only the dead Temurin folder that CR-01 described. Example: after installing REA, the user points their user `JAVA_HOME` at a JDK 17 for other work. On the next `install` (the session `JAVA_HOME` is JDK 17, so `Test-JdkUsable` fails), the script replaces that persistent value with Temurin. It also logs a false reason:

```
==> Replacing JAVA_HOME for your user (was ...\jdk17, set by this script earlier).
  > setx JAVA_HOME "...\temurin"
```

I reproduced this in pwsh with the `test.sh` driver stubs: a ledger containing `env:JAVA_HOME`, a user value pointing at an existing JDK 17, and Temurin first on PATH. Two problems follow:
- It breaks locked decision D-05, which keeps a user-set Windows `JAVA_HOME` (the reason WR-04 was accepted).
- It extends the accepted WR-05 limitation (the ledger stores only the variable name) from uninstall to every rerun. Before this fix, the worst case was that uninstall deleted the user's value. Now each rerun overwrites it too.

The CR-01 test (`test.sh:556-569`) covers only a user value pointing at a deleted folder, so it cannot tell "replace a stale value we set" from "replace any value".
**Fix:** Replace only when the saved value is a dead install, which is exactly the CR-01 case (the Temurin upgrade removed the folder):
```powershell
$userJava = Get-UserEnv 'JAVA_HOME'
$stale = $userJava -and -not (Test-Path -LiteralPath (Join-Path (Join-Path $userJava 'bin') 'java.exe') -PathType Leaf)
$owned = $stale -and (Test-Path $StateFile) -and (@(Get-Content $StateFile) -contains 'env:JAVA_HOME')
$env:JAVA_HOME = $dir
Set-UserEnv 'JAVA_HOME' $dir -Replace:$owned
```
Add a test where the ledger has `env:JAVA_HOME`, `REA_TEST_USER_JAVA_HOME` points at the existing `$Jdks/17`, and the expected result is "leaving it as-is" with no `setx`. Recording the value (`env:JAVA_HOME=<dir>`) would be stricter, but it changes the ledger format on all three scripts.

### WR-02: A Windows dry run still replaces the caller's session `Path`

**File:** `rea-install-windows.ps1:104-113` (`Update-SessionPath` at `112`); the test hides it at `test.sh:473`
**Issue:** The WR-03 fix (commit e0e8d34, "Keep a Windows dry run from changing the session") moved `Set-Item env:` below the `$DryRun` check and replaced the `JAVA_HOME` placeholder. But `Install-Winget` still calls `Update-SessionPath` without checking `$DryRun`. `Invoke-Step` only prints in a dry run, and `Add-Record` is a no-op, but the next line sets `$env:Path` to Machine;User anyway. Any dry run that plans a winget install hits this path (Node.js, Temurin through `Install-Jdk`, Platform Tools, Rizin, WinLibs). Run in-process as the header shows (`.\rea-install-windows.ps1 install -DryRun`), it drops every session-only `Path` entry from the user's terminal, such as an activated venv, fnm's Node, or pwsh 7's `$PSHOME`. Reproduced: with `$DryRun = $true` and `$env:Path = 'C:\session-only\venv\Scripts;C:\Machine'`, `Install-Winget 'OpenJS.NodeJS.LTS'` leaves `$env:Path` as `;` on Unix pwsh, and on Windows it would be Machine;User. The test driver stubs `Update-SessionPath` to an empty function (`test.sh:473`), so the new "-DryRun leaves the session unchanged" checks cannot see this. WR-02 in the earlier review (accepted) covers real runs; this is the dry-run case, which the project's "dry-run must not change anything" rule covers.
**Fix:**
```powershell
    Invoke-Step winget @('install', '--id', $Id, '--exact', '--silent',
                         '--accept-package-agreements', '--accept-source-agreements')
    if ($DryRun) { return }
    Add-Record "winget:$Id"
    Update-SessionPath
```
In the driver, have the stubbed `Update-SessionPath` set a flag (`$script:PathRefreshed = $true`), and assert the flag stays `$false` after the dry-run `Install-Jdk` case.

### WR-03: On a macOS `--no-ghidra` rerun, the profile's `JAVA_HOME` still depends on the caller's environment

**File:** `rea-install-macos.sh:211-219` (ownership check only at `193-200`)
**Issue:** The WR-08 fix moved the ownership decision (`jdk_owned`) into `install_ghidra`. `write_profile` still keeps `JAVA_HOME` only when the caller's environment already holds our path. Take a rerun such as `install --no-ghidra --with-extras` after a full first install (Homebrew Ghidra installed, ledger has `brew:openjdk@21`, block exports our `JAVA_HOME`). `install_ghidra` and `install_jdk` never run, so the result depends on the shell:
- From a terminal that sourced the block, `JAVA_HOME` is kept.
- From the same terminal as run 1, or one where a later line overrides `JAVA_HOME`, the block is rewritten without it. No warning is printed, and `rea setup` then registers agents with no `JAVA_HOME`.

Reproduced: a ledger with `brew:openjdk@21`, a block containing our `export JAVA_HOME=...`, `unset JAVA_HOME; with_ghidra=false; profile_exports+=(...); write_profile` leaves a block with only `REA_OBJDUMP_COMMAND`. Linux gives the same answer every time: its loop unsets every `$STATE_DIR` setting and always rewrites the block, so this rerun always drops `JAVA_HOME` there. On macOS, the same flags and machine state give two different results, which is the defect WR-08 described. The comment at `rea-install-macos.sh:212` ("a rerun that skips install_jdk keeps ours (JAVA-04)") is true only when the environment cooperates.
**Fix:** Make the decision depend on what was installed, in one place. Either keep our path whenever we own it:
```bash
write_profile() {
  local ours
  ours="$(jdk_home)"
  if [ "${JAVA_HOME:-}" = "$ours" ] || { [ -z "${JAVA_HOME:-}" ] && jdk_owned "$ours" && jdk_usable "$ours"; }; then
    export JAVA_HOME="$ours"
    profile_exports+=("export JAVA_HOME=\"$ours\"")
  fi
  ...
```
Or match Linux and write `JAVA_HOME` only when `install_jdk` chose ours in this run, using a run-local flag set at the end of `install_jdk`. Add a test for the `with_ghidra=false` rerun with `JAVA_HOME` unset.

### WR-04: The Linux layout-mismatch error says "rerun", but a rerun downloads and fails the same way

**File:** `rea-install-linux.sh:360-364` (with `unpack` at `255`)
**Issue:** The new check catches the case its comment names: `bin/java` one level deeper because Adoptium's `release_name` does not match the archive's top folder. Then it removes the folder and dies with "rerun to download it again." That mismatch is deterministic for a given release. `unpack` has already deleted the archive (`run rm -rf "$staging" "$archive"`), so every rerun downloads the ~190 MB tarball again, unpacks it into the same nested layout, and dies with the same message. Until the next Temurin release, the user cannot get past this step, and the message points them at the one action that cannot help. Removing the folder fixed the earlier problem (a broken folder becoming the trusted JDK), but this case still never recovers.
**Fix:** Handle the anticipated layout instead of dying on it:
```bash
if [ ! -x "$dir/bin/java" ]; then
  local inner
  for inner in "$dir"/*/; do [ -x "${inner}bin/java" ] && break; inner=""; done
  if [ -n "$inner" ]; then
    run mv "${inner%/}" "$STATE_DIR/jdk"; run rm -rf "$dir"
  else
    run rm -rf "$dir"
    die "the Temurin archive has no bin/java under $dir; report this, since rerunning repeats the same download."
  fi
else
  run mv "$dir" "$STATE_DIR/jdk"
fi
```
At a minimum, change the message so it does not promise that a rerun recovers.

## Info

### IN-01: The WR-07 dry-run fallback is unreachable on most Macs without Homebrew

**File:** `rea-install-macos.sh:260`, `283` (fallback at `144-147`)
**Issue:** A dry run without brew and without a supported Node dies at step 3 with `brew: command not found`: `PATH="$(brew --prefix)/bin:$PATH"` passes the substitution's exit status to `set -e`. That happens before step 4 can use the new default-prefix fallback. With `--with-extras`, step 6 (`$(brew --prefix binutils)`, confirmed to stop Bash 3.2) dies the same way. The fallback only helps when Node is already supported and extras are off. This code predates the phase, but the WR-07 fix and its test (`test.sh:414-423`, which calls `install_jdk` directly) suggest the no-brew dry run now works end to end.
**Fix:** Move the default-prefix logic into a shared `brew_prefix [formula]` helper and use it at lines 260 and 283 too.

### IN-02: The dry-run fallback warning prints once per `jdk_home` call

**File:** `rea-install-macos.sh:146`
**Issue:** `install_ghidra`, `install_jdk` (twice with `--with-android`) and `write_profile` each call `jdk_home`, so a no-brew dry run prints "brew not found; the dry-run plan assumes ..." four times (reproduced). Each call runs in a `$(...)` subshell, so a flag set inside `jdk_home` cannot stop the repeats.
**Fix:** Compute the dry-run prefix once, for example in `do_install` after step 2, into a global that `jdk_home` reads. Or warn from the caller of the first `jdk_home` call.

### IN-03: `install_ghidra` now requires `brew --prefix openjdk@21` even when Ghidra is already present and no JDK is owned

**File:** `rea-install-macos.sh:193-200`
**Issue:** `ours="$(jdk_home)"` runs before the `ghidraRun` check. A user who already has Ghidra and never let the script install `openjdk@21` used to skip all JDK logic. Now that run dies if `brew --prefix openjdk@21` fails (for example, the formula is unavailable with `HOMEBREW_NO_INSTALL_FROM_API` and no core tap). The risk is low (real `brew --prefix` fails only for an unknown formula, as verified), but the dependency is new and not needed for the ledger branch.
**Fix:** Check the ledger first and call `jdk_home` only when the profile clause needs it, or when taking the install branch.

### IN-04: An environmental `java -version` failure makes every Linux rerun delete and download the JDK again

**File:** `rea-install-linux.sh:343-347`, `367`
**Issue:** `jdk_usable` treats any non-zero `java -version` as a broken install. If the environment is the cause, for example an invalid `JAVA_TOOL_OPTIONS`/`_JAVA_OPTIONS` or a `noexec` home, the new branch deletes a good `~/.rea-installer/jdk` and downloads it again. Line 367 then dies with "does not run" and shows nothing from `java`, so the user cannot see why. Each rerun repeats the download.
**Fix:** In the final `die`, include the output of `"$STATE_DIR/jdk/bin/java" -version 2>&1 | head -3`. Optionally, before removing the folder, check whether `JAVA_TOOL_OPTIONS`/`_JAVA_OPTIONS` is set and say so.

### IN-05: Gaps in test coverage for the new branches

**File:** `test.sh:291-327`, `516-590`
**Issue:**
- No test covers the empty-`release` guard (`rea-install-linux.sh:358`), whose comment says it prevents `rm -rf $TOOLS_DIR`.
- No test has an owned ledger plus a user `JAVA_HOME` that still exists (WR-01).
- The dry-run `Path` refresh is not tested (WR-02).
- The macOS `--no-ghidra` rerun is not tested (WR-03).

**Fix:** Add a node stub that prints only `link sha` and assert the `die` with `$TOOLS_DIR` still present. Add the cases described under WR-01 to WR-03.

---

_Reviewed: 2026-10-14T21:26:58Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
