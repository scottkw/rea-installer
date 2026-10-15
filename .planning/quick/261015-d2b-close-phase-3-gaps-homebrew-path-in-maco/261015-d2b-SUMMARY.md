---
phase: quick-261015-d2b
plan: 01
subsystem: macos-installer
tags: [macos, homebrew, sudo, readme, gap-closure]
status: complete
requires: [phase-03]
provides: [homebrew-shellenv-in-profile-block, sudo-ticket-cleared-after-homebrew]
affects: [rea-install-macos.sh, test.sh, README.md]
tech-stack:
  added: []
  patterns: [ledger-driven profile line re-queued on every run]
key-files:
  created: []
  modified: [rea-install-macos.sh, test.sh, README.md]
decisions:
  - "Homebrew shellenv line is queued when install_homebrew ran this run (brew_installed) or the ledger holds homebrew, so reruns keep it in the rebuilt block"
  - "sudo -k runs through run after Homebrew's installer whenever this run cached a ticket with sudo -v, on success and failure; a failed sudo -k warns rather than being swallowed"
  - "do_uninstall left unchanged (lean fix); a kept Homebrew loses its PATH line on uninstall (accepted T-q261015-03)"
requirements: [MAC-02, DOCS-01]
metrics:
  duration: ~10m
  completed: 2026-10-15
actuals:
  tokens: 3250
  tasks: 3
  commits: 3
plan_head_before: 59e67b60ac97e17227831d3281521d95eb1d9d02
plan_head_after: c01378444c3f9d405e917488ab630d65915f0a7d
---

# Quick 261015-d2b Plan 01: Close Phase 3 gaps (Homebrew PATH, sudo ticket, README) Summary

A script-installed Homebrew now gets its `eval "$(<brew> shellenv)"` line in the marked macOS profile block, the sudo ticket cached for Homebrew's unattended installer is cleared with `sudo -k` right after it, and two wrong README sentences are fixed.

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Put a script-installed Homebrew on PATH through the profile block (CR-01) | 714dc7d | rea-install-macos.sh, test.sh |
| 2 | Clear the cached sudo ticket after Homebrew's installer under --yes (WR-01) | a79425e | rea-install-macos.sh, test.sh |
| 3 | README wording fixes (WR-08, IN-03) and profile block note | c013784 | README.md |

## What changed

- `rea-install-macos.sh`: global `brew_installed=false`, set after `record "homebrew"`. `write_profile` appends the shellenv line (`/opt/homebrew/bin/brew` on arm64, `/usr/local/bin/brew` otherwise) when `brew_installed` is true or the ledger holds `homebrew`. `install_homebrew`'s `--yes` branch captures the installer status, runs `run sudo -k` if it ran `sudo -v`, then dies with the existing hint on failure.
- `test.sh`: 6 new checks (recorded Homebrew gets the line, unrecorded does not, dry run plans it and writes nothing, `sudo -k` after the installer line, no `sudo -k` without a terminal, `sudo -k` on installer failure via a sandbox-local `sudo` function).
- `README.md`: macOS uninstall stops if the recorded npm cannot run; openjdk@21 is installed and recorded only when not already present; note on the shellenv line in the profile block; macOS testing row lists the new checks.

## TDD Gate Compliance

Tasks 1 and 2: tests written first and confirmed failing (Task 1: 2 failed; Task 2: 2 failed), then passing after the script change. Tests and implementation were committed together per task (the plan's per-task commit), not as separate RED/GREEN commits.

## Verification

`/bin/bash ./test.sh` on macOS (Bash 3.2): `119 passed, 0 failed, 2 skipped` (the skips are Linux-only checks). `bash -n` and shellcheck pass for both bash scripts and test.sh. No edits to rea-install-linux.sh or rea-install-windows.ps1.

## Deviations from Plan

None in behaviour. Process note: RED and GREEN for each TDD task share one commit instead of separate test/feat commits, matching the plan's "commit each task atomically" instruction.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: rea-install-macos.sh, test.sh, README.md
- FOUND: 714dc7d, a79425e, c013784 (ancestors of HEAD)
