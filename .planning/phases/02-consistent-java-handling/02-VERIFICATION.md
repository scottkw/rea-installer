---
phase: 02-consistent-java-handling
verified: 2026-10-15T01:05:56Z
status: human_needed
score: 43/45 must-haves verified
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
  - ".planning/phases/02-consistent-java-handling/02-06-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-06-SUMMARY.md"
  - ".planning/phases/02-consistent-java-handling/02-07-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-07-SUMMARY.md"
  - ".planning/phases/02-consistent-java-handling/02-REVIEW-DISPOSITION.md"
  - ".planning/phases/02-consistent-java-handling/02-REVIEW.md"
  - ".planning/phases/02-consistent-java-handling/02-UAT.md"
  - "rea-install-linux.sh"
  - "rea-install-macos.sh"
  - "rea-install-windows.ps1"
  - "test.sh"
covered_digest: "v3:sha256:5d33fefe7cca2404f9c5a7309e00ffb3b2042d278da7be9968546d443d1e76bf"
behavior_unverified: 0
overrides_applied: 1
overrides:
  - must_have: "With JAVA_HOME pointing at JDK 21 or newer, it reuses the existing one and installs no JDK"
    reason: "On macOS, Homebrew's ghidra formula depends on openjdk@21, so installing Ghidra pulls in a JDK regardless; the script reuses the user's JAVA_HOME, writes no JAVA_HOME line, and records openjdk@21 so uninstall removes it. Holds literally with --no-ghidra or when Ghidra is already present."
    accepted_by: "Ken Scott"
    accepted_at: "2026-10-14T20:30:00Z"
re_verification:
  previous_status: human_needed
  previous_score: 36/39
  gaps_closed:
    - "G-02-1 (review WR-03): macOS --no-ghidra rerun writes our JAVA_HOME from ledger ownership whether the shell has it set or unset (2fd5825; test fails when the ownership clause is removed)"
    - "G-02-2 (review WR-01): Windows replaces an owned user JAVA_HOME only when its folder is gone; log no longer says 'by this script' (6b0fd4f; test fails when the $gone guard is removed)"
    - "G-02-3 (review WR-02): Windows -DryRun returns from Install-Winget before Add-Record/Update-SessionPath (8d0cbb5; test fails when the return is removed)"
    - "G-02-4: WR-04, IN-03, IN-04, IN-05 fixed (2fd5825, d4021ad); IN-01/IN-02 deferred with an accepted reason; the nine decisions dropped from 4d8a918 restored as WR-101..104 and IN-101..105 (open 0 at 43cc795 and 4fe9ade)"
  gaps_remaining: []
  regressions:
    - "Prohibition 02-01 #2 ('MUST NOT print the captured java -version output anywhere') now fails: the 02-06 IN-04 fix prints the first 3 lines of java -version output in the Linux die (rea-install-linux.sh:380). See human_verification item 1"
