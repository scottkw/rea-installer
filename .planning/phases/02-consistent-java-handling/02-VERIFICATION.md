---
phase: 02-consistent-java-handling
verified: 2026-10-14T21:37:04Z
status: human_needed
score: 36/39 must-haves verified
covered_files:
  - ".planning/phases/02-consistent-java-handling/02-01-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-01-SUMMARY.md"
  - ".planning/phases/02-consistent-java-handling/02-02-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-02-SUMMARY.md"
  - ".planning/phases/02-consistent-java-handling/02-03-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-03-SUMMARY.md"
  - ".planning/phases/02-consistent-java-handling/02-04-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-04-SUMMARY.md"
  - ".planning/phases/02-consistent-java-handling/02-05-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-05-SUMMARY.md"
  - "rea-install-linux.sh"
  - "rea-install-macos.sh"
  - "rea-install-windows.ps1"
  - "test.sh"
covered_digest: "v3:sha256:4b72f3bf56db5429beb907e110f14115f2b0e20d035bf3054e3df654f4510045"
behavior_unverified: 0
overrides_applied: 1
overrides:
  - must_have: "With JAVA_HOME pointing at JDK 21 or newer, it reuses the existing one and installs no JDK"
    reason: "On macOS, Homebrew's ghidra formula depends on openjdk@21, so installing Ghidra pulls in a JDK regardless; the script reuses the user's JAVA_HOME, writes no JAVA_HOME line, and records openjdk@21 so uninstall removes it. Holds literally with --no-ghidra or when Ghidra is already present."
    accepted_by: "Ken Scott"
    accepted_at: "2026-10-14T20:30:00Z"
re_verification:
  previous_status: gaps_found
  previous_score: 23/27
  gaps_closed:
    - "ROADMAP SC3 / JAVA-04: macOS rerun with JAVA_HOME unset now keeps the script's openjdk@21 JAVA_HOME in the single block (jdk_owned + install_ghidra, commit 4289e42)"
    - "ROADMAP SC1 macOS + Ghidra: closed by the accepted override above (no code change)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Decide review WR-03 (macOS): after a full install, rerun `./rea-install-macos.sh install --no-ghidra --with-extras` once from a new terminal (sourced block) and once from a shell with JAVA_HOME unset"
    expected: "A decided, documented rule. Today the sourced shell keeps `export JAVA_HOME=\"<openjdk@21 home>\"` and the unsourced shell drops it (both reproduced by this verifier, cases C and D). Linux drops it in both shells in the same scenario. Either make macOS deterministic (review WR-03 fix) or accept it as a known limitation for DOCS-01"
    why_human: "Product decision. ROADMAP SC3 names `--with-extras`/`--with-android` reruns with Ghidra at its default, and that case passes. The goal's 'survives reruns' does not say whether a rerun that deselects Ghidra must keep JAVA_HOME"
  - test: "Decide review WR-01 (Windows): ledger holds env:JAVA_HOME and the user later points their user JAVA_HOME somewhere else, then reruns install"
    expected: "A decided rule. Today (reproduced) any user value is replaced once the session JAVA_HOME is not JDK 21+, and the log claims it was 'set by this script earlier'. That includes (a) an existing JDK 17, which T-02-22 accepted, and (b) a usable JDK 22 saved with setx while the running terminal still holds the old dead Temurin path. Case (b) falsifies T-02-22's claim that a usable JDK 21+ never reaches the replace path. Fix (replace only when the saved value is dead, per the review) or accept with a corrected log message"
    why_human: "Conflicts with locked D-05 as refined by user decision 3. The JAVA-02 rule itself holds: it is judged on the session JAVA_HOME, as on Linux and macOS"
  - test: "Resolve judgment-tier prohibition 02-05 #2 ('MUST NOT change any session or persistent environment variable during -DryRun'), which the LLM judge rates VIOLATED"
    expected: "Install-Winget returns before Update-SessionPath when -DryRun is set (review WR-02 one-line fix), or the user accepts it. Reproduced: with $DryRun = $true, Install-Jdk -> Install-Winget calls Update-SessionPath, which rewrites $env:Path in the caller's process"
    why_human: "Judgment-tier prohibition verdicts are non-authoritative in autonomous verify. The code dates from the initial commit c403774, not this phase. It still contradicts the project's 'dry-run must not change anything' constraint and this plan's prohibition"
  - test: "Triage the 9 open findings in 02-REVIEW-DISPOSITION.md (re-review WR-01..WR-04, IN-01..IN-05)"
    expected: "Each one fixed or deferred with an 'accepted' reason. Also restore, if still wanted, the 2026-10-14 accepted decisions for the earlier WR-01, WR-02, WR-04 and IN-01..IN-05. The gate dropped them when the re-review reused those IDs; they are recoverable from commit 4d8a918"
    why_human: "Plan 02-05 truth 5 ('open count is 0') held at 4d8a918 and was reset by the later review gate run (198ba51). Triage is a human decision"
  - test: "Real Windows (VERI-02): rerun after a Temurin upgrade; -DryRun in-process; PowerShell 5.1 java -version parsing; first java on the refreshed PATH is Temurin's"
    expected: "User JAVA_HOME is rewritten to the new Temurin folder; dry run leaves JAVA_HOME and the user scope untouched; backstop truths 22 and 23 hold"
    why_human: "Unix pwsh has no User env scope (the driver stands in through Get-UserEnv), and A1/A2 can only be checked on Windows"
  - test: "Confirm or reject the 15 judgment-tier prohibition verdicts (9 from 02-01..02-03, 6 from 02-04/02-05) in the Prohibitions table"
    expected: "Human confirmation of each LLM-judge verdict"
    why_human: "Judgment-tier prohibitions are never silently passed"
  - test: "Push main (46 local commits ahead of origin/main) and confirm both GitHub Actions jobs pass"
    expected: "ubuntu-latest and macos-latest jobs green on the Phase 2 head"
    why_human: "CI has not run on any Phase 2 commit; pushing is the user's call"
  - test: "Resolve the MVP-mode discrepancy: ROADMAP marks Phase 2 `mode: mvp` but its goal is not a user story"
    expected: "Either run /gsd-mvp-phase 2 or drop `mode: mvp`"
    why_human: "Roadmap edit"
