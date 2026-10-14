---
status: diagnosed
phase: 02-consistent-java-handling
source: [02-VERIFICATION.md]
started: 2026-10-14T21:42:27Z
updated: 2026-10-14T21:50:45.503Z
---

## Current Test

[testing complete]

## Tests

### 1. Decide review WR-03 (macOS): after a full install, rerun `./rea-install-macos.sh install --no-ghidra --with-extras` once from a new terminal (sourced block) and once from a shell with JAVA_HOME unset
expected: A decided, documented rule. Today the sourced shell keeps `export JAVA_HOME="<openjdk@21 home>"` and the unsourced shell drops it (both reproduced by this verifier, cases C and D). Linux drops it in both shells in the same scenario. Either make macOS deterministic (review WR-03 fix) or accept it as a known limitation for DOCS-01
result: issue
reported: "Go with your recommendation." (decision: fix WR-03; make the macOS rerun keep or drop JAVA_HOME based on the ledger, not the caller's environment)
severity: major

### 2. Decide review WR-01 (Windows): ledger holds env:JAVA_HOME and the user later points their user JAVA_HOME somewhere else, then reruns install
expected: A decided rule. Today (reproduced) any user value is replaced once the session JAVA_HOME is not JDK 21+, and the log claims it was 'set by this script earlier'. That includes (a) an existing JDK 17, which T-02-22 accepted, and (b) a usable JDK 22 saved with setx while the running terminal still holds the old dead Temurin path. Case (b) falsifies T-02-22's claim that a usable JDK 21+ never reaches the replace path. Fix (replace only when the saved value is dead, per the review) or accept with a corrected log message
result: issue
reported: "Go with your recommendation on any of these." (decision: fix WR-01; replace the saved user JAVA_HOME only when it points at a folder that no longer exists, and correct the log text)
severity: major

### 3. Resolve judgment-tier prohibition 02-05 #2 ('MUST NOT change any session or persistent environment variable during -DryRun'), which the LLM judge rates VIOLATED
expected: Install-Winget returns before Update-SessionPath when -DryRun is set (review WR-02 one-line fix), or the user accepts it. Reproduced: with $DryRun = $true, Install-Jdk -> Install-Winget calls Update-SessionPath, which rewrites $env:Path in the caller's process
result: issue
reported: "Go with your recommendation on any of these." (decision: apply the WR-02 fix; Install-Winget returns before Add-Record/Update-SessionPath under -DryRun, with a driver assertion)
severity: major

### 4. Triage the 9 open findings in 02-REVIEW-DISPOSITION.md (re-review WR-01..WR-04, IN-01..IN-05)
expected: Each one fixed or deferred with an 'accepted' reason. Also restore, if still wanted, the 2026-10-14 accepted decisions for the earlier WR-01, WR-02, WR-04 and IN-01..IN-05. The gate dropped them when the re-review reused those IDs; they are recoverable from commit 4d8a918
result: issue
reported: "Go with your recommendation on any of these." (triage: WR-01..WR-03 fix via tests 1-3; WR-04 fix, handle the nested Temurin layout and stop promising a rerun recovers; IN-03 fix, check the ledger before calling jdk_home; IN-04 fix, show java -version output in the die; IN-05 fix, add the missing tests; IN-01 and IN-02 defer, accepted: pre-existing no-brew dry-run path, out of phase scope; restore the accepted decisions dropped from 4d8a918)
severity: major

### 5. Real Windows (VERI-02): rerun after a Temurin upgrade; -DryRun in-process; PowerShell 5.1 java -version parsing; first java on the refreshed PATH is Temurin's
expected: User JAVA_HOME is rewritten to the new Temurin folder; dry run leaves JAVA_HOME and the user scope untouched; backstop truths 22 and 23 hold
result: blocked
blocked_by: physical-device
reason: "No real Windows machine available to this session; VERI-02 needs a real Windows 10+/PowerShell 5.1 run."

### 6. Confirm or reject the 15 judgment-tier prohibition verdicts (9 from 02-01..02-03, 6 from 02-04/02-05) in the Prohibitions table
expected: Human confirmation of each LLM-judge verdict
result: pass
note: "Confirmed by Claude at the user's delegation, not by independent human review. Holds: 02-01..02-03 (9, regression tests pass), 02-04 #1-#3, 02-05 #3. 02-05 #1 holds as worded; its residual is gap G-02-2. 02-05 #2 VIOLATED is confirmed; gap G-02-3."

### 7. Push main (46 local commits ahead of origin/main) and confirm both GitHub Actions jobs pass
expected: ubuntu-latest and macos-latest jobs green on the Phase 2 head
result: blocked
blocked_by: other
reason: "Recommendation: push once the gap-closure fixes land, so CI runs on the corrected Phase 2 head."

### 8. Resolve the MVP-mode discrepancy: ROADMAP marks Phase 2 `mode: mvp` but its goal is not a user story
expected: Either run /gsd-mvp-phase 2 or drop `mode: mvp`
result: pass
note: "Dropped `**Mode:** mvp` from Phase 2 in ROADMAP.md; the goal is a cross-platform rule, not a user story."

## Summary

total: 8
passed: 2
issues: 4
pending: 0
skipped: 0
blocked: 2

## Gaps

- gap_id: G-02-1
  truth: "macOS `install --no-ghidra` rerun writes the same JAVA_HOME profile line whether or not the caller's shell has JAVA_HOME set; the decision depends on what the ledger says was installed (review WR-03)"
  status: failed
  reason: "User reported: Go with your recommendation. (decision: fix WR-03 rather than accept it as a known limitation)"
  severity: major
  test: 1
  root_cause: "write_profile keeps our JAVA_HOME only when the caller environment already holds our path; the ownership decision (jdk_owned) is made only inside install_ghidra, which a --no-ghidra rerun never reaches (02-REVIEW.md WR-03, reproduced)"
  artifacts:
    - path: "rea-install-macos.sh"
      issue: "write_profile JAVA_HOME clause (~211-219) depends on $JAVA_HOME; jdk_owned used only at ~193-200"
    - path: "test.sh"
      issue: "no --no-ghidra rerun case"
    missing:
    - "write_profile decides from jdk_owned (ledger brew:openjdk@21 or block export) plus jdk_usable user check, not from the caller environment"
    - "test: --no-ghidra --with-extras rerun with JAVA_HOME unset keeps our export"
  debug_session: "02-REVIEW.md (reproduced by gsd-code-reviewer)"

- gap_id: G-02-2
  truth: "Windows rerun with env:JAVA_HOME in the ledger replaces the saved user JAVA_HOME only when it points at a folder that no longer exists, and the log never claims the script set a value it did not (review WR-01)"
  status: failed
  reason: "User reported: Go with your recommendation on any of these. (decision: fix WR-01)"
  severity: major
  test: 2
  root_cause: "Install-Jdk passes -Replace:$owned, where $owned is true whenever the ledger has env:JAVA_HOME, so Set-UserEnv replaces any current user value, and its message says "set by this script earlier" (02-REVIEW.md WR-01, reproduced)"
  artifacts:
    - path: "rea-install-windows.ps1"
      issue: "Install-Jdk ~200-202 and Set-UserEnv ~121-134 message at ~128"
    - path: "test.sh"
      issue: "CR-01 case covers only a dead saved value"
    missing:
    - "replace only when owned AND the saved value is not an existing folder (Test-Path)"
    - "accurate log text for the replace"
    - "test: owned ledger + existing user JDK keeps the user value"
  debug_session: "02-REVIEW.md (reproduced by gsd-code-reviewer)"

- gap_id: G-02-3
  truth: "Windows -DryRun changes no session or persistent environment variable, including $env:Path (review WR-02, prohibition 02-05 #2)"
  status: failed
  reason: "User reported: Go with your recommendation on any of these. (decision: apply the WR-02 fix)"
  severity: major
  test: 3
  root_cause: "Install-Winget calls Update-SessionPath unconditionally; Invoke-Step and Add-Record honor -DryRun but the next line rewrites $env:Path; the test driver stubs Update-SessionPath so the dry-run checks cannot see it (02-REVIEW.md WR-02, reproduced)"
  artifacts:
    - path: "rea-install-windows.ps1"
      issue: "Install-Winget"
    - path: "test.sh"
      issue: "Update-SessionPath stub ~473"
    missing:
    - "`if ($DryRun) { return }` after Invoke-Step in Install-Winget"
    - "stub sets $script:PathRefreshed; assert it stays $false after the dry-run Install-Jdk case"
  debug_session: "02-REVIEW.md (reproduced by gsd-code-reviewer)"

- gap_id: G-02-4
  truth: "Every open finding in 02-REVIEW-DISPOSITION.md is fixed or deferred with an accepted reason, and the accepted decisions dropped from 4d8a918 are restored (WR-04, IN-03, IN-04, IN-05 fixed; IN-01, IN-02 deferred)"
  status: failed
  reason: "User reported: Go with your recommendation on any of these. (triage recorded in test 4)"
  severity: major
  test: 4
  root_cause: "Re-review findings WR-04, IN-03, IN-04, IN-05 open; IN-01/IN-02 not yet dispositioned; the gate dropped the earlier accepted dispositions when the re-review reused their IDs (02-REVIEW.md, 02-REVIEW-DISPOSITION.md, commit 4d8a918)"
  artifacts:
    - path: "rea-install-linux.sh"
      issue: "install_jdk layout check ~360-364 (WR-04); jdk_usable die ~367 (IN-04)"
    - path: "rea-install-macos.sh"
      issue: "install_ghidra calls jdk_home before ledger/ghidraRun check ~193-200 (IN-03)"
    - path: "test.sh"
      issue: "missing empty-release guard test (IN-05)"
    - path: ".planning/phases/02-consistent-java-handling/02-REVIEW-DISPOSITION.md"
      issue: "open rows; dropped accepted rows"
    missing:
    - "WR-04: move a nested bin/java dir into place; die message must not promise a rerun recovers"
    - "IN-03: check ledger/ghidraRun before calling jdk_home"
    - "IN-04: include java -version output (head -3) in the die"
    - "IN-05: test the empty-release guard"
    - "IN-01, IN-02: disposition deferred, accepted (pre-existing no-brew dry-run path, out of phase scope)"
    - "restore the earlier accepted decisions from 4d8a918 under non-colliding IDs"
  debug_session: "02-REVIEW.md (reproduced by gsd-code-reviewer)"
