---
status: testing
phase: 02-consistent-java-handling
source: [02-VERIFICATION.md]
started: 2026-10-14T21:42:27Z
updated: 2026-10-14T21:42:27Z
---

## Current Test

number: 1
name: Decide review WR-03 (macOS): after a full install, rerun `./rea-install-macos.sh install --no-ghidra --with-extras` once from a new terminal (sourced block) and once from a shell with JAVA_HOME unset
expected: |
  A decided, documented rule. Today the sourced shell keeps `export JAVA_HOME="<openjdk@21 home>"` and the unsourced shell drops it (both reproduced by this verifier, cases C and D). Linux drops it in both shells in the same scenario. Either make macOS deterministic (review WR-03 fix) or accept it as a known limitation for DOCS-01
awaiting: user response

## Tests

### 1. Decide review WR-03 (macOS): after a full install, rerun `./rea-install-macos.sh install --no-ghidra --with-extras` once from a new terminal (sourced block) and once from a shell with JAVA_HOME unset
expected: A decided, documented rule. Today the sourced shell keeps `export JAVA_HOME="<openjdk@21 home>"` and the unsourced shell drops it (both reproduced by this verifier, cases C and D). Linux drops it in both shells in the same scenario. Either make macOS deterministic (review WR-03 fix) or accept it as a known limitation for DOCS-01
result: [pending]

### 2. Decide review WR-01 (Windows): ledger holds env:JAVA_HOME and the user later points their user JAVA_HOME somewhere else, then reruns install
expected: A decided rule. Today (reproduced) any user value is replaced once the session JAVA_HOME is not JDK 21+, and the log claims it was 'set by this script earlier'. That includes (a) an existing JDK 17, which T-02-22 accepted, and (b) a usable JDK 22 saved with setx while the running terminal still holds the old dead Temurin path. Case (b) falsifies T-02-22's claim that a usable JDK 21+ never reaches the replace path. Fix (replace only when the saved value is dead, per the review) or accept with a corrected log message
result: [pending]

### 3. Resolve judgment-tier prohibition 02-05 #2 ('MUST NOT change any session or persistent environment variable during -DryRun'), which the LLM judge rates VIOLATED
expected: Install-Winget returns before Update-SessionPath when -DryRun is set (review WR-02 one-line fix), or the user accepts it. Reproduced: with $DryRun = $true, Install-Jdk -> Install-Winget calls Update-SessionPath, which rewrites $env:Path in the caller's process
result: [pending]

### 4. Triage the 9 open findings in 02-REVIEW-DISPOSITION.md (re-review WR-01..WR-04, IN-01..IN-05)
expected: Each one fixed or deferred with an 'accepted' reason. Also restore, if still wanted, the 2026-10-14 accepted decisions for the earlier WR-01, WR-02, WR-04 and IN-01..IN-05. The gate dropped them when the re-review reused those IDs; they are recoverable from commit 4d8a918
result: [pending]

### 5. Real Windows (VERI-02): rerun after a Temurin upgrade; -DryRun in-process; PowerShell 5.1 java -version parsing; first java on the refreshed PATH is Temurin's
expected: User JAVA_HOME is rewritten to the new Temurin folder; dry run leaves JAVA_HOME and the user scope untouched; backstop truths 22 and 23 hold
result: [pending]

### 6. Confirm or reject the 15 judgment-tier prohibition verdicts (9 from 02-01..02-03, 6 from 02-04/02-05) in the Prohibitions table
expected: Human confirmation of each LLM-judge verdict
result: [pending]

### 7. Push main (46 local commits ahead of origin/main) and confirm both GitHub Actions jobs pass
expected: ubuntu-latest and macos-latest jobs green on the Phase 2 head
result: [pending]

### 8. Resolve the MVP-mode discrepancy: ROADMAP marks Phase 2 `mode: mvp` but its goal is not a user story
expected: Either run /gsd-mvp-phase 2 or drop `mode: mvp`
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps
