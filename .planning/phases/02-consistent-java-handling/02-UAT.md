---
status: partial
phase: 02-consistent-java-handling
source: [02-VERIFICATION.md]
started: 2026-10-15T01:09:27Z
updated: 2026-10-15T01:30:46.002Z
---

## Current Test

[testing complete]

## Tests

### 1. Decide whether the Linux "JDK does not run" error may print "Picked up ..." lines (review IN-04 vs 02-01 prohibition)
expected: A decided rule — filter "Picked up" lines (e.g. grep -v '^Picked up' | head -3) or accept the output as-is.
result: issue
reported: "Go with your recommendation" — decided: filter lines starting with "Picked up" before head -3 at rea-install-linux.sh:380 (02-01 T-02-02 prohibits printing them; they can carry proxy credentials and crowd out the real error)
severity: minor

### 2. Triage review WR-01 (macOS): a --no-ghidra rerun with an owned openjdk@21 and a JDK 17 session JAVA_HOME switches JAVA_HOME without the D-04 warning, and the re-appended block overrides a later user export
expected: Fix (split clause, print the D-04 warning) or accept.
result: issue
reported: "fix"
severity: major

### 3. Triage review WR-03 (macOS): when the owned openjdk@21 no longer runs, a --no-ghidra rerun writes a dead JAVA_HOME or drops it depending on the caller's shell, with no warning
expected: Fix (require jdk_usable "$ours" outside jdk_chosen and warn) or accept as a known limitation.
result: issue
reported: "fix"
severity: major

### 4. Triage review WR-02 (Windows): a saved JAVA_HOME pointing at a leftover Temurin folder without bin\java.exe is kept
expected: Fix (test for bin\java.exe instead of the folder) or defer to VERI-02.
result: issue
reported: "fix"
severity: major

### 5. Record dispositions for the 5 open rows in 02-REVIEW-DISPOSITION.md (WR-01..03, IN-01, IN-02)
expected: Each open row is fixed or deferred with an accepted reason; open: 0.
result: pass
note: "Dispositions decided: WR-01, WR-02, WR-03 fix (G-02-2..4); IN-01 fix (G-02-5); IN-02 deferred as accepted, pre-existing no-npm dry-run path outside phase scope (same class as IN-201/IN-202). Rows are written to 02-REVIEW-DISPOSITION.md by the gap-closure plans."

### 6. Real Windows (VERI-02): fresh install, rerun after a Temurin upgrade, -DryRun, Windows PowerShell 5.1
expected: Truths 02-03 #9 and #10 hold; JAVA_HOME saved to the real User scope and removed by uninstall.
result: blocked
blocked_by: physical-device
reason: "blocked: need physical device"

### 7. Push main and confirm both GitHub Actions jobs pass on the Phase 2 head
expected: ubuntu-latest and macos-latest both green.
result: pass
note: "Testing is local by decision (no GitHub Actions). Verified locally: /bin/bash 3.2 on macOS 91 passed, 0 failed, 2 skipped (Linux-only); Ubuntu 24.04 container 59 passed, 0 failed, 11 skipped (pwsh/docker unavailable, covered by the macOS run). Re-run after gap fixes."

## Summary

total: 7
passed: 2
issues: 4
pending: 0
skipped: 0
blocked: 1

## Gaps

- gap_id: G-02-1
  truth: "The Linux 'JDK does not run' error never prints 'Picked up ...' lines from java -version"
  status: failed
  reason: "User reported: Go with your recommendation (decided rule: filter 'Picked up' lines)"
  severity: minor
  test: 1
  artifacts: []
  missing: []

- gap_id: G-02-2
  truth: "A macOS --no-ghidra rerun that replaces a set, non-21 JAVA_HOME with the script's own JDK prints the D-04 warning (review WR-01)"
  status: failed
  reason: "User reported: fix (apply the split-clause fix from 02-REVIEW.md WR-01 plus a test.sh case)"
  severity: major
  test: 2
  artifacts: []
  missing: []

- gap_id: G-02-3
  truth: "A macOS --no-ghidra rerun whose owned openjdk@21 no longer runs gives the same result from any shell: JAVA_HOME is left out of the block and a warning says to rerun without --no-ghidra (review WR-03)"
  status: failed
  reason: "User reported: fix (apply the WR-03 guard from 02-REVIEW.md together with WR-01, plus test.sh cases)"
  severity: major
  test: 3
  artifacts: []
  missing: []

- gap_id: G-02-4
  truth: "On Windows, a saved JAVA_HOME whose folder has no bin\\java.exe is treated as dead and replaced with Temurin's folder (review WR-02)"
  status: failed
  reason: "User reported: fix (test for bin\\java.exe, update Set-UserEnv comment and log text, add a pwsh driver case with a leftover lib-only folder)"
  severity: major
  test: 4
  artifacts: []
  missing: []

- gap_id: G-02-5
  truth: "jdk_owned on macOS checks only the script's own profile block for export JAVA_HOME= lines, so a user's own JAVA_HOME line does not trigger brew --prefix or count as ownership (review IN-01)"
  status: failed
  reason: "User accepted disposition in test 5: fix IN-01 (limit both greps to the PROFILE_BEGIN..PROFILE_END range, add an IN-03 case with a user export JAVA_HOME line)"
  severity: minor
  test: 5
  artifacts: []
  missing: []

## Deferred Follow-Ups

- test: 5
  idea: "Review IN-02: dry runs on a machine without npm die at npm prefix --global (macOS rea-install-macos.sh:308, Windows rea-install-windows.ps1:266); use a placeholder prefix in dry run as Linux does with NPM_PREFIX"
  deferred_at: 2026-10-14
