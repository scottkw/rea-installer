---
phase: 02-consistent-java-handling
verified: 2026-10-14T19:58:12Z
status: gaps_found
score: 23/27 must-haves verified
covered_files:
  - ".planning/phases/02-consistent-java-handling/02-01-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-01-SUMMARY.md"
  - ".planning/phases/02-consistent-java-handling/02-02-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-02-SUMMARY.md"
  - ".planning/phases/02-consistent-java-handling/02-03-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-03-SUMMARY.md"
  - "rea-install-linux.sh"
  - "rea-install-macos.sh"
  - "rea-install-windows.ps1"
  - "test.sh"
covered_digest: "v3:sha256:acc1b3a30249895b2b21c2c2796bddf50083adf5a8e0d8bc1cd4b1e65299a663"
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "ROADMAP SC3 / 02-02 truth 1 (JAVA-04): on macOS, two `install --with-extras` (or `--with-android`) runs in a row leave exactly one profile block that still exports JAVA_HOME pointing at the script's openjdk@21"
    status: partial
    reason: "write_profile re-adds JAVA_HOME only when the caller's environment already holds the openjdk@21 path (D-07). A rerun from a shell that never sourced the block, such as the same terminal as run 1 or a rerun right after a failed run, with Ghidra already on PATH and no --with-android, never calls install_jdk. The block is then rewritten without JAVA_HOME and `rea setup` runs with no JDK, even though the script installed and recorded brew:openjdk@21. I reproduced this with a real-brew dry run (temp HOME, ghidraRun on PATH, JAVA_HOME unset): the planned block holds only the two extras exports. The JAVA-04 test passes only because its second sandbox sets JAVA_HOME=$(jdk_home) itself (the test supplies the precondition; production code does not guarantee it). Linux does not have this problem: its rerun reset plus install_jdk restores $STATE_DIR/jdk whatever the caller exported (confirmed in ubuntu:24.04). The two platforms therefore do not follow the same rule here."
    artifacts:
      - path: "rea-install-macos.sh"
        issue: "write_profile (lines 171-175) and step 4's 'Ghidra already available' branch (lines 222-224) decide from the caller's JAVA_HOME, not from what the script installed"
      - path: "test.sh"
        issue: "JAVA-04 check (lines 299-317) presets JAVA_HOME before the second write, so it cannot catch this case"
    missing:
      - "On a macOS rerun, restore the script's own JAVA_HOME when the script owns openjdk@21 (for example brew:openjdk@21 is in the ledger, or the old block exported it) and JAVA_HOME is unset, or run install_jdk whenever Ghidra or Android support is present, not only when it is being installed"
      - "A test.sh check where the second write runs with JAVA_HOME unset (Ghidra present, Android off) and the block still exports the openjdk@21 path"
  - truth: "ROADMAP SC1 (JAVA-02): with JAVA_HOME pointing at JDK 21 or newer, install reuses the existing one and installs no JDK, on Linux, macOS and Windows"
    status: partial
    reason: "Linux and Windows meet the criterion, and so does macOS with --no-ghidra or with Ghidra already present. On a default macOS install (Ghidra on), the script reuses the user's JDK (it logs 'Using JDK at ...' and writes no JAVA_HOME line) but also runs `brew install openjdk@21` before `brew install ghidra` and records brew:openjdk@21. I confirmed this in a real-brew dry run and in a non-dry stub-brew run, where the ledger read brew:openjdk@21, brew:ghidra. The cause is Homebrew: `brew info --json=v2 ghidra` lists dependencies ['openjdk@21'], so Homebrew installs a JDK either way. Plan 02-02 resolved this as auto-mode assumption A3, which no human has approved. The criterion is not met as written. The intent (respect the user's JDK) is met."
    artifacts:
      - path: "rea-install-macos.sh"
        issue: "Step 4 (lines 225-231) brew_installs openjdk@21 when a user JDK 21+ is reused, because Homebrew's ghidra formula depends on it"
    missing:
      - "EITHER accept the deviation with the override suggested in the report body (recommended: Homebrew installs openjdk@21 as ghidra's dependency anyway, and recording it lets uninstall remove it) OR install Ghidra on macOS from the pinned release zip, as Linux and Windows do, so that no JDK is pulled in"
---

# Phase 2: Consistent Java Handling Verification Report

