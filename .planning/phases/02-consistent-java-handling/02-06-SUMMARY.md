---
phase: 02-consistent-java-handling
plan: 06
subsystem: installer
tags: [bash, macos, linux, jdk, java_home, temurin, profile, test.sh, gap-closure]
status: complete

requires:
  - phase: 02-consistent-java-handling
    provides: "macOS jdk_home, jdk_owned, install_jdk, write_profile; Linux install_jdk and unpack (02-02, 02-04)"
provides:
  - "macOS jdk_owned takes no argument and checks the ledger before it needs brew --prefix (IN-03)"
  - "macOS install_ghidra calls jdk_home only on the branch that installs Ghidra (IN-03)"
  - "macOS jdk_chosen run-local flag set by install_jdk"
  - "macOS write_profile keeps our JAVA_HOME by ownership plus the usable-user-JDK check, not by the caller's shell (WR-03, G-02-1)"
  - "Linux install_jdk moves a one-level-deeper Temurin JDK into place; any other layout stops and asks for a report (WR-04)"
  - "Linux does-not-run error shows the first three lines of java -version (IN-04)"
  - "Test coverage for the empty-release guard and the macOS --no-ghidra rerun (IN-05)"
affects: [02-07 review disposition, 02 re-verification]

actuals:
  tokens: 3012
  tasks: 2
  commits: 2
plan_head_before: 24c693771b30318a65789aff8b315c5da42067e6
plan_head_after: d4021adae03ea0a1b0c69ab99a139889e4bae3ba

tech-stack:
  added: []
  patterns:
    - "Ownership from the ledger or old block decides whether the profile keeps our JAVA_HOME"
    - "A function used as an if condition ends a failed $(...) with `|| exit 1` so a die stays fatal"

key-files:
  created: []
  modified:
    - rea-install-macos.sh
    - rea-install-linux.sh
    - test.sh

key-decisions:
  - "write_profile computes jdk_owned once into a local `owned` flag and reuses it, rather than calling jdk_owned twice (same rule as the plan, one brew --prefix call at most)"
  - "Linux nested layout: move the first child folder holding an executable bin/java, then remove the unpack folder; nothing outside ~/.rea-installer is touched"

requirements-completed: [JAVA-02, JAVA-03, JAVA-04]

duration: 4min
completed: 2026-10-15
---

# Phase 2 Plan 06: macOS JAVA_HOME ownership and Linux Temurin layout Summary

**The macOS profile keeps the script's own JAVA_HOME based on the ledger or old block, not on whether the caller's shell has it set, and never calls brew --prefix for a user with Ghidra and no owned JDK. Linux accepts a Temurin archive whose bin/java is one folder deeper and shows `java -version` output when its JDK does not run.**

## Performance

- **Duration:** 4 min
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- G-02-1 / WR-03: an `install --no-ghidra --with-extras` rerun writes exactly one `export JAVA_HOME="<openjdk@21 home>"` line whether the shell's JAVA_HOME is set to that path or unset. A usable user JDK 21+ is still never written (D-06).
- IN-03: `install_ghidra` and `write_profile` finish with `brew --prefix` failing when Ghidra is present and no JDK is owned, for JAVA_HOME unset, JDK 17, or a usable JDK 21.
- WR-04: a nested Temurin layout becomes a working `~/.rea-installer/jdk`. An unknown layout stops with "report this, since rerunning repeats the same download."
- IN-04: the error now reads "the JDK at ... does not run; java -version printed: <first 3 lines>".
- IN-05: the empty-release guard is tested, and so is the macOS --no-ghidra rerun.

## Task Commits

1. **Task 1 (tracer): macOS ownership-based JAVA_HOME and ledger-first jdk_owned** - `2fd5825`
2. **Task 2: Linux nested Temurin layout, java -version in the error, empty-release test** - `d4021ad`

The plan asked for one commit per task, so each task's red test and its fix share one commit. The red state was captured before the fix (below).

## Red evidence

Task 1, after adding the tests and before changing `rea-install-macos.sh` (`./test.sh`, macOS):

```
FAIL: JAVA-04 macOS --no-ghidra rerun writes its own JAVA_HOME whether or not the shell has it set
     [export JAVA_HOME="$ours": rc=0 export JAVA_HOME=".../home/brew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"] [unset JAVA_HOME: rc=0 ]
FAIL: JAVA-04 macOS --no-ghidra rerun keeps its own JAVA_HOME owned only through the old block
FAIL: JAVA-03 macOS install_ghidra with Ghidra present and no owned JDK does not need brew --prefix
    mode: unset JAVA_HOME
    error: could not locate Homebrew's openjdk@21 (brew --prefix failed).
83 passed, 3 failed, 2 skipped
```

Each FAIL had the expected cause. With JAVA_HOME unset, the rerun wrote no JAVA_HOME line, and the rewritten block lost its export. `install_ghidra` died in `jdk_home` in all three modes.

Task 2, after adding the tests and before changing `rea-install-linux.sh`:

```
FAIL: JAVA-02 Linux install_jdk uses a Temurin archive whose bin/java is one level deeper
    error: the Temurin archive has no bin/java under .../tools/jdk-21.0.5+11; rerun to download it again.
FAIL: JAVA-02 Linux install_jdk stops on a Temurin archive without bin/java
    error: ... rerun to download it again.          (no "report this")
FAIL: JAVA-02 Linux install_jdk shows java -version output when its JDK does not run
    error: the downloaded JDK at .../jdk does not run.   (no JVM output)
PASS: JAVA-02 Linux install_jdk stops on an empty Temurin release and keeps the tools folder
```

The empty-release check passed before the fix, as the plan expected, because the guard already existed. The no-bin/java case also failed before the fix: its new "report this" assertion is part of the plan's behavior block.

## Verification

- `./test.sh` (macOS, default bash): 89 passed, 0 failed, 2 skipped (Linux-only).
- `/bin/bash ./test.sh` (Bash 3.2): 89 passed, 0 failed, 2 skipped.
- `docker run ... ubuntu:24.04 bash ./test.sh`: exit 0, 59 passed, 0 failed, 11 skipped (shellcheck, pwsh, docker, and the macOS-only checks).
- shellcheck: clean for `rea-install-macos.sh`, `rea-install-linux.sh` and `test.sh`.
- Task 1 acceptance: the install_ghidra order check prints "order ok". `jdk_owned "` has 0 callers left. `jdk_chosen=false` is a global and `write_profile` reads it. Header lines 1-14 are unchanged.
- Task 2 acceptance: "rerun to download it again" appears 0 times, "report this" once, and `head -3` is in install_jdk. Header lines 1-15 are unchanged.
- Tracer gate: Task 1 `<verify>` was re-run end-to-end under both bash versions and passed before Task 2 started.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] shellcheck SC2016 on the new nested-layout sandbox call**
- **Found during:** Task 2 red run (`TEST-01 shellcheck test.sh` failed)
- **Fix:** added `# shellcheck disable=SC2016  # expanded inside the sandbox`, as the file's other sandbox calls do
- **Files modified:** test.sh
- **Commit:** d4021ad

Otherwise the plan was executed as written. `write_profile` evaluates `jdk_owned` once into a local `owned` flag instead of calling it at both decision points. The rule is the same as the plan's.

## Threat Flags

None. The changes stay inside the plan's threat register (T-02-23..26).

## Self-Check: PASSED

- FOUND: rea-install-macos.sh, rea-install-linux.sh, test.sh
- FOUND: 2fd5825, d4021ad (ancestors of HEAD)
