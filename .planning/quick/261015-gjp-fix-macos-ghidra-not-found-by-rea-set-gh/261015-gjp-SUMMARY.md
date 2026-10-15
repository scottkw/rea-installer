---
phase: quick-261015-gjp
plan: 01
subsystem: macos-installer
tags: [ghidra, macos, profile, GHID-01]
status: complete
requires: []
provides:
  - "ghidra_home and ghidra_setting in rea-install-macos.sh"
  - "GHID-01 macOS checks in test.sh"
affects: [rea-install-macos.sh, test.sh, README.md, .planning/STATE.md]
tech-stack:
  added: []
  patterns: ["run-scoped flag (ghidra_brewed) beside ledger ownership, as brew_installed and jdk_owned do"]
key-files:
  created: []
  modified: [rea-install-macos.sh, test.sh, README.md, .planning/STATE.md]
decisions:
  - "macOS sets GHIDRA_INSTALL_DIR to $(brew --prefix ghidra)/libexec only for Homebrew's ghidra; a user value elsewhere is left alone and unwritten"
  - "Under --no-ghidra the line is kept only when the ledger records brew:ghidra (same rerun trap as JAVA_HOME, WR-03)"
metrics:
  duration: 3min
  completed: 2026-10-15
actuals:
  tokens: 2700
  tasks: 3
  commits: 3
plan_head_before: 27ade39eefe102104674452a67642286abab6cf1
plan_head_after: 16c2c71a479fc7bbb1ea78385ac0208734b7f1cb
---

# Quick Task 261015-gjp: Fix macOS Ghidra not found by REA Summary

macOS installer now exports `GHIDRA_INSTALL_DIR=$(brew --prefix ghidra)/libexec` before `rea setup` and writes it once into the profile block, on fresh installs, reruns and owned `--no-ghidra` reruns.

## What changed

- `rea-install-macos.sh`: new `ghidra_brewed` flag; `ghidra_home()` (mirrors `jdk_home`: `brew --prefix ghidra`, dry-run default prefix without brew, `die` otherwise); `install_ghidra` sets `ghidra_brewed` and, in a real run, dies if the keg has no `ghidraRun`; `ghidra_setting()` called from `do_install` step 4 outside the `with_ghidra` gate.
- `test.sh`: GHID-01 section with six checks (fresh install, rerun in two shell modes, user value elsewhere, `--no-ghidra` fresh, `--no-ghidra` ledger rerun, dry run).
- `README.md`: "Settings REA reads" block lists `GHIDRA_INSTALL_DIR`, plus a paragraph on the macOS behaviour and the user-value exception.
- `.planning/STATE.md`: removed the answered "does REA find Ghidra on macOS" blocker (left uncommitted for the orchestrator).

## TDD

- Task 1 RED: "GHID-01 macOS fresh install ..." failed with `ghidra_setting: command not found` (119 passed, 1 failed); GREEN after the script change (120 passed, 0 failed).
- Task 2 RED: "GHID-01 macOS --no-ghidra rerun keeps GHIDRA_INSTALL_DIR for the Ghidra its ledger records" failed against Task 1's gate (124 passed, 1 failed); the other four new checks passed at once. GREEN after widening the gate to the `brew:ghidra` ledger entry.

## Verification

- `/bin/bash ./test.sh` (macOS Bash 3.2): `125 passed, 0 failed, 2 skipped`
- `shellcheck rea-install-macos.sh test.sh`: clean.

## Commits

- 195617d Set GHIDRA_INSTALL_DIR for Homebrew Ghidra on macOS
- 1c5d253 Keep GHIDRA_INSTALL_DIR on reruns and cover it in tests
- 16c2c71 Document GHIDRA_INSTALL_DIR in the macOS profile block

## Deviations from Plan

- Task 3 asked for one commit of "all task changes"; the per-task commit protocol was followed instead (one commit per task), and the STATE.md edit was left uncommitted as the orchestrator instructed.
- Not verified on a real Mac install; checks use stubbed brew and ghidraRun.

## Self-Check: PASSED

- Files exist: rea-install-macos.sh, test.sh, README.md.
- Commits 195617d, 1c5d253, 16c2c71 are ancestors of HEAD.
