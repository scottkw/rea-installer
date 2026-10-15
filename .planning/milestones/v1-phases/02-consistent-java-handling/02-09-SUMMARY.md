---
phase: 02-consistent-java-handling
plan: 09
subsystem: installer-linux-windows
tags: [bash, powershell, linux, windows, java, jdk, uat-gap, review-disposition]
status: complete

requires:
  - phase: 02-consistent-java-handling
    provides: "02-08 macOS fixes (3c1259d, e9e01f1) cited in the disposition record; Linux install_jdk self-check and Windows Install-Jdk replace rule from 02-02..02-07"
provides:
  - "Linux install_jdk die message drops java -version lines starting 'Picked up' (G-02-1, T-02-02)"
  - "Windows Install-Jdk treats a saved JAVA_HOME as dead when it has no bin\\java.exe, not only when its folder is gone (G-02-4, WR-02)"
  - "02-REVIEW-DISPOSITION.md at open: 0, total: 31"
affects: [02-10, VERI-02, DOCS-01]

actuals:
  tokens: 2436
  tasks: 3
  commits: 5
plan_head_before: ef74f3eaed87b0dbf964068e7fc7cd71ab32a1c9
plan_head_after: 16d17e4b5468b5f6b3d64eaa0bb59476eaa27dea

tech-stack:
  added: []
  patterns:
    - "Filter java -version output with grep -v '^Picked up' inside the die argument; the substitution's exit status never stops die"

key-files:
  created: []
  modified:
    - rea-install-linux.sh
    - rea-install-windows.ps1
    - test.sh
    - .planning/phases/02-consistent-java-handling/02-REVIEW-DISPOSITION.md

key-decisions:
  - "Linux install_jdk error: Picked up lines are removed before head -3 so proxy credentials are never printed and the real JVM error stays visible (G-02-1)"
  - "Windows Install-Jdk: a ledger-owned user JAVA_HOME is replaced when its bin\\java.exe is not a file; a value holding a JDK is still kept (G-02-4, WR-02, D-05)"
  - "Review IN-02 (no-npm dry-run dies at the REA CLI step) deferred as accepted: pre-existing, outside phase scope, backlog 999.1"

patterns-established:
  - "RED check commit before each GREEN fix commit, in the project's plain sentence-case commit style"

requirements-completed: [JAVA-01, JAVA-02]

duration: 3 min
completed: 2026-10-14

coverage:
  - id: D1
    description: "Linux install_jdk 'does not run' error hides Picked up lines, shows the JVM error, and still stops the install (G-02-1)"
    requirement: JAVA-02
    verification:
      - kind: integration
        ref: "test.sh#JAVA-02 Linux install_jdk hides Picked up lines when its JDK does not run"
        status: pass
      - kind: integration
        ref: "test.sh#JAVA-02 Linux install_jdk shows java -version output when its JDK does not run"
        status: pass
    human_judgment: false
  - id: D2
    description: "Windows rerun replaces a ledger-owned user JAVA_HOME whose folder has no java.exe, keeps one that holds a JDK, and leaves one it never set (G-02-4, WR-02)"
    requirement: JAVA-01
    verification:
      - kind: integration
        ref: "test.sh#JAVA-01 Windows Install-Jdk replaces a saved JAVA_HOME it set whose folder has no java.exe"
        status: pass
      - kind: integration
        ref: "test.sh#JAVA-01 Windows Install-Jdk replaces a stale user JAVA_HOME it set earlier"
        status: pass
      - kind: integration
        ref: "test.sh#JAVA-01 Windows Install-Jdk keeps an existing user JAVA_HOME even when it set one earlier"
        status: pass
      - kind: integration
        ref: "test.sh#JAVA-01 Windows Install-Jdk leaves a user JAVA_HOME it did not set"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every Phase 2 review finding has a gate-preserved disposition; open: 0, total: 31"
    verification:
      - kind: command
        ref: "02-09-PLAN.md Task 3 dispositions verify command (printed 'dispositions ok')"
        status: pass
    human_judgment: false
---

# Phase 2 Plan 09: Linux Picked-up filter, Windows java.exe replace rule, review dispositions Summary

**The Linux "JDK does not run" error now drops `Picked up` lines (which can carry proxy passwords), a Windows rerun repairs a saved JAVA_HOME it set when that folder has no `bin\java.exe`, and all 31 Phase 2 review findings are dispositioned (open: 0).**

