---
status: testing
phase: 02-consistent-java-handling
source: [02-VERIFICATION.md]
started: 2026-10-15T01:09:27Z
updated: 2026-10-15T01:09:27Z
---

## Current Test

number: 1
name: Decide whether the Linux "JDK does not run" error may print "Picked up ..." lines (02-01 prohibition vs 02-06 truth 5, review IN-04)
expected: |
  A decided rule: either filter lines starting with "Picked up" before printing the first 3 lines of java -version at rea-install-linux.sh:380, or accept that the user's own options may appear on their own stderr.
awaiting: user response

## Tests

### 1. Decide whether the Linux "JDK does not run" error may print "Picked up ..." lines (review IN-04 vs 02-01 prohibition)
expected: A decided rule — filter "Picked up" lines (e.g. grep -v '^Picked up' | head -3) or accept the output as-is.
result: [pending]

### 2. Triage review WR-01 (macOS): a --no-ghidra rerun with an owned openjdk@21 and a JDK 17 session JAVA_HOME switches JAVA_HOME without the D-04 warning, and the re-appended block overrides a later user export
expected: Fix (split clause, print the D-04 warning) or accept.
result: [pending]

### 3. Triage review WR-03 (macOS): when the owned openjdk@21 no longer runs, a --no-ghidra rerun writes a dead JAVA_HOME or drops it depending on the caller's shell, with no warning
expected: Fix (require jdk_usable "$ours" outside jdk_chosen and warn) or accept as a known limitation.
result: [pending]

### 4. Triage review WR-02 (Windows): a saved JAVA_HOME pointing at a leftover Temurin folder without bin\java.exe is kept
expected: Fix (test for bin\java.exe instead of the folder) or defer to VERI-02.
result: [pending]

### 5. Record dispositions for the 5 open rows in 02-REVIEW-DISPOSITION.md (WR-01..03, IN-01, IN-02)
expected: Each open row is fixed or deferred with an accepted reason; open: 0.
result: [pending]

### 6. Real Windows (VERI-02): fresh install, rerun after a Temurin upgrade, -DryRun, Windows PowerShell 5.1
expected: Truths 02-03 #9 and #10 hold; JAVA_HOME saved to the real User scope and removed by uninstall.
result: [pending]

### 7. Push main and confirm both GitHub Actions jobs pass on the Phase 2 head
expected: ubuntu-latest and macos-latest both green.
result: [pending]

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps
