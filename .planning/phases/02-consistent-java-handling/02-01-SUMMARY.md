---
phase: 02-consistent-java-handling
plan: 01
subsystem: installer
tags: [bash, jdk, java_home, linux, macos, test.sh]

requires:
  - phase: 01-loud-failures-safe-dry-run-and-regression-tests
    provides: "test.sh harness (sandbox, stubs, source guard), DRY-01 container check, rerun reset of $STATE_DIR settings"
provides:
  - "jdk_usable DIR predicate, byte-identical in rea-install-linux.sh and rea-install-macos.sh"
  - "Linux install_jdk reuses only a JDK 21+ JAVA_HOME; otherwise warns, installs Temurin 21 once per run, persists it via setting"
  - "Post-install self-check: a JDK that does not run stops the Linux install"
  - "test.sh mkjdk helper, 20-row jdk_usable table, three Linux install_jdk checks, DRY-01 single-JDK-plan assertions"
affects: [02-02 macOS JDK wiring, 02-03 Windows JDK handling]

actuals:
  tokens: 2000
  tasks: 2
  commits: 2
plan_head_before: 4674cf1c61022663322b89c86d596c222376c2b6
plan_head_after: c63d58e2c260942c65dfabbed6ecba47db3b2362

tech-stack:
  added: []
  patterns:
    - "Version-gate predicate: capture java -version 2>&1 into a variable (no pipe), regex held in a local, BASH_REMATCH[3]:-0 for set -u"
    - "Same-run guard: JAVA_HOME equal to $STATE_DIR/jdk can only come from this run, because do_install unsets inherited $STATE_DIR values"

key-files:
  created: []
  modified:
    - rea-install-linux.sh
    - rea-install-macos.sh
    - test.sh

key-decisions:
  - "jdk_usable does not require the compiler binary (locked D-01); a JRE 21 JAVA_HOME is reused"
  - "WR-01 hardening limited to a post-install jdk_usable self-check that dies loudly; unpack top-folder mismatch stays accepted"
  - "The D-04 warning names only the folder; java -version output is never printed (it can carry JAVA_TOOL_OPTIONS credentials)"

patterns-established:
  - "mkjdk DIR BODY: stub JDK for tests; plan 02-03 extends it with java.exe"

requirements-completed: [JAVA-02]

coverage:
  - id: D1
    description: "jdk_usable accepts JDK 21+ and fails closed on every other java -version shape, in both bash scripts"
    requirement: JAVA-02
    verification:
      - kind: unit
        ref: "test.sh#JAVA-02 jdk_usable <label> (<script>) x 20, under /bin/bash 3.2 and ubuntu:24.04 Bash 5"
        status: pass
      - kind: other
        ref: "diff of the jdk_usable function between rea-install-linux.sh and rea-install-macos.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Linux install_jdk replaces a JDK 17 JAVA_HOME with its own (one warning, one download plan, one profile line over two calls), reuses a JDK 21 JAVA_HOME, and installs without a warning when JAVA_HOME is unset"
    requirement: JAVA-02
    verification:
      - kind: unit
        ref: "test.sh#JAVA-02 Linux install_jdk replaces a JDK 17 JAVA_HOME with its own"
        status: pass
      - kind: unit
        ref: "test.sh#JAVA-02 Linux install_jdk reuses a JDK 21 JAVA_HOME"
        status: pass
      - kind: unit
        ref: "test.sh#JAVA-02 Linux install_jdk with no JAVA_HOME installs its own without a warning"
        status: pass
    human_judgment: false
  - id: D3
    description: "Fresh ubuntu:24.04 install --dry-run --with-android plans Temurin 21 once and prints no false JAVA_HOME warning"
    requirement: JAVA-02
    verification:
      - kind: integration
        ref: "test.sh#DRY-01 Linux install --dry-run --with-android in fresh ubuntu:24.04"
        status: pass
    human_judgment: false
  - id: D4
    description: "A real (non-dry) Linux JDK download that does not run stops with 'the downloaded JDK at $STATE_DIR/jdk does not run.'"
    requirement: JAVA-02
    verification: []
    human_judgment: true
    rationale: "Needs a real Adoptium download; no test exercises the non-dry path. Checked by code reading only."

