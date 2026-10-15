---
phase: 02-consistent-java-handling
plan: 08
subsystem: installer-macos
tags: [bash, macos, java, jdk, profile, uat-gap]

requires:
  - phase: 02-consistent-java-handling
    provides: "jdk_usable, jdk_home, jdk_owned and write_profile ownership rule from 02-02..02-06"
provides:
  - "write_profile if/elif chain: dead owned JDK left out with a warning, set JAVA_HOME replaced only with the D-04 warning"
  - "jdk_owned limited to the PROFILE_BEGIN..PROFILE_END block"
  - "test.sh regression checks for review WR-01, WR-03 and IN-01"
affects: [02-09, 02-10, DOCS-01]

actuals:
  tokens: 1800
  tasks: 2
  commits: 4
plan_head_before: 4861e441a62e9bae51d722a2371e8738701fa50f
plan_head_after: e9e01f1de61d9b8dcb37af4d57667454e306904a

tech-stack:
  added: []
  patterns:
    - "Read a sed range into a variable and grep it through a here-string, not a sed | grep -q pipe (pipefail SIGPIPE)"

key-files:
  created: []
  modified:
    - rea-install-macos.sh
    - test.sh

key-decisions:
  - "macOS write_profile: outside jdk_chosen the owned JDK must run before it is written; if not, it is left out, warning only when the caller has no usable JDK 21+ (WR-03, JAVA-03)"
  - "macOS write_profile replaces a set non-21 JAVA_HOME only with the D-04 warning (WR-01)"
  - "macOS jdk_owned counts only the script's own profile block as ownership; a user export JAVA_HOME line is ignored (IN-01)"

patterns-established:
  - "RED test commit before each GREEN fix commit, in the project's plain sentence-case commit style"

requirements-completed: [JAVA-03, JAVA-04]

coverage:
  - id: D1
    description: "A macOS --no-ghidra rerun that replaces a set JDK 17 JAVA_HOME with the script's own JDK prints the D-04 warning once (G-02-2)"
    requirement: JAVA-04
    verification:
      - kind: integration
        ref: "test.sh#JAVA-02 macOS --no-ghidra rerun warns before replacing a JDK 17 JAVA_HOME with its own"
        status: pass
    human_judgment: false
  - id: D2
    description: "A macOS --no-ghidra rerun whose owned openjdk@21 does not run writes no JAVA_HOME and warns, whether JAVA_HOME is the dead owned path or unset (G-02-3)"
    requirement: JAVA-04
    verification:
      - kind: integration
        ref: "test.sh#JAVA-04 macOS --no-ghidra rerun leaves out an owned JDK that does not run, with a warning"
        status: pass
      - kind: integration
        ref: "test.sh#JAVA-03 macOS rerun reuses a JDK 21 JAVA_HOME even when it owns openjdk@21"
        status: pass
    human_judgment: false
  - id: D3
    description: "jdk_owned reads only the script's profile block, so a user JAVA_HOME line neither needs brew --prefix nor counts as ownership (G-02-5)"
    requirement: JAVA-03
    verification:
      - kind: integration
        ref: "test.sh#JAVA-03 macOS jdk_owned ignores a user JAVA_HOME line outside its profile block"
        status: pass
      - kind: other
        ref: "awk '/^jdk_owned\\(\\)/,/^}/' rea-install-macos.sh scope check -> jdk_owned scoped"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-10-15
status: complete
---

# Phase 02 Plan 08: macOS JAVA_HOME rerun gaps (G-02-2, G-02-3, G-02-5) Summary

**macOS write_profile now warns before replacing a set JAVA_HOME, leaves out an owned openjdk@21 that does not run (same result from any shell), and jdk_owned only trusts the script's own profile block.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-10-15T01:58:29Z
- **Completed:** 2026-10-15T02:02:01Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- G-02-2 (review WR-01): a `--no-ghidra` rerun that replaces a set, non-21 `JAVA_HOME` prints "JAVA_HOME points at ..., which is not JDK 21 or newer; using the script's own JDK 21 at ..." exactly once.
- G-02-3 (review WR-03): outside `jdk_chosen`, the owned JDK must pass `jdk_usable` before it is written. If it does not run, `JAVA_HOME` stays out of the block, with "... does not run; JAVA_HOME is left out of <profile>. Rerun without --no-ghidra to reinstall it." The warning is skipped only when the caller's `JAVA_HOME` is itself a usable JDK 21+ (JAVA-03).
- G-02-5 (review IN-01): `jdk_owned` reads the `PROFILE_BEGIN..PROFILE_END` range once and greps it through here-strings. A user `export JAVA_HOME="$(/usr/libexec/java_home -v 21)"` line no longer calls `brew --prefix` or counts as ownership.

## Task Commits

1. **Task 1 (tracer): write_profile warns and skips a dead owned JDK**
   - RED: `dd29259` (Add failing checks for macOS rerun JAVA_HOME replace and dead owned JDK)
   - GREEN: `3c1259d` (Warn before a macOS rerun replaces JAVA_HOME and skip an owned JDK that does not run)
