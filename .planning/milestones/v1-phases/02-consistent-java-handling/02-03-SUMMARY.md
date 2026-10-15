---
phase: 02-consistent-java-handling
plan: 03
subsystem: installer
tags: [powershell, jdk, java_home, windows, winget, temurin, test.sh, pwsh]

requires:
  - phase: 02-consistent-java-handling
    provides: "jdk_usable bash predicate and its stub-JDK table (plan 02-01); mkjdk helper in test.sh"
provides:
  - "Test-JdkUsable([string]$Dir) in rea-install-windows.ps1: JDK 21+ via java -version, fails closed, function-local ErrorActionPreference"
  - "Install-Jdk reuses only a JDK 21+ JAVA_HOME, else warns, installs Temurin 21 and derives JAVA_HOME from the java on PATH"
  - "Session JAVA_HOME set before Set-UserEnv, which records env:JAVA_HOME for uninstall"
  - "pwsh driver: stub winget, fake Temurin, Update-SessionPath no-op, 16 new Windows JAVA-01/JAVA-02 checks"
affects: [03 DOCS-01 README known limitations, v2 VERI-02 real-Windows confirmation]

actuals:
  tokens: 2200
  tasks: 2
  commits: 2
plan_head_before: cc1b9dd8ce78e975819f7833dbc3b2d7a46a974e
plan_head_after: 42faa6fd4b226b81a864531dd8043ed9ccb834be

tech-stack:
  added: []
  patterns:
    - "Derive-then-check: after a package install, take the folder from the first java on the refreshed PATH and accept it only if the version predicate passes"
    - "Session first, persist second: $env:JAVA_HOME is assigned before Set-UserEnv because Set-UserEnv returns early when a user value exists"

key-files:
  created: []
  modified:
    - rea-install-windows.ps1
    - test.sh

key-decisions:
  - "Windows Install-Jdk derives JAVA_HOME from Get-Command java (first match) after Update-SessionPath and throws when that folder is not JDK 21+; it never reads or falls back to the Machine-scope JAVA_HOME (D-08)"
  - "Set-UserEnv is unchanged; Install-Jdk sets the session value itself first, so rea setup sees JDK 21 even when a different user JAVA_HOME is left in place (D-05)"
  - "Dry-run placeholder '<Temurin JAVA_HOME>' short-circuits a second Install-Jdk call in the same run, so there is no false warning and no second winget plan (D-09)"

patterns-established:
  - "pwsh driver isolates PATH-sensitive cases by saving and restoring $env:PATH, and finds the stub folder via Get-Command winget instead of assuming PATH order"

requirements-completed: [JAVA-01, JAVA-02]

coverage:
  - id: D1
    description: "Test-JdkUsable returns the same results as the bash jdk_usable table and leaves the script's ErrorActionPreference at Stop"
    requirement: JAVA-02
    verification:
      - kind: unit
        ref: "test.sh#JAVA-02 Windows Test-JdkUsable <label> x 10 (8, 17, 21, 21.0.5, 25-ea, picked-up, garbage, exit1, missing, empty)"
        status: pass
      - kind: unit
        ref: "test.sh#JAVA-02 Windows Test-JdkUsable keeps ErrorActionPreference"
        status: pass
    human_judgment: false
  - id: D2
    description: "Install-Jdk with a JDK 17 JAVA_HOME and a Temurin 21 first on PATH sets the session JAVA_HOME to that folder and records env:JAVA_HOME and winget:EclipseAdoptium.Temurin.21.JDK"
    requirement: JAVA-01
    verification:
      - kind: unit
        ref: "test.sh#JAVA-01 Windows Install-Jdk sets JAVA_HOME from the java on PATH and records it"
        status: pass
      - kind: other
        ref: "mutation: the pre-plan Install-Jdk (HEAD cc1b9dd) makes this check FAIL"
        status: pass
    human_judgment: false
  - id: D3
    description: "A JDK 21+ JAVA_HOME is reused with no winget call or ledger; a dry run sets the placeholder, records nothing, and a second call prints nothing"
    requirement: JAVA-02
    verification:
      - kind: unit
        ref: "test.sh#JAVA-02 Windows Install-Jdk reuses a JDK 21 JAVA_HOME"
        status: pass
      - kind: unit
        ref: "test.sh#JAVA-01 Windows Install-Jdk -DryRun sets the placeholder and records nothing"
        status: pass
    human_judgment: false
  - id: D4
    description: "Install-Jdk throws loudly, naming the folder, when the java on PATH is not JDK 21+, and throws 'java is not on PATH' when there is none"
    requirement: JAVA-01
    verification:
      - kind: unit
        ref: "test.sh#JAVA-01 Windows Install-Jdk throws when the java on PATH is not JDK 21+"
        status: pass
      - kind: unit
        ref: "test.sh#JAVA-01 Windows Install-Jdk throws when no java is on PATH"
        status: pass
    human_judgment: false
  - id: D5
    description: "On real Windows (PowerShell 5.1 and the Temurin MSI), the predicate parses java -version and the first java on the refreshed PATH is Temurin's"
    requirement: JAVA-01
    verification: []
    human_judgment: true
    rationale: "Assumptions A1 and A2 cannot be exercised on Unix pwsh 7 or in CI; deferred to v2 VERI-02."

