---
status: diagnosed
phase: 02-consistent-java-handling
source: [02-VERIFICATION.md]
started: 2026-10-15T01:09:27Z
updated: 2026-10-15T01:30:46.002Z
audit_acknowledged:
  milestone: v1
  at: 2026-10-15
  gap_snapshot: "diagnosed::scenarios=0"
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
  root_cause: "Linux install_jdk die message prints the first 3 lines of java -version unfiltered (02-06 IN-04 fix), contradicting 02-01 T-02-02 which forbids printing that output"
  artifacts:
    - path: "rea-install-linux.sh"
      issue: "die at line ~380 pipes java -version 2>&1 straight to head -3"
  missing:
    - "Insert grep -v '^Picked up' before head -3 (keep the die firing if grep matches nothing); add a test.sh case with a picked-up stub JDK that fails jdk_usable and assert the die text has no Picked up line"
  debug_session: "02-REVIEW.md (diagnosed and reproduced by code review)"

- gap_id: G-02-2
  truth: "A macOS --no-ghidra rerun that replaces a set, non-21 JAVA_HOME with the script's own JDK prints the D-04 warning (review WR-01)"
  status: failed
  reason: "User reported: fix (apply the split-clause fix from 02-REVIEW.md WR-01 plus a test.sh case)"
  severity: major
  test: 2
  root_cause: "write_profile joins the equal-path clause and the owned-but-unusable clause in one condition, so replacing a set non-21 JAVA_HOME prints no D-04 warning (02-REVIEW WR-01)"
  artifacts:
    - path: "rea-install-macos.sh"
      issue: "write_profile JAVA_HOME condition (~lines 224-232)"
  missing:
    - "Split the condition per 02-REVIEW WR-01 Fix and warn when a set value is replaced; test.sh case: ledger brew:openjdk@21, JAVA_HOME=jdks/17, write_profile only, expect block exports ours and output contains \"not JDK 21 or newer\""
  debug_session: "02-REVIEW.md (diagnosed and reproduced by code review)"

- gap_id: G-02-3
  truth: "A macOS --no-ghidra rerun whose owned openjdk@21 no longer runs gives the same result from any shell: JAVA_HOME is left out of the block and a warning says to rerun without --no-ghidra (review WR-03)"
  status: failed
  reason: "User reported: fix (apply the WR-03 guard from 02-REVIEW.md together with WR-01, plus test.sh cases)"
  severity: major
  test: 3
  root_cause: "write_profile accepts JAVA_HOME == ours without checking it runs when install_jdk did not run (--no-ghidra), so result depends on caller shell (02-REVIEW WR-03)"
  artifacts:
    - path: "rea-install-macos.sh"
      issue: "write_profile JAVA_HOME condition (same edit as G-02-2)"
  missing:
    - "Outside jdk_chosen, require jdk_usable \"$ours\" and warn \"the script's $JDK_FORMULA at $ours does not run ... Rerun without --no-ghidra\"; test.sh cases for JAVA_HOME=ours and unset, both expect 0 JAVA_HOME lines and the warning"
  debug_session: "02-REVIEW.md (diagnosed and reproduced by code review)"

- gap_id: G-02-4
  truth: "On Windows, a saved JAVA_HOME whose folder has no bin\\java.exe is treated as dead and replaced with Temurin's folder (review WR-02)"
  status: failed
  reason: "User reported: fix (test for bin\\java.exe, update Set-UserEnv comment and log text, add a pwsh driver case with a leftover lib-only folder)"
  severity: major
  test: 4
  root_cause: "The Windows replace rule tests whether the saved JAVA_HOME folder exists, not whether bin\\java.exe exists; MSI leaves non-empty folders behind (02-REVIEW WR-02)"
  artifacts:
    - path: "rea-install-windows.ps1"
      issue: "$gone computation (~lines 204-207), Set-UserEnv comment (~122), log text (~130)"
  missing:
    - "Use Test-Path on Join-Path $userJava bin java.exe -PathType Leaf; reword comment/log to \"has no java.exe\"; add a pwsh driver case with a leftover lib-only folder expecting the setx line"
  debug_session: "02-REVIEW.md (diagnosed and reproduced by code review)"

- gap_id: G-02-5
  truth: "jdk_owned on macOS checks only the script's own profile block for export JAVA_HOME= lines, so a user's own JAVA_HOME line does not trigger brew --prefix or count as ownership (review IN-01)"
  status: failed
  reason: "User accepted disposition in test 5: fix IN-01 (limit both greps to the PROFILE_BEGIN..PROFILE_END range, add an IN-03 case with a user export JAVA_HOME line)"
  severity: minor
  test: 5
  root_cause: "jdk_owned greps the whole profile for export JAVA_HOME= instead of only the script block (02-REVIEW IN-01)"
  artifacts:
    - path: "rea-install-macos.sh"
      issue: "jdk_owned (~lines 156, 160-163)"
  missing:
    - "Restrict both greps to sed -n \"/^$PROFILE_BEGIN$/,/^$PROFILE_END$/p\"; add an IN-03 test.sh case whose profile has a user export JAVA_HOME line outside the block"
  debug_session: "02-REVIEW.md (diagnosed and reproduced by code review)"

- gap_id: G-02-6
  truth: "The project has no GitHub Actions; all testing is local (test.sh under /bin/bash 3.2 on macOS and ./test.sh in a Linux container)"
  status: failed
  reason: "User decided during UAT test 7: we don't need any GitHub Actions; all release testing is local"
  severity: minor
  test: 7
  root_cause: "Phase 1 added .github/workflows/test.yml and docs describe CI as a verification step"
  artifacts:
    - path: ".github/workflows/test.yml"
      issue: "CI workflow the user no longer wants"
    - path: ".planning/ROADMAP.md, .planning/REQUIREMENTS.md, .claude/CLAUDE.md"
      issue: "references to GitHub Actions / CI as verification"
  missing:
    - "Delete .github/workflows/test.yml and reword CI references to local test.sh runs (macOS Bash 3.2 + Linux container)"
  debug_session: ""

## Deferred Follow-Ups

- test: 5
  idea: "Review IN-02: dry runs on a machine without npm die at npm prefix --global (macOS rea-install-macos.sh:308, Windows rea-install-windows.ps1:266); use a placeholder prefix in dry run as Linux does with NPM_PREFIX"
  deferred_at: 2026-10-14