2. **Task 2: jdk_owned reads only the script's profile block**
   - RED: `0f17524` (Add failing check for a user JAVA_HOME line outside the macOS profile block)
   - GREEN: `e9e01f1` (Limit macOS JDK ownership checks to the script's profile block)

Fix commits cited by 02-09 Task 3: **`3c1259d`** (WR-01, WR-03) and **`e9e01f1`** (IN-01).

## Red evidence

Task 1, `/bin/bash ./test.sh` after `dd29259` and before the `write_profile` fix (exit 1):
```
FAIL: JAVA-02 macOS --no-ghidra rerun warns before replacing a JDK 17 JAVA_HOME with its own
    ==> Adding REA settings to .../home/.bash_profile
    JAVA_HOME=.../home/brew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
    mode: export JAVA_HOME="$ours"
    ==> Adding REA settings to .../home/.bash_profile
    mode: unset JAVA_HOME
    ==> Adding REA settings to .../home/.bash_profile
FAIL: JAVA-04 macOS --no-ghidra rerun leaves out an owned JDK that does not run, with a warning
91 passed, 2 failed, 2 skipped
```
Semantic assessment: both target checks ran and failed on the planned assertion. JDK 17 was replaced with no warning (WR-01). The dead owned JDK produced no warning in either mode, and the `export JAVA_HOME="$ours"` mode also wrote the dead path (WR-03). There were no load or syntax faults, and every other check passed.

Task 2, `/bin/bash ./test.sh` after `0f17524` and before the `jdk_owned` fix (exit 1):
```
FAIL: JAVA-03 macOS jdk_owned ignores a user JAVA_HOME line outside its profile block
    ==> Ghidra already available (left as-is)
    error: could not locate Homebrew's openjdk@21 (brew --prefix failed).
    export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
93 passed, 1 failed, 2 skipped
```
Semantic assessment: the target check failed for the reason in review IN-01. `jdk_owned` matched the user line outside the block, called `brew --prefix` and died.

## Test results (after both fixes)

- macOS, Bash 3.2 (`/bin/bash ./test.sh`): `94 passed, 0 failed, 2 skipped` (baseline 91 + 3 new)
- Linux container (`docker run --rm -v "$PWD":/src:ro ubuntu:24.04 bash -c 'cp -r /src /w && cd /w && ./test.sh'`): `62 passed, 0 failed, 11 skipped` (baseline 59 + 3 new; all three new checks PASS there)
- `shellcheck rea-install-macos.sh test.sh`: clean
- Acceptance: `grep -c 'Rerun without --no-ghidra'` = 1, `grep -c "using the script's own JDK 21 at"` = 1, `grep -cE 'mapfile|declare -A'` = 0, awk scope check prints `jdk_owned scoped`
- Tracer gate: the Task 1 `<verify>` re-run passed end to end before Task 2 started

## Files Created/Modified
- `rea-install-macos.sh`: `write_profile` uses an if/elif chain (dead-owned, equal-path, replace-with-warning, otherwise none) and has updated rule comments. `jdk_owned` is limited to the profile block, and its IN-03 comment now reads (IN-03, IN-01).
- `test.sh`: adds 3 checks (WR-01, WR-03 two-mode loop, IN-01). The existing JAVA-03 owned-openjdk check now also asserts there is no 'does not run' warning.

## Decisions Made
- Branch c (replace with warning) does not call `jdk_usable "$ours"` again. It can only be reached after branch a has shown that ours runs, or with `jdk_chosen` true, where `install_jdk` set `JAVA_HOME` to ours, so branch b takes it. This avoids running `java -version` twice.
- `block="$(sed ...)" || block=""` treats a missing profile as an empty block. This follows the `|| prefix=""` form in `jdk_home`, and absence is an expected state here.

## Deviations from Plan

**1. [Process] RED and GREEN committed separately**
- The plan gives one commit message per task. The executor's TDD protocol requires a RED commit before GREEN, so each task has a test-only commit followed by the fix commit, and the fix commit uses the plan's exact message. Commit messages follow the project's plain sentence-case style (CLAUDE.md) rather than `test(02-08):` prefixes.

**2. [Process] RED evidence not run through `gsd_run check tdd-red-evidence`**
- test.sh prints its own `PASS:/FAIL:` lines, not TAP, JUnit, swift-testing or unittest output, so the classifier has no adapter for it. RED was confirmed by semantic inspection instead (see Red evidence).

**Total deviations:** 2 process-only. **Impact:** none on code or scope.

## Issues Encountered
None.

## Known Stubs
None.

## User Setup Required
None. No external service configuration required.

## Next Phase Readiness
Ready for 02-09, which cites fix commits `3c1259d` and `e9e01f1`. Real-macOS confirmation is still out of scope for this milestone: these checks use the stubbed brew and stubbed JDKs.

## Self-Check: PASSED
- FOUND: rea-install-macos.sh, test.sh
- FOUND commits: dd29259, 3c1259d, 0f17524, e9e01f1 (all ancestors of HEAD)
