---
phase: quick-261014-tvi
plan: 01
subsystem: installer-java
tags: [java, security, profile, macos, linux]
status: complete
requires: []
provides:
  - "Linux JDK error filter that drops both Picked up formats"
  - "macOS write_profile that clears the old block on every run and unsets a dead session JAVA_HOME"
affects: [rea-install-linux.sh, rea-install-macos.sh, test.sh]
tech-stack:
  added: []
  patterns: ["red test committed before each fix"]
key-files:
  created: []
  modified: [rea-install-linux.sh, rea-install-macos.sh, test.sh]
decisions:
  - "macOS write_profile calls remove_profile_block on every run (user decision: always rewrite)"
  - "Dead owned JDK warning now says to reinstall openjdk@21 with Homebrew instead of rerunning without --no-ghidra (IN-01)"
requirements: [JAVA-02, JAVA-04]
metrics:
  completed: 2026-10-14
actuals:
  tokens: 9000
  tasks: 3
  commits: 4
plan_head_before: 883c79898e9227b2194ebdf75cc49cb0546e6eba
plan_head_after: 232256cc29f45bc68119d9f66d27accf42ccd363
---

# Quick 261014-tvi: Linux Picked up filter and macOS dead JAVA_HOME Summary

The Linux JDK error now drops the launcher's `NOTE: Picked up JDK_JAVA_OPTIONS:` line, so a proxy password can't be printed. A plain macOS `--no-ghidra` rerun with a dead owned JDK now removes the old JAVA_HOME export from the profile and unsets it in the session, so `rea setup` no longer registers it.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 red | fea0cd9 | Use the real NOTE: Picked up line in the Linux JDK error test |
| 1 green | 38036da | Drop NOTE: Picked up lines from the Linux JDK error |
| 2 red | b948538 | Test a macOS rerun that leaves a dead JAVA_HOME in the profile |
| 2 green | 232256c | Remove a dead owned JAVA_HOME from the macOS profile and session |

## What changed

- `rea-install-linux.sh` `install_jdk`: the filter is now `grep -Ev '^(NOTE: )?Picked up '`, with a comment explaining the optional `NOTE: ` prefix. The T-02-02 reference is kept.
- `rea-install-macos.sh` `write_profile`:
  - branch a unsets JAVA_HOME when it equals the dead owned path.
  - `remove_profile_block` now runs on every run. Only the log line, the append and `record` remain gated on a non-empty `profile_exports`.
  - The warning now says `Reinstall openjdk@21 with Homebrew to repair it.` (IN-01).
- `test.sh`:
  - The Linux "hides Picked up lines" fixture now uses the real formats, with `hunter2` in the `NOTE: Picked up JDK_JAVA_OPTIONS:` line.
  - Added the new Darwin-guarded case "JAVA-04 macOS --no-ghidra rerun removes a dead owned JAVA_HOME when nothing else is queued", which runs in two modes: JAVA_HOME exported and JAVA_HOME unset.
  - The WR-03 case's grep literal changed to `'Reinstall openjdk@21 with Homebrew'`.

## Red evidence

- Task 1: before the fix, the suite printed `FAIL: JAVA-02 Linux install_jdk hides Picked up lines when its JDK does not run` (95 passed, 1 failed, 2 skipped).
- Task 2: before the fix, the new case failed in both modes. The `# >>> rea-installer >>>` block and its `export JAVA_HOME=` line stayed in the profile. In the export mode, the session also kept `JAVA_HOME=<dead path>` (96 passed, 1 failed, 2 skipped).

## Verification (local)

- Mac, `/bin/bash ./test.sh`: `97 passed, 0 failed, 2 skipped`
- Docker `ubuntu:24.04`, `docker run --rm -v "$PWD":/src -w /src ubuntu:24.04 ./test.sh`: `63 passed, 0 failed, 12 skipped`. The new case is skipped there as macOS only.
- `shellcheck rea-install-linux.sh rea-install-macos.sh test.sh`: exit 0 (Homebrew shellcheck on the Mac)
- `/bin/bash -n rea-install-macos.sh`: ok
- `git diff --stat 883c798 -- rea-install-windows.ps1 .planning/phases/02-consistent-java-handling/02-REVIEW-DISPOSITION.md`: empty

## Known consequence (accepted by user decision)

The block is now rewritten on every run to match that run's flags. If an earlier `--with-extras` run wrote extras lines (`REA_OBJDUMP_COMMAND`, `REA_WABT_BIN_DIRECTORY`), a later rerun that queues nothing removes them. This already happened whenever JAVA_HOME was queued. Per the user's "always rewrite" decision, no code was added to keep those lines.

The `profile:` ledger entry stays after the block is removed. That is harmless, because `remove_profile_block` returns 0 when the block is absent at uninstall.

## Deviations from Plan

None. The plan was executed exactly as written.

## Self-Check: PASSED

- The commits fea0cd9, 38036da, b948538 and 232256c are on HEAD.
- `grep -cF "grep -Ev '^(NOTE: )?Picked up '" rea-install-linux.sh` prints 1.
- `grep -c 'Rerun without --no-ghidra'` prints 0 for both rea-install-macos.sh and test.sh.
