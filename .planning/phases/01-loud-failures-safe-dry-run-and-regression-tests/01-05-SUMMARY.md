---
phase: 01-loud-failures-safe-dry-run-and-regression-tests
plan: 05
subsystem: test-gate
tags: [test.sh, ci, github-actions, bash32, ubuntu, phase-gate]
status: complete

requires:
  - phase: 01-03
    provides: "Linux loud failures, safe dry run and uninstall fixes"
  - phase: 01-04
    provides: "macOS and Windows loud failures and uninstall fixes"
provides:
  - "Observed end state: full test.sh green on the Mac (default bash and Bash 3.2), in ubuntu:24.04, and in CI on both runners for the phase HEAD"
affects: [phase-01-verification]

actuals:
  tokens: 0
  tasks: 2
  commits: 0
plan_head_before: 770a678a3eca4cadfa0d1d35b73733452f86072e
plan_head_after: 770a678a3eca4cadfa0d1d35b73733452f86072e

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "The CI gate reads the run for 770a678, the phase code HEAD; later docs-only tracking commits are not part of the gate"

metrics:
  duration: 3m
  completed: 2026-10-14
---

# Phase 01 Plan 05: Full-suite phase gate Summary

The whole test.sh suite passes together on the Mac under both bash versions, in a fresh ubuntu:24.04 container, and in GitHub Actions on both the linux and macos jobs for phase HEAD 770a678. No file was changed.

## Task 1: local full-suite runs

Verified by the first executor of this plan (no commit; verification only):

- `./test.sh` (default bash): `31 passed, 0 failed, 2 skipped`
- `/bin/bash ./test.sh` (Bash 3.2): `31 passed, 0 failed, 2 skipped`
- `docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" -w /src ubuntu:24.04 bash ./test.sh`: `22 passed, 0 failed, 9 skipped`

Skips: the Mac runs skip the 2 Linux-only checks (TEST-02 Linux profile, UNIN-01 Linux). The ubuntu run skips the 2 macOS-only checks plus 7 tool-absent checks (3 shellcheck, 2 pwsh, 2 docker), as D-10 allows outside CI.

## Task 2: CI on both runners

- Precondition: after `git fetch origin`, `HEAD` and `@{u}` are both `770a678a3eca4cadfa0d1d35b73733452f86072e`; `gh auth status` is logged in to github.com.
- Run: https://github.com/scottkw/rea-installer/actions/runs/38601604074 (id 38601604074, workflow test.yml, commit 770a678)
- `gh run watch 38601604074 --exit-status` exited 0.
- `gh run view --json conclusion,jobs`: conclusion `success`; jobs `linux` success, `macos` success (2 of 2).

## Deviations from Plan

None - plan executed exactly as written. The plan was split across two executors at the blocking-human push precondition on Task 2; the maintainer pushed and this executor re-verified the precondition before reading CI.

## Self-Check: PASSED

- No file changed by this plan: `git rev-list --count 770a678..HEAD` was 0 before this SUMMARY.
- CI run 38601604074 is for commit 770a678 and concluded success with 2 successful jobs.