duration: 2min
completed: 2026-10-14
status: complete
---

# Phase 2 Plan 01: Linux JDK 21 rule and shared jdk_usable predicate Summary

**Linux now reuses `JAVA_HOME` only when its `java -version` reports 21 or newer, otherwise installs Temurin 21 once per run and persists only that path; the same `jdk_usable` predicate sits byte-identical in the macOS script, table-tested under Bash 3.2 and Bash 5.**

## Performance

- **Duration:** about 2 min measured from the first edit (reading and research not counted)
- **Completed:** 2026-10-14T19:30:11Z
- **Tasks:** 2 of 2
- **Files modified:** 3

## Accomplishments

- `jdk_usable DIR` in `rea-install-linux.sh` and `rea-install-macos.sh`. It searches all of the output, so a leading `Picked up JAVA_TOOL_OPTIONS:` line is skipped. It reads `1.8.x` as 8 and fails closed on a missing or broken java or unreadable output.
- Linux `install_jdk` has a same-run guard, reuses a JDK 21+, prints the D-04 warning for an older `JAVA_HOME`, and dies when the downloaded JDK does not run (non-dry runs only).
- test.sh gained 23 new JAVA-02 checks, and DRY-01 now asserts a single JDK plan and no false warning.

## Task Commits

1. **Task 1 (tracer): Linux JDK 17 replaced, JDK 21 reused** - `3d2db49` (Reuse JAVA_HOME on Linux only when it is JDK 21 or newer)
2. **Task 2: jdk_usable table in both scripts, macOS copy, single JDK plan** - `c63d58e` (Table-test the JDK 21 check in both bash installers)

## Files Created/Modified

- `rea-install-linux.sh` - `jdk_usable` after `node_supported`; reworked `install_jdk`
- `rea-install-macos.sh` - `jdk_usable` after `node_supported` (no callers yet; plan 02-02 wires it in)
- `test.sh` - `mkjdk` helper, JAVA-02 section, DRY-01 assertions

## Verification

- Plan gate: `exit: default=0 bash32=0 ubuntu=0` and no FAIL lines. The Mac runs had 54 passes and 2 Linux-only skips. ubuntu:24.04 had 45 passes, including all 23 JAVA-02 checks. Its 9 skips are for shellcheck, pwsh and docker, which are not in the container, plus macOS-only checks.
- Task 2 RED was observed before the macOS copy: all 10 macOS `jdk_usable` rows failed, then all passed after the copy.
- All acceptance criteria for both tasks were re-run and pass. Header lines are unchanged in both scripts (the first diff hunks start at Linux line 284 and macOS line 91).

## Decisions Made

See key-decisions in the frontmatter. No new decisions beyond the plan's resolved assumptions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] shellcheck SC2034 in the jdk_usable table loop**
- **Found during:** Task 2
- **Issue:** A loop variable that was read only inside the single-quoted eval string was flagged as unused, so `TEST-01 shellcheck test.sh` failed.
- **Fix:** The loop now expands the directory into the eval string directly (`sandbox "$script" "jdk_usable \"$dir\""`), with no inline disable.
- **Files modified:** test.sh
- **Commit:** c63d58e

**Note:** Task 2 has `tdd="true"`, but the plan gives one commit message for the task. RED was verified by running the tests, and the test and implementation went into one commit, as the plan specifies.

**Total deviations:** 1 auto-fixed (blocking lint). **Impact:** none on behavior.

## Issues Encountered

None.

## Known Stubs

None.

## Next Phase Readiness

Ready for 02-02 (the macOS `install_jdk` and step-7 profile write, which use `jdk_usable`).

## Self-Check: PASSED

- FOUND: rea-install-linux.sh, rea-install-macos.sh, test.sh
- FOUND: 3d2db49, c63d58e (ancestors of HEAD)