duration: 3min
completed: 2026-10-14
status: complete
---

# Phase 2 Plan 03: Windows JDK 21 rule with a PATH-derived JAVA_HOME Summary

**On Windows, `Install-Jdk` now reuses `JAVA_HOME` only when it is JDK 21+. Otherwise it installs Temurin 21 through winget and derives the folder from the first `java` on the refreshed PATH. It checks that folder with the new `Test-JdkUsable`, sets it for the session first, then saves it with `Set-UserEnv`, which records `env:JAVA_HOME` for uninstall. It no longer depends on what the MSI did with the Machine-scope `JAVA_HOME`.**

## Performance

- **Duration:** about 3 min from the first edit (reading not counted)
- **Completed:** 2026-10-14T19:40:13Z
- **Tasks:** 2 of 2
- **Files modified:** 2

## Accomplishments

- `Test-JdkUsable([string]$Dir)` follows Test-NodeSupported. It requires `<dir>\bin\java.exe`, a zero exit from `java -version` and a quoted major version of 21 or more (`1.8` reads as 8). It sets `$ErrorActionPreference = 'Continue'` only inside the function and never prints the captured output.
- `Install-Jdk` steps, in order: return on the dry-run placeholder; reuse a usable `JAVA_HOME`; give the D-04 warning for an older one; `Install-Winget`; in a dry run, set the placeholder and return; `Update-SessionPath`; `Get-Command java -CommandType Application | Select-Object -First 1`; throw when java is missing or not JDK 21+; `$env:JAVA_HOME = $dir`; `Set-UserEnv 'JAVA_HOME' $dir`. The Machine-scope read and the old "JAVA_HOME was not set" throw are gone. `Set-UserEnv`, `Install-Winget` and `Update-SessionPath` are unchanged.
- test.sh: `mkjdk` also writes `bin/java.exe`. The Windows section adds a stub `winget` (list exits 1, everything else exits 0) and a fake Temurin 21. The driver gets `-Jdks`/`-Temurin` params and overrides `Update-SessionPath {}` (Pitfall 11). There are 16 new checks: 10 table rows, the ErrorActionPreference check, reuse, dry run, wrong java, no java and the JAVA-01 tracer case.

## Task Commits

1. **Task 1 (tracer): JDK 17 JAVA_HOME replaced by the PATH-derived Temurin and recorded** - `d69aca5` (Set the Windows JAVA_HOME from the installed Temurin)
2. **Task 2: Test-JdkUsable table, reuse, dry run, wrong java, no java** - `42faa6f` (Test the Windows JDK 21 rule in the pwsh driver)

## Files Created/Modified

- `rea-install-windows.ps1` - adds `Test-JdkUsable` and reworks `Install-Jdk`. The callers in steps 2 and 3 are unchanged.
- `test.sh` - `mkjdk` writes `java.exe`, plus the stub winget, the fake Temurin and the new pwsh driver cases

## Verification

- Phase gate: `exit: default=0 bash32=0 ubuntu=0` with no FAIL lines. The Mac had 73 passes and 2 Linux-only skips under both shells. ubuntu:24.04 had 47 passes and 10 skips (no pwsh there, so the Windows checks skip).
- Tracer gate: Task 1's `<verify>` passed before Task 2 started. A scratch copy running the pre-plan `Install-Jdk` makes the JAVA-01 tracer check FAIL.
- Mutation checks for Task 2, run on scratch copies. Removing the placeholder guard makes the dry-run check FAIL. Changing `-ge 21` to `-ge 17` makes three checks FAIL: the `17` table row, the wrong-java check and the JAVA-01 check.
- All acceptance criteria for both tasks pass. `Test-JdkUsable` is defined once. `Set-UserEnv 'JAVA_HOME'` appears once, right after `$env:JAVA_HOME = $dir`. There are no `GetEnvironmentVariable('JAVA_HOME'` reads. `Select-Object -First 1` is on the Get-Command java line. The D-04 sentence appears once. The diff touches no line in Set-UserEnv, Install-Winget or Update-SessionPath. The test.sh counts are 2, 1 and 1.
- I did not push, so the GitHub Actions `linux` and `macos` jobs have not run on these commits.