## Performance

- Duration: about 3 min
- Started and completed: 2026-10-14
- Tasks: 3 of 3
- Files modified: 4

## Accomplishments

- G-02-1: `install_jdk`'s final self-check die pipes `java -version` output through `grep -v '^Picked up'` before `head -3`. The die still fires when grep matches nothing, because the substitution is only an argument to `die`.
- G-02-4 / WR-02: `Install-Jdk` sets `$gone` when `Join-Path (Join-Path $userJava 'bin') 'java.exe'` is not a leaf. The `-and` short-circuit stays, so `Test-Path` never sees an empty value under StrictMode. The `Set-UserEnv` comment and the replace log line now say "has no java.exe".
- 02-REVIEW-DISPOSITION.md: WR-01 and WR-03 are fixed in 02-08 (3c1259d), IN-01 is fixed in 02-08 (e9e01f1), WR-02 is fixed in 02-09 (58bad6d), and IN-02 is deferred as "accepted 2026-10-14: pre-existing no-npm dry-run path outside phase scope; backlog 999.1". The counts are open: 0 and total: 31.

## Task Commits

1. **Task 1 (tracer): Linux JDK error hides Picked up lines**: RED `c88ef3f`, GREEN `0039deb`
2. **Task 2: Windows replaces a saved JAVA_HOME with no java.exe**: RED `ed83bbf`, GREEN `58bad6d`
3. **Task 3: Record review dispositions**: `16d17e4`

## Red evidence

Task 1, `/bin/bash ./test.sh` before the fix (94 passed, 1 failed, 2 skipped):

```
FAIL: JAVA-02 Linux install_jdk hides Picked up lines when its JDK does not run
    error: the JDK at .../home/.rea-installer/jdk does not run; java -version printed: Picked up JAVA_TOOL_OPTIONS: -Dhttp.proxyPassword=hunter2
    Picked up _JAVA_OPTIONS: -Xmx1g
    Picked up JDK_JAVA_OPTIONS: -Xss2m
```

Semantic assessment: the target check ran and failed on the planned assertion. `head -3` printed the three Picked up lines, including the fake password, and dropped the JVM error. No setup or syntax fault was involved.

Task 2, `/bin/bash ./test.sh` before the fix (94 passed, 2 failed, 2 skipped):

```
FAIL: JAVA-01 Windows Install-Jdk replaces a stale user JAVA_HOME it set earlier
FAIL: JAVA-01 Windows Install-Jdk replaces a saved JAVA_HOME it set whose folder has no java.exe
    JAVA_HOME is already set for your user to .../win/leftover/jdk-21.0.4.7-hotspot; leaving it as-is.
```

Semantic assessment: the new case failed for the planned reason. The leftover folder exists, so the old folder test kept it. The CR-01 case still replaced the value, so it failed only on its updated wording condition: the log said "a folder that no longer exists", not "has no java.exe".

## Local test runs (final)

- macOS, Bash 3.2, including the pwsh driver: `96 passed, 0 failed, 2 skipped` (the 2 skips are Linux-only checks)
- Linux container, ubuntu:24.04: `63 passed, 0 failed, 11 skipped` (the Windows cases skip because the container has no pwsh)
- `exit: mac=0 linux=0`, with no FAIL lines in either run

## Acceptance criteria

- `grep -cF "2>&1 | grep -v '^Picked up' | head -3" rea-install-linux.sh` returned 1: PASS
- `grep -c 'has no java.exe' rea-install-windows.ps1` returned 2: PASS
- `awk '/^function Install-Jdk/,/^}/' rea-install-windows.ps1 | grep -c 'PathType Leaf'` returned 1: PASS
- The `58bad6d` hunks start at old lines 119, 127 and 197. All are after line 17, so the help block is unchanged: PASS
- The dispositions command printed `dispositions ok`: PASS

## Deviations from Plan

None. The plan was executed as written. The RED checks were committed separately before each GREEN fix, using the project's plain commit style. The plan named only the GREEN commit messages.

## Threat Flags

None. The changes stay inside the plan's threat register (T-02-33, T-02-34, T-02-35).

## Next Phase Readiness

Ready for 02-10. Confirmation on a real Windows machine stays deferred to VERI-02.

## Self-Check: PASSED

- The modified files exist, and commits c88ef3f, 0039deb, ed83bbf, 58bad6d and 16d17e4 are ancestors of HEAD.
