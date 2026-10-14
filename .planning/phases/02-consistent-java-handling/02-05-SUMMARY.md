---
phase: 02-consistent-java-handling
plan: 05
subsystem: installer
tags: [powershell, windows, jdk, java_home, temurin, dry-run, test.sh, review-disposition, gap-closure]

requires:
  - phase: 02-consistent-java-handling
    provides: "Windows Test-JdkUsable, Install-Jdk, Set-UserEnv (02-03); WR-07/08/09 fixes (02-04)"
provides:
  - "Windows Get-UserEnv seam: the one reader of User-scope variables, overridden by the pwsh driver"
  - "Windows Set-UserEnv -Replace: overwrites an existing user value and logs 'Replacing <NAME> for your user (was <old>, set by this script earlier).'"
  - "Windows Install-Jdk passes -Replace only when the ledger holds env:JAVA_HOME (CR-01)"
  - "Windows $JdkPlanned script-scope flag replaces the '<Temurin JAVA_HOME>' session placeholder (WR-03)"
  - "Set-UserEnv sets no session variable under -DryRun (WR-03)"
  - "Four new or reworked pwsh driver checks and a ledger reset before the records check (WR-10, mutation-proven)"
  - "02-REVIEW-DISPOSITION.md: 6 fixed, 11 deferred with 'accepted 2026-10-14:' reasons, open 0"
affects: [02 re-verification, 03 DOCS-01 known limitations, VERI-02 real-Windows check]

actuals:
  tokens: 3687
  tasks: 3
  commits: 3
plan_head_before: 1e86663af77b14d2729af5bbd55883638e7b8b0a
plan_head_after: 4d8a91891964886e23c3fa6047e87e627872df50

tech-stack:
  added: []
  patterns:
    - "Ownership from the ledger: a persistent user value is replaced only when the script's own env:<NAME> record shows it set it"
    - "Dry-run state lives in a script-scope flag, never in the caller's environment"
    - "A single reader function for a platform scope the test host lacks, overridden by the dot-sourcing driver"

key-files:
  created: []
  modified:
    - rea-install-windows.ps1
    - test.sh
    - .planning/phases/02-consistent-java-handling/02-REVIEW-DISPOSITION.md

key-decisions:
  - "Windows rerun replaces a user JAVA_HOME only when the ledger holds env:JAVA_HOME (CR-01, user decision 3); a value the script never set keeps D-05's warn-and-leave"
  - "A Windows -DryRun changes no session variable: $JdkPlanned marks the planned JDK, and Set-UserEnv returns before Set-Item (WR-03, supersedes D-09's placeholder)"
  - "Accepted review findings are stored as 'deferred' with an 'accepted 2026-10-14:' Source cell, because the disposition gate resets any other value to open"

patterns-established:
  - "Get-UserEnv seam: Unix pwsh cannot hold a User-scope value, so the driver plays it through $env:REA_TEST_USER_<NAME>"

requirements-completed: [JAVA-01]

coverage:
  - id: D1
    description: "Windows rerun replaces a stale user JAVA_HOME the script set earlier, and leaves one it did not set (CR-01)"
    requirement: JAVA-01
    verification:
      - kind: unit
        ref: "test.sh#JAVA-01 Windows Install-Jdk replaces a stale user JAVA_HOME it set earlier"
        status: pass
      - kind: unit
        ref: "test.sh#JAVA-01 Windows Install-Jdk leaves a user JAVA_HOME it did not set"
        status: pass
    human_judgment: false
  - id: D2
    description: "Windows -DryRun leaves the caller's session JAVA_HOME and other variables untouched and records nothing (WR-03)"
    requirement: JAVA-01
    verification:
      - kind: unit
        ref: "test.sh#JAVA-01 Windows Install-Jdk -DryRun leaves JAVA_HOME unchanged and records nothing"
        status: pass
      - kind: unit
        ref: "test.sh#JAVA-01 Windows Set-UserEnv -DryRun leaves the session unchanged"
        status: pass
    human_judgment: false
  - id: D3
    description: "The winget-ledger assertion fails when Install-Winget does not record the install (WR-10)"
    requirement: JAVA-01
    verification:
      - kind: unit
        ref: "test.sh#JAVA-01 Windows Install-Jdk sets JAVA_HOME from the java on PATH and records it"
        status: pass
      - kind: mutation
        ref: "Task 2 mutation command (Add-Record winget line deleted from a copy) printed 'mutation caught'"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every Phase 2 review finding has a gate-preserved disposition; open is 0"
    requirement: JAVA-01
    verification:
      - kind: command
        ref: "Task 3 dispositions command printed 'dispositions ok'"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-10-14
status: complete
---

# Phase 2 Plan 05: Windows JAVA_HOME rerun and dry-run fixes, review dispositions Summary

**A Windows rerun now replaces a dead user JAVA_HOME that the installer's own ledger says it set, an in-process -DryRun no longer changes the caller's session, the winget-ledger test is proven able to fail, and all 17 Phase 2 review findings have a recorded disposition (6 fixed, 11 accepted, 0 open).**

## Performance

- **Duration:** about 4 min of execution (plus reading)
- **Completed:** 2026-10-14
- **Tasks:** 3 (1 tracer, 2 auto; Tasks 1 and 2 TDD)
- **Files modified:** 3

## Accomplishments