human_verification:
  - test: "Decide the conflict between prohibition 02-01 #2 and plan 02-06 truth 5 (review IN-04). rea-install-linux.sh:380 dies with the first 3 lines of `$STATE_DIR/jdk/bin/java -version 2>&1` output"
    expected: "A decided rule. Either filter the 'Picked up JAVA_TOOL_OPTIONS:' / 'Picked up _JAVA_OPTIONS:' lines before printing (for example `| grep -v '^Picked up' | head -3`) or accept that the user's own options may appear on their own stderr. Today the line prints as-is. This die path is the one an invalid JAVA_TOOL_OPTIONS is most likely to reach, and 02-01 says those options can carry proxy credentials"
    why_human: "Two plan must-haves conflict, and this is a judgment-tier prohibition. Neither IN-04 nor 02-06 weighed the credential concern 02-01 recorded"
  - test: "Triage 02-REVIEW.md WR-01 (macOS). Ledger holds brew:openjdk@21, the session JAVA_HOME is a JDK 17, then rerun `install --no-ghidra --with-extras`"
    expected: "Reproduced by this verifier: write_profile switches JAVA_HOME to the script's openjdk@21, writes it in the block and prints no warning. The JAVA-02 outcome is correct, because a JDK 17 is not trusted. But the D-04 warning install_jdk prints is missing, and the re-appended block now overrides any user `export JAVA_HOME=` line placed after the old block. Apply the review's split-clause fix with a warning, or accept"
    why_human: "Does not break SC1 to SC4 or any truth as worded. It conflicts with locked D-04 and the 'never silently altered' core value, so it needs a product decision"
  - test: "Triage 02-REVIEW.md WR-03 (macOS) and judgment prohibition 02-06 #1. Ledger holds brew:openjdk@21 but the formula no longer runs, then rerun `install --no-ghidra --with-extras` once with JAVA_HOME set to our path and once with it unset"
    expected: "Reproduced by this verifier: the shell with JAVA_HOME set writes a dead `export JAVA_HOME=` line, the unset shell writes none, and neither warns. In this edge, the caller's JAVA_HOME is the only thing that decides keep or drop, which is what prohibition 02-06 #1 forbids. Fix (require jdk_usable \"$ours\" outside jdk_chosen and warn) or accept as a known limitation"
    why_human: "An edge case: the user removed the owned openjdk@21 outside the script. Truth 02-06 #1 holds for a working JDK and is mutation-tested. Judgment-tier prohibition verdicts are not authoritative in autonomous verify"
  - test: "Triage 02-REVIEW.md WR-02 (Windows). Ledger holds env:JAVA_HOME and the saved user value points at a Temurin folder that still exists but has no bin\\java.exe (leftover after an upgrade), then rerun install"
    expected: "Per code (rea-install-windows.ps1:204-208), $gone is false because the folder exists. The dead user value is kept with 'leaving it as-is', and only the session gets Temurin. This matches 02-07 truth 1 as worded, but CR-01 returns whenever Windows Installer leaves the folder behind. Fix (test for bin\\java.exe instead of the folder) or defer to VERI-02"
    why_human: "Whether real Temurin upgrades leave such folders can only be confirmed on real Windows (VERI-02). The rule chosen in G-02-2 said 'no longer exists'"
  - test: "Record dispositions for IN-01 (jdk_owned's profile probe matches any `export JAVA_HOME=` line, not only the block) and IN-02 (no-npm dry run dies at the REA CLI step; pre-existing) in 02-REVIEW-DISPOSITION.md, which shows open: 5"
    expected: "Each of the 5 open rows is fixed or deferred with an accepted reason"
    why_human: "Triage is a human decision. The open rows come from the review run after 02-07, not from 02-07's own work"
  - test: "Real Windows (VERI-02): fresh install, rerun after a Temurin upgrade, -DryRun in-process, Windows PowerShell 5.1 parsing and java -version handling"
    expected: "Backstop truths 02-03 #9 (a rerun with an equal user JAVA_HOME adds no warning or ledger line) and #10 (the first java on the refreshed PATH is Temurin's after a fresh winget install) hold. JAVA_HOME is saved to the real User scope and removed by uninstall"
    why_human: "Project constraint: CI cannot run real Windows. The pwsh driver stands in for the User scope and Update-SessionPath"
  - test: "Push main and confirm both GitHub Actions jobs (ubuntu-latest, macos-latest) pass on the Phase 2 head"
    expected: "Both jobs green"
    why_human: "Needs a push, which the verifier does not do"
---

# Phase 2: Consistent Java Handling Verification Report

