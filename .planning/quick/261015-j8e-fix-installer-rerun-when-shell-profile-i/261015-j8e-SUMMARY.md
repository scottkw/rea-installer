---
phase: quick-261015-j8e
plan: 01
subsystem: installer-profile
status: complete
tags: [macos, linux, shell-profile, symlink, dotfiles, regression-test]
requires: []
provides:
  - "remove_profile_block that writes through a symlinked profile (both bash scripts)"
  - "TEST-04 symlinked-profile regression checks; TEST-02 on every OS"
affects: [rea-install-macos.sh, rea-install-linux.sh, test.sh]
tech-stack:
  added: []
  patterns: ["filter to mktemp file, write back with run cp so the link and mode survive"]
key-files:
  created: []
  modified: [rea-install-macos.sh, rea-install-linux.sh, test.sh]
decisions:
  - "remove_profile_block filters with plain sed into a mktemp file and writes back with run cp; cp follows the symlink and keeps the target's mode on BSD and GNU"
  - "TEST-04 checks the target's mode with find -perm 600 instead of parsing ls -l, to keep shellcheck clean (SC2012)"
metrics:
  duration: "~3 min"
  completed: 2026-10-15
actuals:
  tokens: 1800
  tasks: 2
  commits: 3
plan_head_before: ff75587e4e73199a8b110a9bd1e031bed05903b6
plan_head_after: b517e3f
---

# Phase quick-261015-j8e Plan 01: Fix installer rerun with a symlinked shell profile Summary

`remove_profile_block` in both bash installers no longer uses an in-place sed edit. It now filters the profile into a mktemp file and writes it back with `run cp`. On a rerun or uninstall, a dotfiles-linked `~/.zshrc` therefore keeps its link, its target and its mode, and the macOS installer no longer dies before `rea setup`.

## What changed

- `rea-install-macos.sh` and `rea-install-linux.sh`: same 4-line body in `remove_profile_block`: `tmp="$(mktemp)"`, `sed ... "$file" >"$tmp"`, `run cp "$tmp" "$file"`, `rm -f "$tmp"`, with one comment explaining why. The guard line and callers are unchanged. Bash 3.2 safe.
- `test.sh`: new TEST-04 section, with 2 checks per script and no OS gate. The profile is a relative symlink `.bashrc -> dotfiles/.bashrc`, the target is mode 600, and the block sits mid-file. The checks assert rc 0, the path is still a symlink, the readlink value is unchanged, the target content matches the reference exactly and the mode is still 600. The dry-run check also asserts that `$ cp` is printed and the target is byte-identical.
- `test.sh`: TEST-02 lost its uname gate and runs both scripts on every OS. The now-false in-place sed clauses were removed from the UNIN-01, JAVA-04 and GHID-01 comments. Their OS gates were left as they were, because those also depend on tac/tail -r, brew stubs and the macOS profile_file.

## Verification

- RED (before the fix, macOS): all 4 TEST-04 checks failed. The macOS script reproduced the user's exact error, `in-place editing only works for regular files`.
- `/bin/bash ./test.sh` on macOS (Bash 3.2): **131 passed, 0 failed, 1 skipped**. The skip is UNIN-01 Linux, which is Linux only. TEST-02 and TEST-04 PASS for both scripts.
- shellcheck: `shellcheck rea-install-macos.sh rea-install-linux.sh test.sh` is clean, and TEST-01 shellcheck PASSes for all three files.
- `grep -n 'sed -i' rea-install-macos.sh rea-install-linux.sh test.sh`: no matches.
- Docker Linux run: `docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" -w /src ubuntu:24.04 bash ./test.sh` gave **96 passed, 0 failed, 12 skipped**. TEST-02 and TEST-04 PASS for both scripts on GNU sed, the path where the original bug replaced the link. The skips are the expected macOS-only checks, plus shellcheck, pwsh and docker, which are not in the bare container.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] shellcheck SC2012 on the planned `ls -l | cut` mode check**
- **Found during:** Task 1 (GREEN run)
- **Issue:** The plan's `ls -l "$target" | cut -c1-10` and the `ls -l ... | sed` diagnostics made TEST-01 shellcheck fail on test.sh.
- **Fix:** The mode check is now `[ -n "$(find "$target" -perm 600)" ]`, an exact-mode match that works the same on BSD and GNU. The diagnostic `ls -l` is no longer piped.
- **Files modified:** test.sh
- **Commit:** 1fc9dfb. The RED commit cc6a0a5 briefly had the lint failure.

**2. [Rule 1 - Stale comment] JAVA section comment near the old line 416**
- `# No existing block below, so no sed -i: these run on every OS.` was not in the plan's list, but it cited the in-place sed form, so the clause was dropped. It now reads `# These run on every OS.`

## Commits

- cc6a0a5: Add failing check for a symlinked shell profile
- 1fc9dfb: Keep a symlinked shell profile on rerun and uninstall
- b517e3f: Run the profile round trip for both scripts on every OS

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: rea-install-macos.sh, rea-install-linux.sh, test.sh modified
- FOUND: cc6a0a5, 1fc9dfb, b517e3f on HEAD