- CR-01: `Install-Jdk` sets `$owned` from an exact `env:JAVA_HOME` line in `$StateFile` and calls `Set-UserEnv 'JAVA_HOME' $dir -Replace:$owned`. After a Temurin upgrade, a rerun prints `setx JAVA_HOME "<new folder>"` instead of "leaving it as-is". A user value the script did not set is still kept with the warning, and only the session is pointed at Temurin. The Machine scope and every JDK folder are untouched.
- `Get-UserEnv` is now the only place that reads User-scope variables, so the pwsh driver can play a saved user value on Unix pwsh, which has no User scope.
- WR-03: `$JdkPlanned` is the dry-run marker. A second `Install-Jdk` in the same dry run prints nothing, `$env:JAVA_HOME` keeps the caller's value, and `Set-UserEnv` prints its setx line but sets nothing under `-DryRun`.
- WR-10: the records check starts from an empty ledger. A mutation run proves it fails when the winget record is missing.
- Disposition record: CR-01, WR-03 and WR-10 are fixed in 02-05. WR-07, WR-08 and WR-09 are fixed in 02-04. The other eleven are `deferred`, each with its `accepted 2026-10-14:` reason. `open: 0`, `total: 17`.

## Task Commits

1. **Task 1 (tracer): repair a stale Windows JAVA_HOME the installer set earlier** - `bccc843`
2. **Task 2: keep a Windows dry run from changing the session** - `e0e8d34`
3. **Task 3: record Phase 2 review dispositions** - `4d8a918`

Commit messages follow the project convention in `.claude/CLAUDE.md` (short imperative sentence, no prefix), which takes precedence over the GSD `type(phase-plan):` form.

## Red evidence

Each was seen with the new tests in place and before the production fix.

Task 1, `./test.sh` after the `Get-UserEnv` seam and before `-Replace`:

```
FAIL: JAVA-01 Windows Install-Jdk replaces a stale user JAVA_HOME it set earlier
PASS: JAVA-01 Windows Install-Jdk leaves a user JAVA_HOME it did not set
```

The failing case's output showed the CR-01 bug itself: `JAVA_HOME is already set for your user to .../win/gone/jdk-21.0.4.7-hotspot; leaving it as-is.`

Task 2, `./test.sh` before the `$JdkPlanned` and `Set-UserEnv` reorder:

```
FAIL: JAVA-01 Windows Install-Jdk -DryRun leaves JAVA_HOME unchanged and records nothing
FAIL: JAVA-01 Windows Set-UserEnv -DryRun leaves the session unchanged
```

WR-10 mutation, Task 2 verify (copy of the scripts with `Add-Record "winget:$Id"` deleted):

```
mutation caught
FAIL: JAVA-01 Windows Install-Jdk sets JAVA_HOME from the java on PATH and records it
```

That was the only FAIL line in the mutated run.

## Verification

- Task 1 verify: pass (all six named checks PASS, no FAIL line). The tracer gate (end-of-phase, automated-only verify) re-ran it before Task 2.
- Task 2 verify: pass. Order check printed `order ok`. Mutation command printed `mutation caught`.
- Task 3 verify: `dispositions ok`. 6 `disposition: fixed`, 11 `disposition: deferred`, `total: 17`.
- Phase gate: `exit: default=0 bash32=0 ubuntu=0` and no `FAIL:` line. The local runs gave 83 passed, 0 failed, 2 skipped. ubuntu:24.04 gave 54 passed, 0 failed, 10 skipped, because that container has no pwsh, so the Windows checks SKIP there.
- Acceptance greps: all pass. `function Get-UserEnv` 1, `GetEnvironmentVariable($Name, 'User')` 1, `[switch]$Replace` 1, `-Replace:$owned` 1, `'env:JAVA_HOME'` 1, `REA_TEST_USER_` 6 in test.sh, `Temurin JAVA_HOME>` 0 in both files, non-comment `JdkPlanned` lines 3. The first diff hunk in `rea-install-windows.ps1` starts at line 35, so the help block (lines 1-16) is unchanged.

## Decisions Made

See `key-decisions` in the frontmatter.

## Deviations from Plan

None. The plan was executed as written.

One addition within the plan's scope: the two new CR-01 cases print their captured output with `Write-Host` after `Report`. test.sh shows it only when a check fails, which is how the red output above was read.

## Issues Encountered

None.

## Known limitations (unchanged, noted for DOCS-01)

- WR-05 and T-02-22 (accepted): the ledger stores only the variable name. A rerun therefore also replaces an owned `JAVA_HOME` that the user later repointed at a non-JDK-21 folder. A usable JDK 21+ `JAVA_HOME` is reused and never reaches the replace path.
- Real-Windows confirmation of CR-01 and WR-03 is still deferred to VERI-02. On Unix pwsh, the User-scope write is a silent no-op, and the driver stands in for the User-scope read.

## Next Phase Readiness

Phase 2 now has a SUMMARY for all 5 plans and no `open` review finding. It is ready for re-verification.

## Self-Check: PASSED

- FOUND: rea-install-windows.ps1, test.sh, .planning/phases/02-consistent-java-handling/02-REVIEW-DISPOSITION.md
- FOUND: bccc843, e0e8d34, 4d8a918 (ancestors of HEAD)
- Commits measured: `git rev-list --count 1e86663..HEAD` = 3