---

# Phase 2: Consistent Java Handling Verification Report

**Phase Goal:** Linux, macOS and Windows all follow one rule (reuse an existing `JAVA_HOME` only if it is JDK 21 or newer, otherwise install and record the script's own JDK) and the script's own `JAVA_HOME` survives reruns
**Verified:** 2026-10-14T21:37:04Z (code at HEAD `198ba51`; gap-closure commits `4289e42`, `f61a0b8`, `a1f62a6`, `bccc843`, `e0e8d34`, `4d8a918`, all ancestors of HEAD)
**Status:** human_needed
**Re-verification:** Yes, after gap closure (plans 02-04 and 02-05)

## MVP Mode Discrepancy (unchanged)

ROADMAP still sets `**Mode:** mvp`, and the goal is still not a user story. As in the first report, this one verifies goal-backward against the four roadmap success criteria and every plan truth, and has no User Flow Coverage table.

## Goal Achievement

### Roadmap Success Criteria (contract)

| # | Success criterion | Status | Evidence |
|---|---|---|---|
| SC1 | JDK 17 `JAVA_HOME` gets the script's own JDK 21; JDK 21+ is reused and no JDK is installed (Linux, macOS, Windows) | ✓ PASSED (override) | **Override:** Homebrew's `ghidra` depends on `openjdk@21`, so macOS records it. Accepted by Ken Scott on 2026-10-14T20:30:00Z. Regression check: the Linux, macOS and Windows JAVA-02 replace/reuse tests all PASS (my `/bin/bash ./test.sh` run and the ubuntu:24.04 run). In a real-brew macOS dry run, case F (owned ledger, Ghidra present, JDK 17 `JAVA_HOME`) warns, plans `brew install openjdk@21` and exports ours; case E (JDK 21 stub) logs `Using JDK at ...` and writes no `JAVA_HOME`. |
| SC2 | macOS with a JDK 21+ `JAVA_HOME` writes no `JAVA_HOME` line | ✓ VERIFIED | `PASS: JAVA-03 macOS reused JDK 21 JAVA_HOME is not written to the profile` and the new `PASS: JAVA-03 macOS rerun reuses a JDK 21 JAVA_HOME even when it owns openjdk@21`. Real-brew dry run case E: the block holds only the extras exports. |
| SC3 | macOS: two `--with-extras`/`--with-android` runs in a row leave one block still exporting our openjdk@21 `JAVA_HOME` | ✓ VERIFIED | **Gap closed.** `jdk_owned` (`rea-install-macos.sh:155-157`) reads the ledger line `brew:openjdk@21` or the block's own export line. `install_ghidra`'s "already available" branch calls `install_jdk` when the script owns the JDK (`:198-200`). The reworked Darwin test no longer supplies `JAVA_HOME` (`test.sh:348`, `unset JAVA_HOME; install_ghidra; ...`) and PASSES. It covers the block-line path; the ledger path is a separate all-OS test that PASSES on macOS and ubuntu. My own real-brew dry runs with `JAVA_HOME` unset and `ghidraRun` on PATH: case A (ledger only) and case B (old block only) each plan exactly one block with `export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"`; case G (`--no-ghidra --with-android`, unset) also keeps it. See the WR-03 note below for a flag combination outside this criterion. |
| SC4 | Windows: after Temurin, session `JAVA_HOME` = Temurin folder derived from `java` on PATH, saved as a user variable that uninstall removes, MSI-independent | ✓ VERIFIED (Unix pwsh + code review, as the criterion specifies) | `Install-Jdk` (`rea-install-windows.ps1:183-203`): `Update-SessionPath`, `Get-Command java`, `Test-JdkUsable`, `$env:JAVA_HOME = $dir`, `Set-UserEnv 'JAVA_HOME' $dir -Replace:$owned`. A real `Set-UserEnv` run records `env:JAVA_HOME`. `PASS: JAVA-01 Windows Install-Jdk sets JAVA_HOME from the java on PATH and records it`, now on a fresh ledger. My mutation run (the `Add-Record "winget:$Id"` line deleted from a copy) printed exactly `FAIL: JAVA-01 Windows Install-Jdk sets JAVA_HOME from the java on PATH and records it`, so the assertion can fail. Real Windows is deferred to VERI-02. |

### Plan Truths

Truths 1-21 and the two backstops come from plans 02-01 to 02-03, verified in the first report. They were regression-checked here by the same named tests, all PASS. Only their status is repeated.

| # | Truth (plan) | Status | Evidence |
|---|---|---|---|
| 1-9 | 02-01 Linux rule, predicate, self-check, DRY-01 | ✓ VERIFIED | All `JAVA-02 Linux ...` and `jdk_usable` rows PASS in /bin/bash 3.2 and ubuntu:24.04; `PASS: DRY-01 Linux install --dry-run --with-android in fresh ubuntu:24.04` |
| 10-14 | 02-02 macOS rule, ledger, `write_profile`, lint | ✓ VERIFIED | Step 4 moved into `install_ghidra`. The order install_jdk → `brew_install "$JDK_FORMULA"` → `brew_install ghidra` is kept (`:202-207`). shellcheck clean, `bash -n` under 3.2 OK |
| 15-21 | 02-03 Windows rule | ✓ VERIFIED | All `JAVA-0x Windows ...` driver cases PASS. Truth 20's placeholder was superseded by the 02-05 truth 3 below (user decision, WR-03) |
| 22 | 02-03 backstop: rerun with equal user value is silent | ⚠️ insufficient_spec | Real Windows only (VERI-02) |
| 23 | 02-03 backstop: first `java` on refreshed PATH is Temurin's | ⚠️ insufficient_spec | Real Windows only (VERI-02) |
| 24 | 02-04: rerun after a block write, JAVA_HOME unset, Ghidra on PATH, Android off → one block, one export of ours | ✓ VERIFIED | Same as SC3 (roadmap wording kept); Darwin test PASS; case B dry run |
| 25 | 02-04: same, ledger `brew:openjdk@21` and no earlier block → block exports ours | ✓ VERIFIED | `PASS: JAVA-04 macOS rerun with JAVA_HOME unset restores its own JAVA_HOME from the ledger` (macOS and ubuntu); dry-run case A |
| 26 | 02-04: owned ledger + usable user JDK 21+ → reused, no `JAVA_HOME` line | ✓ VERIFIED | `PASS: JAVA-03 macOS rerun reuses a JDK 21 JAVA_HOME even when it owns openjdk@21`; dry-run case E |
| 27 | 02-04: JAVA-04 test unsets JAVA_HOME and uses the production `install_ghidra` path | ✓ VERIFIED | `test.sh:348`; `grep -cF 'export JAVA_HOME="$(jdk_home)"' test.sh` = 0 |
| 28 | 02-04: `brew --prefix` failure → real run dies naming it, never `/libexec`; no-brew dry run plans the default prefix with a warning | ✓ VERIFIED | `PASS: JAVA-02 macOS install_jdk stops when brew cannot locate openjdk@21` and `... dry run without brew plans the default Homebrew JDK path`. All 3 `jdk_home` callers are plain assignments (non-assignment count 0, assignment count 3), so `set -e` sees the `die`. Review IN-01: the fallback is unreachable in a full no-brew dry run (step 3 `$(brew --prefix)` stops first); the truth is about `jdk_home` and holds |
| 29 | 02-04: Linux broken `~/.rea-installer/jdk` → warn, remove, re-download; dry run only prints; user JDK untouched | ✓ VERIFIED | Three new Linux tests PASS (ubuntu and macOS). My container dry run with a broken own JDK and `JAVA_HOME=/jdks/17` printed the D-04 warning, `does not run; downloading it again.`, `$ rm -rf /root/.rea-installer/jdk`, `Would download Temurin 21`, `export JAVA_HOME="/root/.rea-installer/jdk"`, and the broken `bin/java` was still on disk afterwards |
| 30 | 02-04: archive without `bin/java` is removed and the run stops before the move | ✓ VERIFIED | `PASS: JAVA-02 Linux install_jdk stops on a Temurin archive without bin/java`; `install_jdk` has exactly two `rm -rf` targets (`"$STATE_DIR/jdk"`, `"$dir"`); an empty-`release` guard (`:358`) protects `$TOOLS_DIR`. Review WR-04: the message "rerun to download it again" over-promises for a deterministic layout mismatch (warning only) |
| 31 | 02-04/02-05: lint, header, guard, phase gate | ✓ VERIFIED | shellcheck clean on all three bash files; `bash -n` OK under 3.2; GUARD tests PASS; first diff hunks start at macOS line 132, Linux 337, Windows 32 (headers untouched). My runs: `/bin/bash ./test.sh` exit 0, 83 passed, 0 failed, 2 skipped (Linux only); ubuntu:24.04 exit 0, 54 passed, 0 failed, 10 skipped. The orchestrator reports default-bash 83/0/2 |
| 32 | 02-05: owned `env:JAVA_HOME` + stale user value → rerun replaces it | ✓ VERIFIED | `PASS: JAVA-01 Windows Install-Jdk replaces a stale user JAVA_HOME it set earlier`; red evidence in SUMMARY. See WR-01 for the over-reach |
| 33 | 02-05: not owned → user value kept with warning, session set | ✓ VERIFIED | `PASS: JAVA-01 Windows Install-Jdk leaves a user JAVA_HOME it did not set` |
| 34 | 02-05: in-process `-DryRun` keeps session `JAVA_HOME`, second call silent, nothing recorded; `Set-UserEnv` under `-DryRun` sets no session variable | ✓ VERIFIED | Two driver tests PASS; `Set-Item` is after the `$DryRun` return (awk "order ok"); my driver run: dry-run `Install-Jdk` left `JAVA_HOME` at the JDK 17 path, no ledger. `Path` is outside this truth's wording; see prohibition 02-05 #2 |
| 35 | 02-05: the records test fails when the winget record is missing | ✓ VERIFIED | My mutation run: exit 1, sole FAIL line is that test |
| 36 | 02-05: disposition record: 6 fixed, 11 accepted, open 0 | ⚠️ UNCERTAIN (superseded) | True at `4d8a918` (`open: 0`, `total: 17`, verified via `git show`). The later re-review gate (`198ba51`) reused IDs WR-01..WR-04 and IN-01..IN-05. The file now reads `open: 9`, and the earlier accepted reasons for those IDs are gone. Routed to human triage |

Roadmap SC3 absorbs 02-04 truth 1 (same claim, roadmap wording kept). The 02-04 and 02-05 phase-gate truths are merged into row 31. That leaves 4 SCs + 21 + 2 backstops + 12 new = 39 truths.

**Score:** 36/39 truths verified (1 by override; 2 backstop truths need real Windows; 1 superseded record truth needs triage; 0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `rea-install-macos.sh` | `jdk_owned`, `install_ghidra`, loud `jdk_home`, plain-assignment callers | ✓ VERIFIED | `jdk_owned()` 1, `install_ghidra()` 1, one call in `do_install` (`:267`), `brew:$JDK_FORMULA` read in `jdk_owned` |
| `rea-install-linux.sh` | `install_jdk` replaces a broken own JDK, checks `bin/java` before the move | ✓ VERIFIED | `:340-367`; both message strings present once |
| `rea-install-windows.ps1` | `Get-UserEnv`, `Set-UserEnv -Replace`, `$JdkPlanned`, `Install-Jdk -Replace:$owned` | ✓ VERIFIED | `GetEnvironmentVariable($Name, 'User')` only in `Get-UserEnv`; `Temurin JAVA_HOME>` placeholder gone; 3 non-comment `JdkPlanned` lines |
| `test.sh` | new JAVA-03/04 macOS, WR-07, WR-09 Linux, CR-01/WR-03/WR-10 pwsh checks | ✓ VERIFIED | All named checks PASS; JAVA-04 no longer presets `JAVA_HOME` |
| `02-REVIEW-DISPOSITION.md` | 17 dispositions, open 0 | ⚠️ superseded | See truth 36 |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `install_ghidra` (already-available branch) | `install_jdk` | `jdk_owned "$ours"` | WIRED | `rea-install-macos.sh:198-200` |
| `write_profile` | `jdk_home` | `ours="$(jdk_home)"` plain assignment | WIRED | `:215-216` |
| Linux `install_jdk` | `jdk_usable "$STATE_DIR/jdk"` | broken-JDK replace | WIRED | `:343-347` |
| `Install-Jdk` | `Set-UserEnv -Replace` | `$owned` from exact `env:JAVA_HOME` ledger line | WIRED | `rea-install-windows.ps1:200-202` |
| `Set-UserEnv` | `Get-UserEnv` | single User-scope reader | WIRED | `:122` |
| `Install-Jdk -DryRun` | `$JdkPlanned` | script-scope flag | WIRED | `:184`, `:190` |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full suite, Bash 3.2 (run once) | `/bin/bash ./test.sh` | exit 0; 83 passed, 0 failed, 2 skipped | ✓ PASS |
| Linux-only checks | `docker run ubuntu:24.04 bash ./test.sh` (once) | exit 0; 54 passed, 0 failed, 10 skipped | ✓ PASS |
| WR-10 mutation | copy with `Add-Record "winget:$Id"` deleted, run copied `test.sh` | exit 1; only FAIL is the records test | ✓ PASS |
| macOS SC3, ledger only (A) | real-brew `install --dry-run --yes --with-extras`, `JAVA_HOME` unset, `ghidraRun` stub | block exports our `JAVA_HOME` | ✓ PASS |
| macOS SC3, old block only (B) | same, no ledger | block exports our `JAVA_HOME` | ✓ PASS |
| macOS `--no-ghidra --with-extras` rerun, unsourced (C) | same, owned, `JAVA_HOME` unset | block has **no** `JAVA_HOME` | ⚠️ review WR-03 reproduced |
| macOS `--no-ghidra --with-extras` rerun, sourced (D) | same, `JAVA_HOME` = ours | block keeps `JAVA_HOME` | ✓ (env-dependent vs C) |
| macOS JAVA-03 on owned rerun (E) | user JDK 21 stub | `Using JDK at ...`, no `JAVA_HOME` line | ✓ PASS |
| macOS JDK 17 on owned rerun (F) | JDK 17 stub | warning, `brew install openjdk@21`, ours exported | ✓ PASS |
| Linux rerun survival | container dry run, own JDK stub, `JAVA_HOME` unset / inherited, `--with-extras` | both `export JAVA_HOME="/root/.rea-installer/jdk"` | ✓ PASS |
| Linux `--no-ghidra --with-extras` rerun | container, inherited ours | block without `JAVA_HOME` (deterministic) | ℹ️ comparison for WR-03 |
| Linux broken own JDK, dry run | container, `JAVA_HOME=/jdks/17` | warn, planned `rm -rf`, Temurin planned once, file still on disk | ✓ PASS |
| Windows WR-01 | pwsh driver, owned ledger, user value = existing JDK 17 | replaced, log says "set by this script earlier" | ⚠️ review WR-01 reproduced |
| Windows WR-01 edge | owned ledger, user value = usable JDK 22, session = dead Temurin path | user JDK 22 replaced by Temurin | ⚠️ new finding (see warnings) |
| Windows reuse | session = JDK 22 | `Using JDK at ...`, nothing replaced | ✓ PASS |
| Windows WR-02 | `$DryRun = $true`, `Install-Jdk` | `Update-SessionPath` called; `JAVA_HOME` unchanged; no ledger | ⚠️ review WR-02 reproduced |

### Probe Execution

None declared, and there is no `scripts/*/tests/probe-*.sh` in the repo. Not applicable.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| JAVA-01 | 02-03, 02-05 | Windows: `JAVA_HOME` for the session and a recorded user variable after Temurin, MSI-independent | ✓ SATISFIED (Unix pwsh + code; real Windows → VERI-02) | SC4; truths 32-35 |
| JAVA-02 | 02-01, 02-02, 02-03, 02-04 | Reuse `JAVA_HOME` only if JDK 21+, else own JDK, on every platform | ✓ SATISFIED (macOS via the accepted SC1 override) | SC1; truths 28-30. The rule is judged on the `JAVA_HOME` the script sees on all three platforms. WR-01's Windows edge overwrites a *persistent* user value; it does not reuse a non-21 JDK |
| JAVA-03 | 02-02, 02-04 | macOS never writes a user's JDK 21+ `JAVA_HOME` to the profile | ✓ SATISFIED | SC2; truth 26; case E |
| JAVA-04 | 02-02, 02-04 | macOS rerun keeps `JAVA_HOME` in the single block when it points at our JDK | ✓ SATISFIED | SC3; truths 24-25; cases A, B, G |

No orphaned requirements: REQUIREMENTS.md maps exactly JAVA-01 to JAVA-04 to Phase 2, and the plans claim all four. REQUIREMENTS.md still lists JAVA-02, JAVA-03 and JAVA-04 as "Gaps Found". The orchestrator should update the traceability table once the human items are resolved.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| (all four phase files) | - | TBD/FIXME/XXX/TODO/HACK | none found | - |
| `rea-install-windows.ps1` | 128 | Log text "set by this script earlier" is printed whenever `-Replace` is set, even when the user changed the value | ⚠️ Warning | Misleading message (WR-01) |
| `rea-install-windows.ps1` | 112 | `Update-SessionPath` runs under `-DryRun` (pre-existing since `c403774`) | ⚠️ Warning | In-process dry run rewrites `$env:Path` (WR-02) |
| `rea-install-linux.sh` | 363 | "rerun to download it again" for a deterministic layout mismatch | ⚠️ Warning | Rerun repeats the same failure (WR-04) |
| `rea-install-macos.sh` | 212 | Comment says a rerun that skips `install_jdk` keeps ours; true only when the caller's env holds it | ℹ️ Info | WR-03 |

### Warnings Requiring a Decision (re-review 02-REVIEW.md, all `open`)

None of these falsifies a roadmap criterion as worded, so none is in `gaps:`. Each is listed under Human Verification for a decision.

| ID | Finding | Verifier assessment |
|---|---|---|
| WR-01 | CR-01 fix replaces any owned user `JAVA_HOME` | Reproduced. The JDK 17 case was accepted in advance as T-02-22, and it matches what the Linux/macOS profile blocks do to a JDK 17. I also reproduced a case the review did not name: a **usable JDK 22** saved by the user (for example with `setx`, which does not update the running terminal) is overwritten when the session still holds the old dead Temurin path. That falsifies T-02-22's mitigation claim. Likelihood is low, impact is a silently changed user setting. The review's fix (replace only when the saved value is dead) closes both cases |
| WR-02 | Windows dry run rewrites session `Path` | Reproduced. Pre-existing code, outside truth 34's wording, but it violates plan 02-05's own prohibition #2 and the project's dry-run constraint. One-line fix |
| WR-03 | macOS `--no-ghidra` rerun is environment-dependent | Reproduced (C vs D). It is outside SC3's scenario. Linux drops `JAVA_HOME` deterministically there, so neither platform keeps it; macOS is merely nondeterministic. This is a product decision, not a contract failure |
| WR-04 | Linux layout-mismatch message over-promises | Loud and safe, but a rerun cannot recover. Message fix at minimum |
| IN-01..IN-05 | No-brew dry-run reach, repeated warning, new `brew --prefix` dependency, env-caused re-download, test gaps | Informational; IN-05 lists the missing tests for WR-01..WR-03 |

### Prohibitions (judgment tier, autonomous verify): unverified, human review recommended

The verdicts below come from an LLM judge and are not authoritative. None was silently passed.

| Plan | Prohibition | Judge verdict |
|---|---|---|
| 02-01 (3), 02-02 (3), 02-03 (3) | See the first report | Unchanged: hold, with the residuals noted there |
| 02-04 #1 | Must not write a user's `JAVA_HOME` or restore ours over a usable user JDK 21+ | Holds: `install_jdk` returns at `jdk_usable` before any export; test and case E |
| 02-04 #2 | Linux `install_jdk` removes only `~/.rea-installer/jdk` and the fresh extract | Holds: the only two `rm -rf` targets are `"$STATE_DIR/jdk"` and `"$dir"`; the user JDK 17 is byte-identical in the test; the empty-`release` guard prevents `$dir = $TOOLS_DIR` |
| 02-04 #3 | Dry run changes nothing (Linux removal via `run`, macOS fallback only prints) | Holds: the container dry run left the broken `bin/java` on disk |
| 02-05 #1 | Overwrite a persistent user `JAVA_HOME` only when the ledger shows the script set it | Holds as worded (gated on exact `env:JAVA_HOME`). Residual: the ledger shows the script set the variable *once*, not that the current value is ours (WR-01) |
| 02-05 #2 | Must not change any session or persistent env var during `-DryRun` | **VIOLATED (flagged):** `$env:Path` is rewritten via `Install-Winget` → `Update-SessionPath` (reproduced). Pre-existing line |
| 02-05 #3 | Use only a disposition value the gate preserves | Held at `4d8a918` (`deferred` + `accepted ...`). The later gate run still dropped those rows, because it reused the IDs, not because of the values |

### Human Verification Required

1. **WR-03 macOS `--no-ghidra` rerun:** decide the rule (deterministic keep-when-owned, or match Linux and drop), or accept it as a DOCS-01 known limitation.
2. **WR-01 Windows owned-`JAVA_HOME` replacement:** fix (replace only a dead saved value) or accept, including the JDK 22/stale-session edge, and correct the log text either way.
3. **Prohibition 02-05 #2 / WR-02:** fix the dry-run `Path` refresh (one line) or explicitly accept it.
4. **Triage the 9 open findings** in 02-REVIEW-DISPOSITION.md. Restore the dropped accepted decisions from `4d8a918` if they still apply.
5. **Real Windows (VERI-02):** backstop truths 22 and 23, PowerShell 5.1 parsing, and CR-01/WR-03 against the real User scope.
6. **Confirm the 15 judgment-tier prohibition verdicts.**
7. **Push and confirm CI.** `main` is 46 commits ahead of `origin/main`.
8. **MVP-mode discrepancy:** restate the goal as a user story or drop `mode: mvp`.

### Gaps Summary

Both gaps from the first verification are closed. SC3 is closed in code: on macOS, the rerun now decides from the ledger or the block's own export line, and the test no longer supplies its own precondition. I confirmed it in real-brew dry runs from a shell with `JAVA_HOME` unset. SC1 is closed by the user-accepted override. All four roadmap criteria and requirements JAVA-01 to JAVA-04 are met as worded. The suite passes under Bash 3.2 and in ubuntu:24.04, and the WR-10 mutation is caught.

Nothing is marked as a gap. The status is `human_needed` because three reproduced review findings need a product decision before ship. None of them breaks a success criterion as written:
- **WR-03:** a macOS rerun that *deselects* Ghidra keeps or drops our `JAVA_HOME` depending on the caller's shell.
- **WR-01:** a Windows rerun overwrites an owned user `JAVA_HOME` even when the user deliberately changed it. In a narrow edge, that includes a usable JDK 22.
- **WR-02:** a Windows dry run rewrites the session `Path`. This violates a plan prohibition, but the code predates the phase.

The remaining human items are the real-Windows checks, the 9 open findings in the review record, CI, and the MVP-mode flag. Phase 3 (DOCS-01) only documents limitations, so nothing is deferred to it. It is the natural home for whichever of WR-01, WR-03 and WR-04 the user accepts.

---

_Verified: 2026-10-14T21:37:04Z_
_Verifier: Claude (gsd-verifier)_