## Decisions Made

See key-decisions in the frontmatter. These are the plan's auto-mode resolutions, applied as written.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] "No java" case assumed the stub folder is first on PATH**
- **Found during:** Task 2
- **Issue:** pwsh 7 puts its own `$PSHOME` folder first on PATH. Setting PATH to "its first entry" therefore dropped the stubs, and `Install-Jdk` failed on a missing `winget` instead of on a missing `java`.
- **Fix:** The case sets PATH to the folder of the stub winget: `Split-Path (Get-Command winget -CommandType Application).Source`.
- **Files modified:** test.sh
- **Commit:** 42faa6f

**2. [Rule 2 - Missing check] Dry-run case did not assert the "second call is silent" truth**
- **Found during:** Task 2, while running mutations
- **Issue:** With the placeholder guard removed, the dry-run check still passed. The second call warns and plans winget again, but it still ends at the placeholder with no ledger. The must-have truth says a second call "neither warns nor plans a second winget install".
- **Fix:** The second call now runs as `@(Install-Jdk *>&1)`, and the check also asserts that its output is empty. Removing the guard now makes the check FAIL.
- **Files modified:** test.sh
- **Commit:** 42faa6f

**Note:** Task 2 has `tdd="true"`, but its tests could not fail first, because Task 1 delivered the behaviour they check. The mutation checks above stand in for RED. As the plan specifies, Task 2's tests went into one commit.

**Total deviations:** 2 auto-fixed (1 test bug, 1 missing assertion). **Impact:** test-only. The installer code matches the plan.

## Known Limitations (for Phase 3 DOCS-01)

- **Stale user `JAVA_HOME` after a Temurin upgrade (T-02-13, RESEARCH Pitfall 7, accepted).** Run 1 saves the user `JAVA_HOME` as `...\jdk-21.0.x-hotspot`. If `winget upgrade` later moves Temurin to a new folder, a rerun detects the dead path. It warns, derives the new folder and sets it for the session, so `rea setup` sees JDK 21. But `Set-UserEnv` will not replace an existing user value, even one the script recorded itself, and prints "JAVA_HOME is already set for your user to ...; leaving it as-is." New terminals keep the dead path until the user fixes it or runs uninstall and then install. The README Known limitations should say this. A future fix could let `Install-Jdk` overwrite the user value when the ledger already holds `env:JAVA_HOME`.
- **A different user-scope `JAVA_HOME`** (for example a JDK 17 the user set) is left in place with the same warning. The session gets Temurin; new terminals keep the user's value. This is D-05 as decided.
- **Another usable JDK 21+ first on PATH** after the install is saved instead of Temurin (T-02-09 residual). It still satisfies the rule.

## Assumptions Open for v2 VERI-02 (real Windows)

- **A1:** In Windows PowerShell 5.1, `"$_"` of a redirected native-stderr ErrorRecord is assumed to equal the raw `java -version` line. This is unverified: CI and this Mac have only pwsh 7, where stderr is not wrapped. If A1 is wrong, `Test-JdkUsable` always returns false on 5.1. Every run then installs Temurin and throws "the java on PATH is in <dir>, which is not JDK 21 or newer". That failure is loud, not silent.
- **A2:** Right after a fresh winget Temurin install, the first `java` on the refreshed PATH is assumed to be Temurin's `bin\java.exe`. The MSI's `ADDLOCAL=ALL` prepends to Machine PATH, and `Update-SessionPath` puts Machine before User. If another JDK or Oracle's `javapath` shim comes first and is not 21+, D-08 throws and names that folder.
- **Rerun with an equal user value (backstop truth):** when the user `JAVA_HOME` already equals the derived folder, `Set-UserEnv` returns without a warning or a new ledger line. This is true by code reading only, because user scope is a no-op on Unix pwsh.

## Issues Encountered

None.

## Known Stubs

None.

## Next Phase Readiness

Phase 2 is complete: all three plans have summaries. JAVA-01 and JAVA-02 are implemented on Linux, macOS and Windows. Next steps are phase verification, then Phase 3 (MAC-01/02, DOCS-01). DOCS-01 must take in the Known Limitations from 02-02 and from this plan.

## Self-Check: PASSED

- FOUND: rea-install-windows.ps1, test.sh
- FOUND: d69aca5, 42faa6f (ancestors of HEAD)