**Phase Goal:** Linux, macOS and Windows all follow one rule (reuse an existing `JAVA_HOME` only if it is JDK 21 or newer, otherwise install and record the script's own JDK) and the script's own `JAVA_HOME` survives reruns
**Verified:** 2026-10-15T01:05:56Z
**Status:** human_needed
**Re-verification:** Yes. This runs after gap-closure plans 02-06 and 02-07, which target UAT gaps G-02-1 to G-02-4. The previous report had no `gaps:` block, so every must-have was re-checked in full.

## Goal Achievement

The rule holds on all three platforms, and the script's own `JAVA_HOME` survives reruns on macOS, including the `--no-ghidra` rerun that G-02-1 covered. Every must-have was checked against the code, and the suite was run by this verifier, not taken from SUMMARY claims. In the mutation runs below, each gap-closure test failed when its fix was removed.

### Observable Truths

**Roadmap success criteria (contract)**

| # | Truth | Status | Evidence |
|---|---|---|---|
| SC1 | JDK 17 `JAVA_HOME`: own JDK 21 installed on all three platforms. JDK 21+: reused, no JDK installed | ✓ VERIFIED (macOS + fresh Ghidra: PASSED (override)) | Linux `install_jdk` (rea-install-linux.sh:330-383), macOS `install_jdk` (rea-install-macos.sh:167-182), Windows `Install-Jdk` (rea-install-windows.ps1:185-209) all gate on the same predicate. The predicate text is byte-identical in the two bash scripts. Tests: `JAVA-02 Linux/macOS/Windows ... replaces a JDK 17` and `... reuses a JDK 21`. Override carried forward for Homebrew's ghidra→openjdk@21 dependency |
| SC2 | macOS, JDK 21+ `JAVA_HOME`: no `JAVA_HOME` line in the block | ✓ VERIFIED | `write_profile` keeps ours only if `JAVA_HOME = ours` or (owned and the user JDK is not usable). Tests `JAVA-03 ... not written to the profile` and `JAVA-03 macOS rerun reuses a JDK 21 ... even when it owns openjdk@21`. Spot-check: a fresh Ghidra install with a user JDK 21 recorded `brew:openjdk@21`, then `brew:ghidra`, and the block had no `JAVA_HOME` |
| SC3 | macOS, two `--with-extras`/`--with-android` runs: one block, still exporting our `openjdk@21` | ✓ VERIFIED | `JAVA-04 macOS rerun keeps one profile block ...`, `... with JAVA_HOME unset restores ... from the ledger`, `... --no-ghidra rerun writes its own JAVA_HOME whether or not the shell has it set`, `... owned only through the old block`. Mutation: replacing the ownership clause with the old env-only check fails 2 tests |
| SC4 | Windows: after Temurin, session `JAVA_HOME` = Temurin folder derived from `java` on PATH, saved as a user variable that uninstall removes, MSI or not | ✓ VERIFIED (as worded: code review + pwsh parse + driver; real Windows deferred to VERI-02) | `Install-Jdk` derives `$dir` from `Get-Command java`, checks it with `Test-JdkUsable`, sets `$env:JAVA_HOME`, then `Set-UserEnv` → `Add-Record "env:JAVA_HOME"`. Uninstall's `'env'` arm clears the User variable (rea-install-windows.ps1:317-321). No Machine-scope read. Test `JAVA-01 Windows Install-Jdk sets JAVA_HOME from the java on PATH and records it` |

**Plan must-haves** (truths that restate an SC are merged above; superseded truths are listed after this table and not counted)

| Plan | Truth (short) | Status | Evidence |
|---|---|---|---|
| 02-01 #1-2 | Linux JDK 17 → warn, own JDK, one profile line; JDK 21 → "Using JDK", no download | ✓ VERIFIED | Linux JAVA-02 tests |
| 02-01 #3 | `jdk_usable` semantics; identical text in both bash scripts; Bash 3.2 | ✓ VERIFIED | `diff` of the two function bodies is empty; the suite runs under /bin/bash 3.2.57 |
| 02-01 #4 | Inclusive boundary 21; "1.8" → 8; 25-ea usable | ✓ VERIFIED | `jdk_usable` table, 10 rows × 2 scripts |
| 02-01 #5 | Second `install_jdk` call in one run is silent | ✓ VERIFIED | Equality guard at rea-install-linux.sh:332; DRY-01 counts "Would download Temurin 21" = 1 |
| 02-01 #6 | Empty/missing/exit≠0/garbage → fail closed; no warning when unset | ✓ VERIFIED | Table rows plus `... with no JAVA_HOME installs its own without a warning` |
| 02-01 #7 | A "Picked up" line before the version line is handled | ✓ VERIFIED | `picked-up` row passes in bash and pwsh |
| 02-01 #8 | Fresh ubuntu:24.04 `--dry-run --with-android` plans one JDK, no warning | ✓ VERIFIED | `DRY-01` passed (docker, `--network none`) |
| 02-02 #3 | macOS JDK 17 → one warning on two calls, `brew_install openjdk@21`, our path | ✓ VERIFIED | `JAVA-02 macOS install_jdk replaces a JDK 17 ...` (asserts exactly 1 warning) |
| 02-02 #4 | Ghidra step and Android step both go through `install_jdk` | ✓ VERIFIED | rea-install-macos.sh:205-211, 286; the old `[ -n "$JAVA_HOME" ] \|\| install_jdk` is gone |
| 02-02 #5 | A reused user JDK still records `brew:openjdk@21` before ghidra; uninstall removes ghidra first | ✓ VERIFIED | install_ghidra:213-216 and `tail -r` uninstall. Verifier spot-check: ledger order `brew:openjdk@21`, `brew:ghidra` (no pre-existing test) |
| 02-02 #7 | bash -n, shellcheck, header lines 2-11 and source guard unchanged | ✓ VERIFIED | TEST-01 and GUARD pass; header unchanged since 2527b78 |
| 02-03 #2 | Session gets Temurin even when `Set-UserEnv` keeps a different user value | ✓ VERIFIED | `$env:JAVA_HOME = $dir` before `Set-UserEnv`; `... leaves a user JAVA_HOME it did not set` asserts session = Temurin |
| 02-03 #3 | Windows JDK 21+ reused with no winget call or ledger line; JDK 17 → D-04 warning and Temurin | ✓ VERIFIED | `JAVA-02 Windows Install-Jdk reuses a JDK 21 JAVA_HOME` plus the Install-Jdk warning line |
| 02-03 #4 | `Test-JdkUsable` matches the bash table; caller's EAP stays Stop | ✓ VERIFIED | 10 rows plus `keeps ErrorActionPreference` |
| 02-03 #5 | A non-21 java on PATH → throw naming the folder; no Machine fallback | ✓ VERIFIED | Test `throws when the java on PATH is not JDK 21+` |
| 02-03 #6 | No java on PATH → `Temurin installed but java is not on PATH.` | ✓ VERIFIED | Test `throws when no java is on PATH` |
| 02-03 #8 | Parses; only PS 5.1 constructs; `Set-UserEnv` contract kept | ✓ VERIFIED | `pwsh parse` passes; grep finds no `??`, `?.`, `&&`/`\|\|` chains, or `-Parallel`. `Set-UserEnv` still keeps a different value unless `-Replace` is passed |
| 02-03 #9 | (backstop) A rerun with an equal user value adds no warning or ledger line | ? insufficient_spec | `verification: backstop`; code returns early on `$existing -eq $Value`, but presence does not qualify. Human item 6 (VERI-02) |
| 02-03 #10 | (backstop) Real Windows: the first java after a fresh winget install is Temurin's | ? insufficient_spec | Only real Windows can show this. Human item 6 (VERI-02) |
| 02-04 #1-3 | macOS rerun (unset `JAVA_HOME`) restores ours from the old block or the ledger; a usable user JDK still wins | ✓ VERIFIED | Three macOS tests named above |
| 02-04 #4 | The JAVA-04 test unsets `JAVA_HOME` and uses the production `install_ghidra` | ✓ VERIFIED | test.sh:381 |
| 02-04 #5 | `brew --prefix` failure stops a real run; a dry run without brew warns and plans the default prefix | ✓ VERIFIED | `... stops when brew cannot locate openjdk@21` (also checks for no `/libexec` path); `... dry run without brew plans the default ...` |
| 02-04 #6 | Linux broken `~/.rea-installer/jdk` → warn, `run rm -rf`, re-download; the dry run only prints | ✓ VERIFIED | `... plans to replace` and `... replaces a broken ... on rerun` |
| 02-05 #2 | No `env:JAVA_HOME` in the ledger → user value left with a warning, only the session set | ✓ VERIFIED | `... leaves a user JAVA_HOME it did not set` |
| 02-05 #3 | `-DryRun` leaves session `JAVA_HOME` alone; second call silent; nothing recorded; `Set-UserEnv -DryRun` sets no session var | ✓ VERIFIED | Three dry-run driver tests |
| 02-05 #4 | The JAVA-01 record test starts from an empty ledger and asserts the winget line | ✓ VERIFIED | test.sh:627 removes `$StateFile` first |
| 02-06 #1 | macOS `--no-ghidra --with-extras` rerun writes exactly one export of ours, `JAVA_HOME` set or unset (G-02-1) | ✓ VERIFIED | Loop test over both modes. Mutation-proven |
| 02-06 #2 | Keep ours only when owned and no usable user JDK 21+ | ✓ VERIFIED | rea-install-macos.sh:224-233; JAVA-03 tests. See WR-01 note (missing warning) |
| 02-06 #3 | Ghidra present, nothing owned, `brew --prefix` failing: completes for unset, 17 and 21 | ✓ VERIFIED | IN-03 loop test runs with `brew` stubbed to `exit 1` |
| 02-06 #4 | Linux nested Temurin layout used; no `bin/java` → stop without "rerun recovers" | ✓ VERIFIED | `... one level deeper` and `... stops on a Temurin archive without bin/java`; message says "report this" |
| 02-06 #5 | Linux error shows the first lines of `java -version` | ✓ VERIFIED | `... shows java -version output`. **Conflicts with prohibition 02-01 #2** (human item 1) |
| 02-06 #6 | Empty Adoptium release stops and keeps `tools/` | ✓ VERIFIED | `... stops on an empty Temurin release and keeps the tools folder` |
| 02-07 #1 | Windows: owned user value replaced only when its folder is gone; an existing folder is kept with a warning (G-02-2) | ✓ VERIFIED | `... replaces a stale ...` and `... keeps an existing user JAVA_HOME even when it set one earlier`. Mutation-proven. See WR-02 (leftover folder) |
| 02-07 #2 | The replace log says "no longer exists" and never "by this script" | ✓ VERIFIED | rea-install-windows.ps1:131; the test asserts both strings |
| 02-07 #3 | `-DryRun` returns before `Add-Record`/`Update-SessionPath` (G-02-3) | ✓ VERIFIED | rea-install-windows.ps1:111 |
| 02-07 #4 | Driver stub records the call; the check fails if a dry run calls it | ✓ VERIFIED | Mutation: removing line 111 gives `FAIL: ... -DryRun leaves the session PATH alone` |
| 02-07 #5 | Disposition record has no open row, with the listed fixes, deferrals and restorations (G-02-4) | ✓ VERIFIED (at completion) | `open: 0, total: 26` at 43cc795 and 4fe9ade. The later re-review (5e1e32f) added 5 new open rows (WR-01..03, IN-01..02). The prior decisions were renumbered WR-201..203 and IN-201..202, and all 26 earlier decisions survive. The new open rows are new triage (human item 5), not a regression of this truth |
| 02-07 #6 | Phase gate exits 000 with no FAIL; pwsh parse passes | ✓ VERIFIED | Verifier ran: default bash (= /bin/bash 3.2.57 on this Mac) 91 passed, 0 failed, 2 skipped; ubuntu:24.04 59 passed, 0 failed, 11 skipped |

**Superseded truths (not counted; their replacement truths are verified above):** 02-01 #9 (the die text changed; see 02-04 #6 and 02-06 #5), 02-02 #6 (by 02-06 #2), 02-03 #7 placeholder (by 02-05 #3), 02-04 #7 (by 02-06 #4), 02-04 #8, 02-05 #6 (gate; see 02-07 #6), 02-05 #1 (by 02-07 #1), 02-05 #5 (by 02-07 #5).

**Score:** 43/45 truths verified (1 via override), 2 `insufficient_spec` backstop truths routed to human verification, 0 present-but-behavior-unverified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `rea-install-linux.sh` | `jdk_usable`, `install_jdk` reuse/replace, broken-JDK recovery, nested layout, `report this` | ✓ VERIFIED | verify.artifacts passes for 02-01, 02-04 and 02-06; called from steps 3 and 4 |
| `rea-install-macos.sh` | `jdk_usable`, `jdk_home`, `jdk_owned`, `install_jdk`, `install_ghidra`, `write_profile`, `jdk_chosen` | ✓ VERIFIED | All present and called from `do_install` |
| `rea-install-windows.ps1` | `Test-JdkUsable`, `Get-UserEnv`, `Set-UserEnv -Replace`, `Install-Jdk`, dry-run return in `Install-Winget`, `no longer exists` | ✓ VERIFIED | Called from `Invoke-Install` (Ghidra and Android steps) |
| `test.sh` | Every named check in plan artifacts | ✓ VERIFIED | All `contains:` strings present; all pass |
| `02-REVIEW-DISPOSITION.md` | `open: 0` | ⚠️ (tool reports `Missing pattern: open: 0`) | Held when 02-05 and 02-07 completed; the later re-review added 5 open rows. Human item 5 |

### Key Link Verification

The `verify.key-links` tool could not resolve these links: their `from:` values are function names, not file paths. Each link was checked by hand with its pattern.

| From | To | Via | Status |
|---|---|---|---|
| Linux `install_jdk` | `jdk_usable "${JAVA_HOME:-}"` / `setting JAVA_HOME` | reuse decision; persist only `$STATE_DIR/jdk` | WIRED |
| Linux `do_install` reset | `install_jdk` equality guard | unset inherited `$STATE_DIR/*` values (line 409-412) | WIRED |
| Linux `install_jdk` | `$STATE_DIR/jdk` | `run mv "$dir"` or `run mv "${inner%/}"` | WIRED |
| macOS `write_profile` | `jdk_owned`, `jdk_home` | `jdk_owned && owned=true`; `ours="$(jdk_home)"` as a plain statement | WIRED |
| macOS `jdk_owned` | `jdk_home` | ledger `brew:$JDK_FORMULA` first, then the profile grep, then `jdk_home \|\| exit 1` | WIRED |
| macOS `install_ghidra` | `install_jdk`, `brew_install "$JDK_FORMULA"` | owned → `install_jdk`; fresh → JDK recorded before ghidra | WIRED |
| `Install-Jdk` | `Test-JdkUsable`, `Update-SessionPath`, `Set-UserEnv 'JAVA_HOME' -Replace:$replace` | reuse, refresh, derive, save | WIRED |
| `Set-UserEnv` | `Get-UserEnv $Name` | one reader for the user scope | WIRED |
| `Install-Winget` | `Update-SessionPath` | `if ($DryRun) { return }` before `Add-Record` | WIRED |
| test.sh driver stub | `$PathRefreshed` | flag asserted false after the dry run | WIRED |

### Data-Flow Trace (Level 4)

Not applicable: these are installer scripts with no rendered data. The ledger-to-profile flow (`brew:openjdk@21` → `jdk_owned` → `write_profile` → block) was traced above and exercised by tests and the verifier's spot-checks.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full suite, macOS (bash 3.2.57) | `./test.sh` | 91 passed, 0 failed, 2 skipped (Linux-only) | ✓ PASS |
| Full suite, ubuntu:24.04 | `docker run ... ubuntu:24.04 bash ./test.sh` | 59 passed, 0 failed, 11 skipped (no pwsh, shellcheck or docker inside) | ✓ PASS |
| G-02-3 test can fail | remove `if ($DryRun) { return }` in `Install-Winget`, run a copy | `FAIL: JAVA-01 Windows Install-Jdk -DryRun leaves the session PATH alone` | ✓ PASS |
| G-02-1 and G-02-2 tests can fail | revert the macOS clause to env-only and set Windows `$replace = $true -and ...` | 3 FAILs: both `--no-ghidra` tests and `keeps an existing user JAVA_HOME ...` | ✓ PASS |
| macOS fresh Ghidra with user JDK 21 | sourced `install_ghidra; write_profile` with stub brew | Ledger `brew:openjdk@21`, `brew:ghidra`; no `JAVA_HOME` in the block; session still the user JDK | ✓ PASS |
| Review WR-01 reproduction | owned ledger, `JAVA_HOME`=JDK 17, `write_profile` only | Block exports ours, session switched, no warning printed | reproduced (warning) |
| Review WR-03 reproduction | owned ledger, our JDK exits 1, set vs unset | 1 vs 0 `JAVA_HOME` lines, no warning either way | reproduced (warning) |
| Summary commits exist | `verify.commits 1c2bc0a 24c6937 2fd5825 43cc795 4d8a918 6b0fd4f 8d0cbb5 d4021ad` | all_valid: true | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` exist, and no plan declares one. Step 7c does not apply.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| JAVA-01 | 02-03, 02-05, 02-07 | Windows: after Temurin, session and user `JAVA_HOME` point at Temurin 21; uninstall removes it; MSI-independent | ✓ SATISFIED (real Windows: VERI-02) | SC4 row; driver tests |
| JAVA-02 | 02-01, 02-02, 02-03, 02-04, 02-06 | Every platform reuses `JAVA_HOME` only if JDK 21+, else installs its own | ✓ SATISFIED | SC1 row; predicate tables for all three scripts |
| JAVA-03 | 02-02, 02-04, 02-06 | macOS never writes a user's JDK 21+ `JAVA_HOME` into the profile | ✓ SATISFIED | SC2 row; JAVA-03 tests including the owned-ledger case |
| JAVA-04 | 02-02, 02-04, 02-06 | macOS rerun keeps our `JAVA_HOME` in the single block | ✓ SATISFIED | SC3 row; four JAVA-04 tests |

REQUIREMENTS.md maps JAVA-01 to JAVA-04, and only those, to Phase 2. Every one is claimed by a plan. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| (all four source files) | - | TBD/FIXME/XXX/TODO/HACK | none found | - |
| rea-install-linux.sh | 380 | Prints raw `java -version` output (can include `Picked up JAVA_TOOL_OPTIONS: ...`) | ⚠️ Warning | Violates judgment prohibition 02-01 #2 (human item 1) |
| rea-install-macos.sh | 228 | Owned-JDK clause replaces a JDK 17 `JAVA_HOME` without the D-04 warning (review WR-01) | ⚠️ Warning | Silent profile change on `--no-ghidra` reruns (human item 2) |
| rea-install-macos.sh | 228 | `JAVA_HOME = ours` accepted without `jdk_usable` outside `jdk_chosen` (review WR-03) | ⚠️ Warning | Environment-dependent result when the owned JDK is broken (human item 3) |
| rea-install-windows.ps1 | 205 | "Gone" means the folder is missing, not "no java.exe" (review WR-02) | ⚠️ Warning | A leftover Temurin folder keeps a dead user `JAVA_HOME` (human item 4) |
| rea-install-macos.sh | 162-164 | Profile probe not limited to the block (review IN-01) | ℹ️ Info | Needs `brew --prefix` for users with their own `export JAVA_HOME=` line |

None of these breaks a roadmap success criterion or a plan truth as worded, so none is a BLOCKER. Each needs a decision before ship.

### Prohibitions (judgment tier, autonomous verify): unverified, human review recommended

These verdicts come from an LLM judge and are not authoritative. None was silently passed.

| Plan | Prohibition | Judge verdict |
|---|---|---|
| 02-01 #1, #3 | Never touch a user JDK or persist a user `JAVA_HOME` (Linux) | Holds: the only `rm -rf` targets are `$STATE_DIR/jdk` and the fresh extract; `setting JAVA_HOME` is always `$STATE_DIR/jdk` |
| 02-01 #2 | Never print captured `java -version` output | **VIOLATED (flagged):** rea-install-linux.sh:380, added by 02-06 (IN-04) |
| 02-02 #1-3 | No user `JAVA_HOME` in block; Ghidra's openjdk@21 recorded; no version output | Hold (spot-check above). The block reordering in WR-01 overrides a user line placed after the block, but writes no user value |
| 02-03 #1-3 | `Set-UserEnv` contract; only the Temurin folder saved; no version output | Hold |
| 02-04 #1-3 | No user value or override of a usable JDK; Linux removes only its own folders; the dry run changes nothing | Hold |
| 02-05 #1 | Overwrite the user value only when the ledger holds `env:JAVA_HOME` | Holds, and is now narrower (folder must also be gone) |
| 02-05 #2, 02-07 #2 | `-DryRun` changes no session or persistent variable, `$env:Path` included | Holds now (was VIOLATED last time). Test-tier, mutation-proven |
| 02-05 #3, 02-07 #3 | Disposition values and ids the gate preserves | Hold: values are only `open`/`fixed`/`deferred`; ids match `(CR\|WR\|IN)-\d+` |
| 02-06 #1 | Caller's `JAVA_HOME` must not be the only reason to keep or drop ours | **VIOLATED in one edge (flagged):** when the owned JDK does not run (review WR-03, reproduced). Holds for a working JDK (mutation-proven) |
| 02-06 #2 | No usable user `JAVA_HOME` in macOS block (automated) | Holds: JAVA-03 tests |
| 02-06 #3 | No Linux JDK folder outside `~/.rea-installer` touched | Holds |
| 02-07 #1 | Never overwrite a user value pointing at an existing folder (automated) | Holds: test is mutation-proven |

### Human Verification Required

1. **Prohibition 02-01 #2 versus truth 02-06 #5.** Filter `Picked up ...` lines out of the Linux die message, or accept that they print.
2. **Review WR-01 (macOS).** A `--no-ghidra` rerun silently replaces a JDK 17 `JAVA_HOME`, with no D-04 warning, and the re-appended block now overrides a user line placed after it. Fix or accept.
3. **Review WR-03 (macOS) / prohibition 02-06 #1 edge.** When the owned openjdk@21 is broken, the result depends on the caller's shell. Fix or accept.
4. **Review WR-02 (Windows).** A leftover Temurin folder with no `java.exe` keeps a dead user `JAVA_HOME`. Fix (check for `bin\java.exe`) or defer to VERI-02.
5. **Record dispositions** for the 5 open rows in 02-REVIEW-DISPOSITION.md, IN-01 and IN-02 included.
6. **Real Windows (VERI-02).** Backstop truths 02-03 #9 and #10, PowerShell 5.1, and the real User scope.
7. **Push and confirm CI** on ubuntu-latest and macos-latest.

### Gaps Summary

All four UAT gaps are closed in code and backed by tests that fail when the fix is reverted:
- **G-02-1:** the macOS `--no-ghidra` rerun now decides by ownership.
- **G-02-2:** Windows replaces only a gone folder, and the log is honest.
- **G-02-3:** a Windows dry run leaves `Path` alone.
- **G-02-4:** the triage is recorded, and the dropped decisions are restored.

All four roadmap success criteria and JAVA-01 to JAVA-04 are met as worded. The suite passes under Bash 3.2 and in ubuntu:24.04.

There are no blocking gaps. The status is `human_needed` for three reasons:
- **New regression.** The 02-06 IN-04 fix prints raw `java -version` output. That contradicts prohibition 02-01 #2, which exists because `JAVA_TOOL_OPTIONS` can carry proxy credentials. Nobody reconciled the two. One `grep -v '^Picked up'` would satisfy both.
- **Three post-gap review warnings, all reproduced.** WR-01 and WR-03 are edges of the new macOS ownership clause: a missing D-04 warning, and a broken owned JDK. WR-02 is an edge of the Windows "gone folder" rule. None defeats the phase goal in its normal paths, but each leaves the machine changed or stale without a message in a narrow case. That touches the project's core value, so each needs a fix-or-accept decision.
- **Checks only a person can do.** Two backstop truths need real Windows (VERI-02), and CI needs a push.

Phase 3 (DOCS-01) only documents limitations, so no gap is deferred to it. It is the natural home for whichever warnings the user accepts.

---

_Verified: 2026-10-15T01:05:56Z_
_Verifier: Claude (gsd-verifier)_
