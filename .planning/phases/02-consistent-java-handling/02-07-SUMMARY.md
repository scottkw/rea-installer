---
phase: 02-consistent-java-handling
plan: 07
subsystem: installer
tags: [powershell, windows, jdk, java_home, dry-run, test.sh, review-disposition, gap-closure]
status: complete

requires:
  - phase: 02-consistent-java-handling
    provides: "Windows Install-Jdk, Install-Winget, Set-UserEnv -Replace (02-05); 02-06 fix commits 2fd5825 and d4021ad"
provides:
  - "Windows Install-Jdk replaces an owned user JAVA_HOME only when its folder no longer exists (WR-01, G-02-2)"
  - "Set-UserEnv replace log says the old folder no longer exists, not that the script set it"
  - "Install-Winget returns under -DryRun before Add-Record and Update-SessionPath (WR-02, G-02-3)"
  - "Observable Update-SessionPath stub ($PathRefreshed) in the pwsh driver"
  - "02-REVIEW-DISPOSITION.md with all 26 findings dispositioned, open 0 (G-02-4)"
affects: [02 re-verification, VERI-02]

actuals:
  tokens: 3552
  tasks: 3
  commits: 3
plan_head_before: 1c2bc0a27f5ee795b66b5801583e0392a84703e7
plan_head_after: 43cc7958b4f2ccceccedfeeb05370bdb22032bc2

tech-stack:
  added: []
  patterns:
    - "Replace a persistent user value only when the ledger owns it AND the folder it names is gone"
    - "Driver stubs set a script-scope flag so a test can assert the stubbed call never happened"

key-files:
  created: []
  modified:
    - rea-install-windows.ps1
    - test.sh
    - .planning/phases/02-consistent-java-handling/02-REVIEW-DISPOSITION.md

key-decisions:
  - "Windows replaces a user JAVA_HOME only when the ledger holds env:JAVA_HOME and Test-Path -PathType Container on the saved value is false; an existing folder is kept even if the script set the variable earlier (WR-01, D-05)"
  - "Restored review decisions use 3-digit ids WR-101..WR-104 and IN-101..IN-105 so a re-review numbering from 01 cannot collide with them"

requirements-completed: [JAVA-01]

duration: 3min
completed: 2026-10-15
---

# Phase 2 Plan 07: Windows JAVA_HOME replace rule, dry-run PATH, and review triage Summary

**A Windows rerun now overwrites the saved user JAVA_HOME only when the folder it points at is gone, and says that. A Windows dry run no longer refreshes the caller's session Path. All 26 Phase 2 review findings have a disposition the gate keeps: 13 fixed, 13 deferred-accepted, 0 open.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-10-15T00:47:08Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- `Install-Jdk` computes `$replace` from three facts: the user value is non-empty, its folder does not exist, and the ledger holds `env:JAVA_HOME`. `-and` short-circuits, so `Test-Path` never sees an empty value under StrictMode.
- `Set-UserEnv` logs `Replacing JAVA_HOME for your user (was ..., a folder that no longer exists).`
- `Install-Winget` has `if ($DryRun) { return }` right after the `winget install` step, so a dry run never reaches `Add-Record` or `Update-SessionPath`.
- The pwsh driver gained the WR-01 case (owned ledger plus an existing user JDK), tighter CR-01 log checks, and the `$PathRefreshed` dry-run check.
- The disposition record's re-review rows are filled in, and the nine decisions that the gate dropped in commit 4d8a918 are back under new ids.

## Task Commits

1. **Task 1 (tracer): Keep a Windows JAVA_HOME the user repointed at an existing JDK** - `6b0fd4f`
2. **Task 2: Keep a Windows dry run from refreshing the session PATH** - `8d0cbb5`
3. **Task 3: Record Phase 2 re-review dispositions and restore dropped ones** - `43cc795`

## Red evidence

Task 1, after the driver edits and before the fix (`./test.sh`):

```
FAIL: JAVA-01 Windows Install-Jdk replaces a stale user JAVA_HOME it set earlier
FAIL: JAVA-01 Windows Install-Jdk keeps an existing user JAVA_HOME even when it set one earlier
88 passed, 2 failed, 2 skipped
```

Task 2, after the stub and check and before the fix:

```
FAIL: JAVA-01 Windows Install-Jdk -DryRun leaves the session PATH alone
90 passed, 1 failed, 2 skipped
```

Green after each fix: 90 passed, then 91 passed, with 0 failed. The Install-Winget awk order check prints `order ok`. `grep -c PathRefreshed test.sh` gives 4.

## Phase gate

```
exit: default=0 bash32=0 ubuntu=0
```

No FAIL lines. Default and /bin/bash 3.2: 91 passed, 2 skipped. ubuntu:24.04: 59 passed, 11 skipped (it has no pwsh, so the Windows cases skip). The dispositions check prints `dispositions ok`.

## Files Created/Modified

- `rea-install-windows.ps1` - Install-Jdk replace rule, Set-UserEnv log text and `-Replace` comment, Install-Winget dry-run return
- `test.sh` - pwsh driver: WR-01 case, tighter CR-01 assertions, observable Update-SessionPath stub, dry-run PATH check
- `.planning/phases/02-consistent-java-handling/02-REVIEW-DISPOSITION.md` - 26 rows, open 0

## Decisions Made

- `Install-Jdk` still sets `$env:JAVA_HOME` before it calls `Set-UserEnv`, so the session gets Temurin even when the user value is kept.
- Disposition sources: WR-01 and WR-02 cite 6b0fd4f and 8d0cbb5. WR-03 and IN-03 cite 2fd5825. WR-04 and IN-04 cite d4021ad. IN-05 cites d4021ad and 8d0cbb5. IN-01 and IN-02 are accepted as the pre-existing no-brew dry-run path. WR-102 notes that its dry-run case is now fixed as WR-02.

## Deviations from Plan

None. The plan ran as written.

## Issues Encountered

None.

## Threat Flags

None. T-02-27 and T-02-28 are mitigated as planned and covered by the new driver checks and the awk order check. T-02-29 is covered by the dispositions check.

## Next Phase Readiness

- Phase 2 gap closures G-02-2, G-02-3 and G-02-4 are done. The phase is ready for re-verification.
- Confirmation on a real Windows machine is still deferred to VERI-02.

## Self-Check: PASSED

- FOUND: rea-install-windows.ps1, test.sh, 02-REVIEW-DISPOSITION.md
- FOUND commits: 6b0fd4f, 8d0cbb5, 43cc795