**Phase Goal:** Linux, macOS and Windows all follow one rule (reuse an existing `JAVA_HOME` only if it is JDK 21 or newer, otherwise install and record the script's own JDK) and the script's own `JAVA_HOME` survives reruns
**Verified:** 2026-10-14T19:58:12Z (code at HEAD `18a174a`; phase code commits `3d2db49`..`42faa6f`, local only, not pushed, so GitHub Actions has not run on Phase 2 code)
**Status:** gaps_found
**Re-verification:** No, initial verification

## MVP Mode Discrepancy

ROADMAP sets `**Mode:** mvp` for Phase 2, but the goal is not a user story (`user-story.validate` returned `valid: false`). The plans say so too and do not invent a story. As in Phase 1, this report verifies goal-backward against the four roadmap success criteria and every plan truth, and has no User Flow Coverage table. To clear the discrepancy, either run `/gsd-mvp-phase 2` or drop `mode: mvp`.

## Goal Achievement

### Roadmap Success Criteria (contract)

| # | Success criterion | Status | Evidence |
|---|---|---|---|
| SC1 | JDK 17 `JAVA_HOME` gets the script's own JDK 21; JDK 21+ is reused and no JDK is installed (Linux, macOS, Windows) | ✗ FAILED (partial) | **Linux:** test PASS (replace, reuse, unset). Container dry run in ubuntu:24.04: JDK 17 stub gives the warning, `Would download Temurin 21` and `export JAVA_HOME="/root/.rea-installer/jdk"`; JDK 21 stub gives `Using JDK at /jdks/jdk21` twice and no download. **Windows:** pwsh driver PASS (reuse, JDK 17 to Temurin). **macOS:** the JDK 17 case passes (test and real-brew dry run: one warning, then `export JAVA_HOME="/opt/homebrew/opt/openjdk@21/..."`). With JDK 21+ and Ghidra on (the default), the dry run plans `brew install openjdk@21` then `brew install ghidra`. Homebrew ghidra depends on openjdk@21. See the gap and the override suggestion. |
| SC2 | macOS with a JDK 21+ `JAVA_HOME` writes no `JAVA_HOME` line to the profile block | ✓ VERIFIED | `write_profile` adds `JAVA_HOME` only when it equals `$(jdk_home)` (lines 173-175). The `JAVA-03 macOS reused JDK 21 JAVA_HOME is not written to the profile` check passes; a planted `REA_TEST=1` export proves a block was actually written. The real-brew dry run with a JDK 21 stub planned no `JAVA_HOME` line. |
| SC3 | macOS: two `--with-extras`/`--with-android` runs in a row leave one block still exporting our openjdk@21 `JAVA_HOME` | ✗ FAILED (partial) | Holds when the rerun shell inherited `JAVA_HOME` from the block (new terminal) or with `--with-android` (step 5 always calls `install_jdk`). The real-brew dry run with JAVA_HOME = ours shows one block with the `JAVA_HOME` export. It fails for a rerun from a shell that never sourced the block, with Ghidra present and Android off: the reproduced dry run plans a block with no `JAVA_HOME`. See the gap. |
| SC4 | Windows: after Temurin is installed, session `JAVA_HOME` = Temurin 21 folder derived from `java` on PATH, saved as a user variable that uninstall removes, whether or not the MSI set it (code review + pwsh parse; real Windows deferred to VERI-02) | ✓ VERIFIED (first install; see CR-01 warning) | `Install-Jdk` (lines 175-193): `Update-SessionPath`, then `Get-Command java ... \| Select-Object -First 1`, `Test-JdkUsable`, `$env:JAVA_HOME = $dir`, `Set-UserEnv 'JAVA_HOME' $dir` (records `env:JAVA_HOME`). There are no `GetEnvironmentVariable('JAVA_HOME'` reads, so the result does not depend on the MSI. The uninstall `env` arm (lines 301-305) deletes recorded user variables. `TEST-01 pwsh parse` passes, as do the 16 driver cases. Real Windows and PowerShell 5.1 are deferred by the criterion itself. CR-01 (a stale saved value after a Temurin upgrade) is outside this criterion's scenario; it is listed under warnings. |

### Plan Truths

| # | Truth (plan) | Status | Evidence |
|---|---|---|---|
| 1 | 02-01: Linux JDK 17 `JAVA_HOME`: D-04 warning, `JAVA_HOME=$STATE_DIR/jdk`, exactly one profile line | ✓ VERIFIED | `PASS: JAVA-02 Linux install_jdk replaces a JDK 17 JAVA_HOME with its own` (two calls, one warning, one line); container dry run confirms end to end |
| 2 | 02-01: Linux JDK 21+ reused, no download, no profile line | ✓ VERIFIED | `PASS: JAVA-02 Linux install_jdk reuses a JDK 21 JAVA_HOME`; container dry run |
| 3 | 02-01: `jdk_usable` semantics; byte-identical in both bash scripts; Bash 3.2 | ✓ VERIFIED | `diff` of the two function bodies prints nothing; 20 table rows PASS under `/bin/bash` 3.2 (my run) and Bash 5 (orchestrator's ubuntu run) |
| 4 | 02-01: boundary inclusive at 21; `1.8` reads as 8; `25-ea` usable | ✓ VERIFIED | Table rows 8/17/21/21.0.5/25-ea PASS for both scripts |
| 5 | 02-01: second `install_jdk` in the same run is silent | ✓ VERIFIED | Truth 1's check calls it twice and counts 1 warning, 1 download, 1 line |
| 6 | 02-01: unset/empty `JAVA_HOME`: own JDK, no warning; predicate fails closed | ✓ VERIFIED | `PASS: ... with no JAVA_HOME installs its own without a warning`; table rows garbage/exit1/missing/empty all return 1 |
| 7 | 02-01: `Picked up JAVA_TOOL_OPTIONS:` first line does not change the result | ✓ VERIFIED | `picked-up` row PASS (both scripts and pwsh) |
| 8 | 02-01: fresh ubuntu `--dry-run --with-android` plans Temurin once, no false warning | ✓ VERIFIED | `PASS: DRY-01 Linux install --dry-run --with-android in fresh ubuntu:24.04` (asserts count = 1 and no warning) |
| 9 | 02-01: non-dry Linux: a JDK that does not run stops with the die message | ✓ VERIFIED | No test.sh check. I ran it directly: sandbox with `dry_run=false` and a `$STATE_DIR/jdk/bin/java` that exits 1 printed `error: the downloaded JDK at .../.rea-installer/jdk does not run.` and did not reach the next statement |
| 10 | 02-02: macOS JDK 17: one warning over two calls, `brew_install openjdk@21`, `JAVA_HOME` = ours | ✓ VERIFIED | `PASS: JAVA-02 macOS install_jdk replaces a JDK 17 JAVA_HOME with openjdk@21`; real-brew dry run |
| 11 | 02-02: steps 4 and 5 both go through `install_jdk`; step 5 no longer trusts any non-empty `JAVA_HOME` | ✓ VERIFIED | Lines 226 and 237; the old `[ -n "${JAVA_HOME:-}" ] \|\| install_jdk` line is gone |
| 12 | 02-02: user JDK 21+ reused while Ghidra is installed: `brew:openjdk@21` recorded, uninstall removes ghidra first | ✓ VERIFIED | Non-dry `do_install` run with a stub brew (list exits 1, install exits 0), a stub npm and `JAVA_HOME` at a JDK 21 stub gave the ledger `brew:openjdk@21`, `brew:ghidra`, `npm:...`. Uninstall reads the ledger newest first (`tail -r`), so ghidra is removed before openjdk@21 |
| 13 | 02-02: `install_jdk` no longer appends to `profile_exports`; `write_profile` adds `JAVA_HOME` once, only when it equals `jdk_home` | ✓ VERIFIED | The only `profile_exports+=("export JAVA_HOME=` is at line 174, inside `write_profile`; a single `write_profile` call in `do_install` (line 253) |
| 14 | 02-02: macOS passes `bash -n`/shellcheck under 3.2; header and source guard unchanged | ✓ VERIFIED | TEST-01 passes; the first diff hunk of the phase is at line 91 (macOS) and line 284 (Linux) |
| 15 | 02-03: session `JAVA_HOME` set even when `Set-UserEnv` leaves a different user value | ✓ VERIFIED | Ordering at lines 191-192. Behavioural check in pwsh: with `Set-UserEnv` replaced by its keep-existing branch (warn and return) and `JAVA_HOME=/old/jdk-21.0.4`, the session ended at the fake Temurin folder |
| 16 | 02-03: Windows JDK 21+ reused with no winget call or ledger; JDK 17 warned and replaced | ✓ VERIFIED | `PASS: JAVA-02 Windows Install-Jdk reuses a JDK 21 JAVA_HOME` (no state file); the JAVA-01 case starts from JDK 17 and ends at Temurin |
| 17 | 02-03: `Test-JdkUsable` matches the bash table; `$ErrorActionPreference` stays `Stop` | ✓ VERIFIED (pwsh 7 only) | 11 `PASS: JAVA-02 Windows Test-JdkUsable ...` lines. PowerShell 5.1 stderr wrapping (A1) is not exercised anywhere; that is deferred to VERI-02 |
| 18 | 02-03: `java` on PATH not 21+ makes it throw, naming the folder, with no Machine fallback | ✓ VERIFIED | `PASS: JAVA-01 Windows Install-Jdk throws when the java on PATH is not JDK 21+` |
| 19 | 02-03: no `java` on PATH makes it throw `Temurin installed but java is not on PATH.` | ✓ VERIFIED | `PASS: JAVA-01 Windows Install-Jdk throws when no java is on PATH` |
| 20 | 02-03: `-DryRun` sets the placeholder, records nothing, and the second call is silent | ✓ VERIFIED | `PASS: JAVA-01 Windows Install-Jdk -DryRun sets the placeholder and records nothing` (asserts the second call's output is empty) |
| 21 | 02-03: parses; PowerShell 5.1 constructs only; `Set-UserEnv` unchanged | ✓ VERIFIED | `TEST-01 pwsh parse` PASS; the phase diff touches only `Test-JdkUsable` and `Install-Jdk`; the constructs used (`Join-Path`, `-LiteralPath`, `ForEach-Object`, `-join`, `Select-Object -First`) all exist in 5.1 |
| 22 | 02-03 (backstop): rerun with an equal user value: `Set-UserEnv` silent, session still set | ⚠️ insufficient_spec | User-scope variables are a no-op on Unix pwsh; this can only be checked on real Windows (VERI-02). Code reading agrees (`if ($existing -eq $Value) { return }`) |
| 23 | 02-03 (backstop): on real Windows, the first `java` on the refreshed PATH is Temurin's | ⚠️ insufficient_spec | Assumption A2. It cannot be exercised off Windows. WR-01 below describes realistic cases where it is false (Oracle `javapath` shim, an older JDK first on PATH) |

Roadmap SC2, SC3 and SC4 absorb plan truths 02-02 #1, 02-02 #2 and 02-03 #1 (same claims, roadmap wording kept).

**Score:** 23/27 truths verified (2 failed, both partial; 2 backstop truths need real Windows; 0 present-but-behavior-unverified)

### Override Suggestion (SC1, macOS + Ghidra)

**This looks intentional.** Homebrew's `ghidra` formula depends on `openjdk@21` (`brew info --json=v2 ghidra` lists dependencies `['openjdk@21']`), so on macOS with Homebrew Ghidra a JDK is installed whatever the script does. Recording it lets uninstall remove it. To accept, add to this file's frontmatter:

```yaml
overrides:
  - must_have: "With JAVA_HOME pointing at JDK 21 or newer, it reuses the existing one and installs no JDK"
    reason: "On macOS, Homebrew's ghidra formula depends on openjdk@21, so installing Ghidra pulls in a JDK regardless; the script reuses the user's JAVA_HOME, writes no JAVA_HOME line, and records openjdk@21 so uninstall removes it. Holds literally with --no-ghidra or when Ghidra is already present."
    accepted_by: "{name}"
    accepted_at: "{ISO timestamp}"
```

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `rea-install-linux.sh` | `jdk_usable`; `install_jdk` reuses only 21+, installs Temurin once, self-check | ✓ VERIFIED | `verify.artifacts` 3/3 for 02-01; functions at lines 285 and 330 |
| `rea-install-macos.sh` | `jdk_usable` (identical), `jdk_home`, reworked `install_jdk`, `write_profile`, step-4 openjdk@21 | ✓ VERIFIED | Lines 92, 135, 137, 171, 225-231 |
| `rea-install-windows.ps1` | `Test-JdkUsable`; `Install-Jdk` derives from PATH, session first, `Set-UserEnv` | ✓ VERIFIED | Lines 84 and 175 |
| `test.sh` | `mkjdk`, jdk_usable tables, Linux/macOS/Windows JAVA checks, DRY-01 assertions | ✓ VERIFIED | 42 `PASS: JAVA-0x` lines in my `/bin/bash ./test.sh` run (73 passed, 0 failed, 2 skipped) |

### Key Link Verification

`verify.key-links` cannot resolve function-level `from:` values and returns "Source file not found" for all 9 links. I checked each one by hand:

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Linux `install_jdk` | `jdk_usable` | reuse decision | WIRED | `rea-install-linux.sh:335` `if jdk_usable "${JAVA_HOME:-}"; then` |
| Linux `install_jdk` | `setting` | persist own JDK | WIRED | `:352` `setting JAVA_HOME "$STATE_DIR/jdk"` |
| Linux rerun reset | `install_jdk` guard | `$STATE_DIR/*` unset | WIRED | `:381` unset loop; container rerun with inherited `JAVA_HOME=$STATE_DIR/jdk` still exports it (`--with-extras` and `--with-android`) |
| macOS `write_profile` | `jdk_home` | equality check | WIRED | `:173` |
| macOS `install_jdk` | `jdk_usable` | reuse decision | WIRED | `:141` |
| macOS step 4 | `brew_install "$JDK_FORMULA"` | before ghidra | WIRED | awk order 226 < 229 < 231 |
| `Install-Jdk` | `Test-JdkUsable` | reuse + derived check | WIRED | `:177`, `:189` |
| `Install-Jdk` | `Set-UserEnv 'JAVA_HOME'` | session first | WIRED | `:191-192` |
| `Install-Jdk` | `Update-SessionPath` | always before `Get-Command` | WIRED | `:184` |

### Data-Flow Trace (Level 4)

Not applicable (installer scripts, no rendered data). The relevant flow is the `JAVA_HOME` value into the profile block, user variable and agent registration. It is traced in the SC rows above: Linux `setting` goes to `profile_lines`, macOS `export` to `write_profile`, Windows `$env:` to `Set-UserEnv`.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full suite, Bash 3.2 (run once) | `/bin/bash ./test.sh` | exit 0; 73 passed, 0 failed, 2 skipped (Linux-only) | ✓ PASS |
| Linux SC1 end to end | `docker run ... ubuntu:24.04` with `JAVA_HOME=/jdks/jdk17` and `jdk21` stubs, `install --dry-run --with-android` | 17: warning + one Temurin plan + one export; 21: reused, no download | ✓ PASS |
| Linux rerun survival | Same container, `JAVA_HOME=/root/.rea-installer/jdk` inherited, own JDK present, `--with-extras` / `--with-android` | Both plan `export JAVA_HOME="/root/.rea-installer/jdk"` | ✓ PASS |
| macOS SC1/SC2 end to end | Real-brew `install --dry-run --with-android`, temp HOME, `JAVA_HOME` at 17 / 21 stubs | 17: warn, openjdk@21, block with our `JAVA_HOME`; 21: `Using JDK at`, `brew install openjdk@21` + `ghidra` planned, no `JAVA_HOME` line | ✓ PASS (SC1 literal deviation noted) |
| macOS SC3 rerun, sourced shell | Real-brew dry run, `--with-extras`, ghidraRun stub on PATH, `JAVA_HOME`=ours | One block with REA_OBJDUMP, REA_WABT, `JAVA_HOME` | ✓ PASS |
| macOS SC3 rerun, un-sourced shell | Same, `JAVA_HOME` unset | Block planned **without** `JAVA_HOME` | ✗ FAIL (gap) |
| macOS step-4 ledger (non-dry, stubs) | `do_install` with stub brew/npm, user JDK 21 | Ledger: `brew:openjdk@21`, `brew:ghidra`, `npm:...` | ✓ PASS |
| macOS/Linux non-dry self-checks | `install_jdk` with broken own JDK | Both die with their messages | ✓ PASS |
| Windows session-first ordering | pwsh, `Set-UserEnv` keep-existing branch, stale `JAVA_HOME` | Session = fake Temurin; persisted value untouched (this is the CR-01 flow) | ✓ PASS |

### Probe Execution

None declared and no `scripts/*/tests/probe-*.sh` in the repo. Not applicable.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| JAVA-01 | 02-03 | Windows: after Temurin, `JAVA_HOME` for the session and as a recorded user variable, MSI-independent | ✓ SATISFIED (Unix pwsh + code reading; real Windows → VERI-02) | SC4 row; CR-01, WR-01, WR-04, WR-05 below are open risks |
| JAVA-02 | 02-01, 02-02, 02-03 | Existing `JAVA_HOME` reused only if JDK 21+, else own JDK, on every platform | ✗ BLOCKED (partial) | Linux and Windows meet it; macOS meets the rule but SC1's "installs no JDK" fails with Ghidra (override candidate). JRE edge: WR-06 |
| JAVA-03 | 02-02 | macOS never writes a user's JDK 21+ `JAVA_HOME` to the profile | ✓ SATISFIED | SC2 row |
| JAVA-04 | 02-02 | macOS rerun keeps `JAVA_HOME` in the single block when it points at the script's own JDK | ✓ SATISFIED as worded / SC3 ✗ partial | The requirement is conditional ("when it points at"), and that condition holds. Roadmap SC3 and the phase goal ("survives reruns") are not conditional, and the un-sourced-shell rerun fails |

No orphaned requirements: REQUIREMENTS.md maps exactly JAVA-01 to JAVA-04 to Phase 2, and every plan claims at least one of them. REQUIREMENTS.md already marks all four Complete. That is the executor's claim; this report overrides it for JAVA-02 and SC3.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| (all phase files) | - | TBD/FIXME/XXX/TODO/HACK | none found | - |
| `test.sh` | 299-317 | JAVA-04 test sets `JAVA_HOME=$(jdk_home)` itself before the rerun write | ⚠️ Warning | Its pass relies on test setup; it hides the SC3 gap |
| `test.sh` | 448-456 | JAVA-01 winget-ledger assertion is already satisfied by the earlier throw cases (review WR-10) | ⚠️ Warning | The `env:JAVA_HOME` assertion is still meaningful; the winget part is vacuous |
| `rea-install-macos.sh` | 135 | `printf ... "$(brew --prefix ...)"` swallows a brew failure (WR-07) | ⚠️ Warning | Silent fallback; a dry run on a Mac without brew plans `JAVA_HOME=/libexec/...` |
| `rea-install-windows.ps1` | 86 | `Join-Path` on a `JAVA_HOME` whose drive does not exist throws instead of returning `$false` (found in this verification: `Cannot find drive`) | ℹ️ Info | Loud, not silent; `Test-JdkUsable` is not fully fail-closed for a removed or unmapped drive letter |

### Warnings Requiring a Decision (code review 02-REVIEW.md, all still `open`)

None of these falsifies a roadmap criterion as worded, so they are not in `gaps:`. Several conflict with the core value ("a rerun recovers", "uninstall removes only what the script added"). The gap-closure round is the cheap place to fix them or record each one as accepted in 02-REVIEW-DISPOSITION.md.

| ID | Finding | Verifier assessment |
|---|---|---|
| CR-01 | Windows saves a version-specific Temurin folder as the user `JAVA_HOME`; after a `winget upgrade` a rerun cannot replace it | Confirmed by code reading and by the pwsh run above: the rerun warns, fixes the session and leaves the dead user value. Plan 02-03 accepted this as T-02-13 (low) in auto mode. It contradicts "a rerun recovers", and the fix is about 5 lines (overwrite when the ledger holds `env:JAVA_HOME`). **Recommend fixing in the gap-closure round.** |
| WR-01 | The first `java` on PATH may not be Temurin (Oracle `javapath` shim, older JDK first) → throw on every run | SC4's own wording ("derived from the java now on PATH") requires this design. The failure is loud. Assumption A2 is checked under VERI-02. The `javapath` case always throws, whatever the Java version, because its parent folder has no `bin\java.exe` |
| WR-02 | `Update-SessionPath` now replaces the session PATH whenever the JDK is not usable | Session-only Node (fnm) can then fail at step 5. Not covered by an SC |
| WR-03 | In-process `-DryRun` replaces the caller's JDK 17 `JAVA_HOME` with the placeholder | New in this phase for the JDK 17 case (pre-phase code returned early). Conflicts with "dry-run must not change anything" for the `.\script.ps1` form |
| WR-04 | A user-scope JDK 17 `JAVA_HOME` stays persistent on Windows; Linux and macOS override it via the profile block | Decision D-05, made in auto mode. The cross-platform rule differs for new terminals |
| WR-05 | Uninstall deletes the user's `JAVA_HOME` even if the user changed it after install | The ledger stores only the name, not the value |
| WR-06 | The predicate accepts a JRE 21 (no `javac`); REA and Ghidra need a JDK | Matches HARD-06's prescribed fix and locked D-01. RESEARCH recommended `javac` and asked for user confirmation, which auto mode never gave. Example: Ubuntu `openjdk-21-jre-headless` |
| WR-07 | macOS `jdk_home` turns a missing `brew` into `/libexec/...` | See the anti-patterns table |
| WR-08 | macOS rerun `JAVA_HOME` depends on the caller's environment | **Promoted to gap** (SC3) |
| WR-09 | A broken `~/.rea-installer/jdk` makes every Linux rerun die without a recovery hint | Loud, but a rerun never recovers |
| WR-10 | Vacuous winget-ledger assertion | See the anti-patterns table |

### Prohibitions (judgment tier, autonomous verify): unverified, human review recommended

The verdicts below come from an LLM judge and are not authoritative. Each one needs human confirmation; none was silently passed.

| Plan | Prohibition | Judge verdict |
|---|---|---|
| 02-01 | Must not touch the user's JDK or write the user's `JAVA_HOME` into the block | Holds: only `$STATE_DIR/jdk` is moved or persisted |
| 02-01 | Must not print `java -version` output | Holds: `$out` is only regex-matched |
| 02-01 | Must not persist any Linux `JAVA_HOME` other than `$STATE_DIR/jdk` | Holds (the pre-existing Apktool launcher embeds `$JAVA_HOME` as a fallback default; that is a file, not the block) |
| 02-02 | Must not write the user's `JAVA_HOME` or relink the user's JDK | Holds, except the IN-03 edge (a user value identical to the Homebrew path is written; same value) |
| 02-02 | Must not leave ghidra's openjdk@21 out of the ledger | Holds: non-dry stub run recorded it before ghidra |
| 02-02 | Must not print `java -version` output | Holds |
| 02-03 | Must not change `Set-UserEnv` | Holds: diff touches no line in it |
| 02-03 | Must not modify the user JDK or Machine `JAVA_HOME`; must not save a user `JAVA_HOME` other than the derived Temurin folder | Holds as written, with a residual: the "derived" folder may be a non-Temurin JDK 21+ that comes first on PATH (T-02-09, accepted) |
| 02-03 | Must not print `java -version` output | Holds |

### Human Verification Required (preserved under gaps_found)

1. **Accept or reject the SC1 macOS override** (above). It is a product decision made in auto mode (A3).
2. **Decide CR-01, WR-03, WR-05, WR-06 and WR-09**: fix them in the gap-closure round, or set the disposition to accepted in 02-REVIEW-DISPOSITION.md with a reason.
3. **Real Windows (VERI-02):** check backstop truths 22 and 23, PowerShell 5.1 parsing of `java -version` (A1), and that Temurin's `bin` is first on the refreshed PATH (A2).
4. **Confirm or reject the nine judgment-tier prohibition verdicts.**
5. **Resolve the MVP-mode discrepancy** (restate the goal as a user story or drop `mode: mvp`).
6. **Push the commits and confirm both GitHub Actions jobs pass.** CI has not run on any Phase 2 commit.

### Gaps Summary

The single rule is in place and tested on all three platforms. The Linux and Windows halves of SC1, plus SC2 and SC4 (to the standard of evidence SC4 itself names), are met. Two gaps remain, both on macOS:

1. **The script's own `JAVA_HOME` does not always survive a macOS rerun (SC3, the goal's second clause).** It survives only if the rerun's shell already holds it. A rerun from the same terminal, which is how a user recovers from a failed run, rewrites the block without it, while the Linux script recovers it from its own state. The JAVA-04 test cannot see this because it sets `JAVA_HOME` itself. The fix is small: decide from what the script installed (the ledger or the old block), not from the caller's environment, and add a test with `JAVA_HOME` unset.
2. **SC1's "installs no JDK" is not met on macOS when Ghidra is installed**, because Homebrew's ghidra formula depends on openjdk@21. This is most likely resolved by accepting the suggested override, not by code.

Not a gap but strongly recommended for the same round: CR-01 (Windows saved `JAVA_HOME` goes stale after a Temurin upgrade and a rerun cannot repair it). Phase 3 (DOCS-01) only documents limitations, so none of these items is deferred to it.

---

_Verified: 2026-10-14T19:58:12Z_
_Verifier: Claude (gsd-verifier)_
