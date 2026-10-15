---
phase: 02-consistent-java-handling
verified: 2026-10-15T02:23:48Z
status: gaps_found
score: 51/56 must-haves verified
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
  - ".planning/phases/02-consistent-java-handling/02-08-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-08-SUMMARY.md"
  - ".planning/phases/02-consistent-java-handling/02-09-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-09-SUMMARY.md"
  - ".planning/phases/02-consistent-java-handling/02-10-PLAN.md"
  - ".planning/phases/02-consistent-java-handling/02-10-SUMMARY.md"
  - ".planning/phases/02-consistent-java-handling/02-REVIEW-DISPOSITION.md"
  - ".planning/phases/02-consistent-java-handling/02-REVIEW.md"
  - ".planning/phases/02-consistent-java-handling/02-UAT.md"
  - "rea-install-linux.sh"
  - "rea-install-macos.sh"
  - "rea-install-windows.ps1"
  - "test.sh"
covered_digest: "v3:sha256:cfedafb24a4c97c44df48b2f86a9161f1c94d0d29cc591a2d2a6efd172ceb4c5"
behavior_unverified: 0
overrides_applied: 1
overrides:
  - must_have: "With JAVA_HOME pointing at JDK 21 or newer, it reuses the existing one and installs no JDK"
    reason: "On macOS, Homebrew's ghidra formula depends on openjdk@21, so installing Ghidra pulls in a JDK regardless; the script reuses the user's JAVA_HOME, writes no JAVA_HOME line, and records openjdk@21 so uninstall removes it. Holds literally with --no-ghidra or when Ghidra is already present."
    accepted_by: "Ken Scott"
    accepted_at: "2026-10-14T20:30:00Z"
re_verification:
  previous_status: human_needed
  previous_score: 43/45
  gaps_closed:
    - "G-02-2 (old review WR-01): a macOS --no-ghidra rerun that replaces a set JDK 17 JAVA_HOME prints the D-04 warning exactly once (3c1259d)"
    - "G-02-4 (old review WR-02): Windows replaces a ledger-owned user JAVA_HOME whose folder has no bin\\java.exe (58bad6d)"
    - "G-02-5 (old review IN-01): jdk_owned reads only the PROFILE_BEGIN..PROFILE_END block (e9e01f1)"
    - "G-02-6: .github/workflows/test.yml deleted; ROADMAP, REQUIREMENTS, PROJECT and .claude/CLAUDE.md describe local runs (84a334a, 8ec879e)"
    - "Previous human item 5: the 5 open disposition rows were recorded (16d17e4)"
    - "Previous human item 7 (push and check CI): moot after G-02-6"
  gaps_remaining:
    - "G-02-1: only partly closed. The filter misses the real 'NOTE: Picked up JDK_JAVA_OPTIONS: ...' line (new review CR-01, reproduced with a real JDK)"
    - "G-02-3: only partly closed. It works only when another export forces a block rewrite. A plain --no-ghidra rerun keeps the dead JAVA_HOME in the block, and the session still depends on the shell (new review WR-01, reproduced)"
  regressions:
    - "rea-install-windows.ps1:205 (58bad6d, 02-09) replaced the crash-safe Test-Path -LiteralPath $userJava with Join-Path, which throws 'Cannot find drive' when the saved JAVA_HOME is on an unavailable drive (new review WR-02). Line 88 has had the same pattern since d69aca5 (02-03)"
gaps:
  - truth: "The Linux 'JDK does not run' error never prints 'Picked up ...' lines from java -version (G-02-1; prohibition 02-09 #1 and 02-01 T-02-02)"
    status: failed
    reason: "The filter `grep -v '^Picked up'` misses the real launcher format for JDK_JAVA_OPTIONS, `NOTE: Picked up JDK_JAVA_OPTIONS: ...`. Reproduced with the Homebrew openjdk@17 on this Mac, and through the shipped install_jdk with a stub JDK that prints the real format. The die printed `NOTE: Picked up JDK_JAVA_OPTIONS: -Dhttps.proxyPassword=hunter2 -Xbogus`. The regression test passes only because its fixture writes a format no JDK prints, and its secret is in a different line"
    artifacts:
      - path: "rea-install-linux.sh"
        issue: "line 381: `grep -v '^Picked up'` keeps `NOTE: Picked up JDK_JAVA_OPTIONS: ...`"
      - path: "test.sh"
        issue: "line 351: the fixture prints `Picked up JDK_JAVA_OPTIONS: -Xss2m` with no `NOTE: ` prefix, and the hunter2 secret sits only in the JAVA_TOOL_OPTIONS line"
    missing:
      - "Change the filter to `grep -Ev '^(NOTE: )?Picked up '`, keeping it inside the die argument with no `||` fallback"
      - "Change the test.sh:351 fixture to print the real `NOTE: Picked up JDK_JAVA_OPTIONS: -Dhttps.proxyPassword=hunter2` line, with the secret in that line, and confirm the check fails before the fix"
      - "Update the comment at rea-install-linux.sh:379 and the jdk_usable comments (linux:284, macos:92, windows:85) to name the NOTE form"
  - truth: "A macOS --no-ghidra rerun whose owned openjdk@21 no longer runs gives the same result from any shell: JAVA_HOME is left out of the block and a warning says so (G-02-3)"
    status: partial
    reason: "Branch a of write_profile only clears the local `ours`. On a plain --no-ghidra rerun nothing else is queued in profile_exports, so the old block is never rewritten. Reproduced under /bin/bash 3.2 with the test.sh brew stub: the block still exports the dead path while the warning says JAVA_HOME 'is left out of' the profile. Session JAVA_HOME is the dead path in a shell that sourced the block and unset in one that did not, and step 9 (`rea setup`) copies it into the agent registrations. The regression test always queues `export REA_TEST=1` (the --with-extras shape) and starts with no block, so the default rerun is never exercised"
    artifacts:
      - path: "rea-install-macos.sh"
        issue: "lines 231-234: dropping ours neither unsets a session JAVA_HOME equal to ours nor removes the old block; line 249 rewrites the block only when profile_exports is non-empty"
      - path: "test.sh"
        issue: "lines 482-496: both modes queue REA_TEST=1 and start with no existing block"
    missing:
      - "When branch a drops ours: `[ \"${JAVA_HOME:-}\" = \"$ours\" ] && unset JAVA_HOME`, and remove the old block even when profile_exports is empty (for example, an elif that calls remove_profile_block when a drop flag is set)"
      - "test.sh case: an existing block exporting the dead ours, ledger brew:openjdk@21, nothing queued, run in both modes (JAVA_HOME=ours and unset). Expect no `export JAVA_HOME=` in the profile and JAVA_HOME unset in the session after write_profile. Darwin-guarded, because remove_profile_block uses BSD sed -i ''"
      - "Optional (review IN-01): the warning should name a repair that does not install Ghidra, for example `brew reinstall openjdk@21`"
  - truth: "Windows applies the rule to every unusable JAVA_HOME: one on an unavailable drive gets the D-04 warning and Temurin, not a provider crash (SC1 rule, 02-03 #4 fail-closed parity with the bash jdk_usable table)"
    status: partial
    reason: "Under $ErrorActionPreference = 'Stop', Join-Path on 'Q:\\jdk-17' throws 'Cannot find drive. A drive with the name 'Q' does not exist.', reproduced in pwsh 7.6.7 against the shipped Test-JdkUsable. Test-Path -LiteralPath returns False for the same path. Install-Jdk stops before the rule applies, even for a user value the script never set. Lower severity: the install stops loudly, not silently. The trigger is narrow (a mapped network drive or a removable disk). The fix is two lines"
    artifacts:
      - path: "rea-install-windows.ps1"
        issue: "line 88 (Test-JdkUsable, since d69aca5) and line 205 ($gone, new in 58bad6d): Join-Path on a caller-supplied path"
    missing:
      - "Use [IO.Path]::Combine($Dir, 'bin', 'java.exe') at line 88 and [IO.Path]::Combine($userJava, 'bin', 'java.exe') at line 205. Both work on .NET Framework 4.x (PS 5.1) and .NET (PS 7)"
      - "pwsh driver case: $env:JAVA_HOME = 'Q:\\jdk-17', expect the 'not JDK 21 or newer' warning and no throw. Also a case with the saved user value on Q:"
---

# Phase 2: Consistent Java Handling Verification Report

**Phase Goal:** Linux, macOS and Windows all follow one rule (reuse an existing `JAVA_HOME` only if it is JDK 21 or newer, otherwise install and record the script's own JDK) and the script's own `JAVA_HOME` survives reruns
**Verified:** 2026-10-15T02:23:48Z
**Status:** gaps_found
**Re-verification:** Yes. This runs after UAT gap-closure plans 02-08, 02-09 and 02-10, which target G-02-1 to G-02-6. The previous report had no `gaps:` block, so every new must-have got a full check. Earlier must-haves got a regression check: the full suite on both platforms plus re-reading the code they rest on.

## Goal Achievement

The core rule still holds on all three platforms in the normal paths. All four roadmap success criteria are met as worded, and both local suites are green: macOS Bash 3.2 gave 96 passed, 0 failed, 2 skipped, and ubuntu:24.04 gave 63 passed, 0 failed, 11 skipped. Four of the six UAT gaps are fully closed.

Two UAT gaps are only partly closed, and the gap closure added one regression. I reproduced all three myself, against the shipped code. I did not take them from the review:

1. **G-02-1 (CR-01).** The `Picked up` filter misses the real `NOTE: Picked up JDK_JAVA_OPTIONS:` line, so the credential leak the gap was meant to stop still happens. The test fixture uses a format no JDK prints.
2. **G-02-3 (WR-01).** The "same result from any shell" fix works only when `--with-extras` forces a block rewrite. On a plain `--no-ghidra` rerun, the dead `JAVA_HOME` stays in the block, the warning says the opposite, and `rea setup` still gets a value that depends on the shell.
3. **WR-02 (regression).** A Windows `JAVA_HOME` on an unavailable drive crashes `Install-Jdk` with a provider error. That path was crash-safe before 02-09 at line 205; line 88 has had the same pattern since 02-03.

The suite stays green because no test covers any of these three inputs. A green suite is therefore not evidence that these gaps are closed.

### Observable Truths

**Roadmap success criteria (contract): regression check**

| # | Truth | Status | Evidence |
|---|---|---|---|
| SC1 | JDK 17 `JAVA_HOME`: own JDK 21 on all three platforms. JDK 21+: reused, no JDK installed | ✓ VERIFIED (macOS + fresh Ghidra: PASSED (override)) | Linux `install_jdk` (linux:330-385), macOS `install_jdk` (macos:169-184), Windows `Install-Jdk` (win:185-209). JAVA-02 tests on all three pass on this run. The WR-02 drive edge is tracked as gap 3: a missing drive is not a JDK 17 |
| SC2 | macOS, JDK 21+ `JAVA_HOME`: no `JAVA_HOME` line in the block | ✓ VERIFIED | write_profile branch d (macos:240-241). `JAVA-03 macOS rerun reuses a JDK 21 JAVA_HOME even when it owns openjdk@21` now also asserts there is no "does not run" warning, and it passes |
| SC3 | macOS, two `--with-extras`/`--with-android` runs: one block, still exporting our `openjdk@21` | ✓ VERIFIED | `JAVA-04 macOS rerun keeps one profile block ...`, `... restores ... from the ledger`, `... --no-ghidra rerun writes its own JAVA_HOME whether or not the shell has it set`, `... owned only through the old block`. All pass |
| SC4 | Windows: session and user `JAVA_HOME` = the Temurin folder derived from `java` on PATH, removed by uninstall, MSI or not | ✓ VERIFIED (as worded: code + pwsh driver; real Windows is VERI-02) | `Install-Jdk` win:196-208; `JAVA-01 Windows Install-Jdk sets JAVA_HOME from the java on PATH and records it` passes |

**UAT gaps and gap-closure plan must-haves (full check)**

| # | Truth | Status | Evidence |
|---|---|---|---|
| G-02-1 / 02-09 #1 | The Linux "does not run" error never prints `Picked up` lines | ✗ FAILED | linux:381 `grep -v '^Picked up'`. A real JDK prints `NOTE: Picked up JDK_JAVA_OPTIONS: ...`; verified with `/opt/homebrew/opt/openjdk@17` on this Mac. The shipped `install_jdk`, run with a stub JDK that prints the real format, died with `... java -version printed: NOTE: Picked up JDK_JAVA_OPTIONS: -Dhttps.proxyPassword=hunter2 -Xbogus`. The plan truth "every line starting 'Picked up' removed" holds literally, but the UAT truth and the prohibition do not |
| G-02-2 / 02-08 #1 | A `--no-ghidra` rerun replacing a set JDK 17 `JAVA_HOME` prints the D-04 warning exactly once | ✓ VERIFIED | Branch c, macos:237-239. `JAVA-02 macOS --no-ghidra rerun warns before replacing a JDK 17 JAVA_HOME with its own` passes and asserts a count of 1. 02-08 SUMMARY shows the red run |
| G-02-3 / 02-08 #2 | Dead owned JDK: same result from any shell, `JAVA_HOME` left out of the block, with a warning | ✗ FAILED (partial) | Holds when another export is queued (the test shape). On a plain `--no-ghidra` rerun with an existing block, both modes printed the "left out of" warning, yet the block still held `export JAVA_HOME="<dead ours>"`. Session `JAVA_HOME` was the dead path in one mode and `<unset>` in the other (Bash 3.2 repro below) |
| 02-08 #3 | Dead owned JDK, usable user JDK 21+: no warning, no line | ✓ VERIFIED | macos:232 `jdk_usable "${JAVA_HOME:-}" \|\| warn`; the JAVA-03 owned-ledger check asserts there is no "does not run" output |
| G-02-5 / 02-08 #4 | `jdk_owned` reads only the block, and a user line is neither ownership nor a reason to call `brew --prefix` | ✓ VERIFIED | macos:163-166: a sed range into `block`, then 2 here-string greps. `JAVA-03 macOS jdk_owned ignores a user JAVA_HOME line outside its profile block` passes under a failing `brew` stub |
| G-02-4 / 02-09 #2 | Windows replaces a ledger-owned user `JAVA_HOME` whose folder has no `bin\java.exe`, and the log says "has no java.exe" | ✓ VERIFIED | win:205-208, win:130; `... replaces a saved JAVA_HOME it set whose folder has no java.exe` passes (asserts the setx line and no "leaving it as-is") |
| 02-09 #3 | A saved value that holds `bin\java.exe` is kept; one the script never set is left as-is (D-05) | ✓ VERIFIED | `... keeps an existing user JAVA_HOME even when it set one earlier` and `... leaves a user JAVA_HOME it did not set` pass. The unavailable-drive exception is gap 3 |
| WR-02 (derived from SC1 rule / 02-03 #4) | Windows applies the rule to any unusable `JAVA_HOME`, an unavailable drive included, without crashing | ✗ FAILED (partial, lower severity) | Reproduced in pwsh 7.6.7: the shipped `Test-JdkUsable 'Q:\jdk-17'` throws `Cannot find drive`. The bash `jdk_usable` fails closed for every path |
| 02-09 #4 | Disposition record `open: 0`, `total: 31` with the listed rows | ✓ VERIFIED (literal, at 16d17e4) | Frontmatter shows `open: 0`, `total: 31`, WR-01/WR-03/IN-01 fixed in 02-08, WR-02 fixed in 02-09, IN-02 deferred. See the process note below about the newer review |
| G-02-6 / 02-10 #1 | No GitHub Actions; nothing under `.github` | ✓ VERIFIED | `.github` does not exist; `git ls-files` lists nothing under it |
| 02-10 #2 | test.sh: comment changes only (plus one SKIP text) | ✓ VERIFIED | The `git show 84a334a -- test.sh` diff has 5 changed lines: 4 comments and the SKIP message `not on this runner` changed to `not on this Mac` |
| 02-10 #3 | ROADMAP, REQUIREMENTS, PROJECT and CLAUDE.md describe local runs | ✓ VERIFIED | TEST-06 names both commands. Out-of-scope row added. PROJECT.md:64 and .claude/CLAUDE.md:17 Testing lines are byte-identical (`diff` is empty) |
| 02-10 #4 | Completed history not rewritten; Phase 1 criterion gets a dated note | ✓ VERIFIED | No `.planning/phases/01-*` file is in 84a334a or 8ec879e. ROADMAP:28 carries the dated note, and ROADMAP:15/23/37/47 (Phase 1 history) keep "CI" by design |
| Gate (02-08 #5, 02-09 #5, 02-10 #5; supersedes 02-07 #6) | Both local runs report 0 failed | ✓ VERIFIED | Verifier ran: `/bin/bash ./test.sh` (3.2.57) gave 96 passed, 0 failed, 2 skipped; `docker run ... ubuntu:24.04 ... ./test.sh` gave 63 passed, 0 failed, 11 skipped |

**Earlier must-haves (02-01 to 02-07), regression check:** the 41 truths verified in the previous report still hold. Every named test passes on this run, and the code under each was re-read where 02-08 and 02-09 touched it (write_profile, jdk_owned, Linux die, Install-Jdk). Changes since the last report:
- **Superseded, not counted:** 02-07 #1, by G-02-4 (the "folder is gone" rule became "has no java.exe"), and 02-07 #2, by G-02-4 (log text "no longer exists" became "has no java.exe"). 02-07 #6 is superseded by the gate row above.
- **Still `insufficient_spec` (backstop; real Windows only):** 02-03 #9 and 02-03 #10. Not counted as verified.

**Score:** 51/56 truths verified (1 via override). 3 failed. 2 `insufficient_spec` backstop truths still need real Windows (VERI-02). 0 present-but-behavior-unverified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `rea-install-macos.sh` | write_profile if/elif chain; jdk_owned limited to the block; `Rerun without --no-ghidra` | ✓ VERIFIED (substantive, wired) | verify.artifacts 02-08: all_passed. The chain is called from `do_install` step 7. Wiring is incomplete for the plain-rerun case (gap 2) |
| `rea-install-linux.sh` | `grep -v '^Picked up'` in the install_jdk die | ⚠️ present, wrong pattern | verify.artifacts 02-09 passes because the `contains:` string is the defective pattern itself (gap 1) |
| `rea-install-windows.ps1` | `has no java.exe` replace rule | ✓ VERIFIED (with the gap 3 regression at line 205) | Called from `Invoke-Install` (Ghidra and Android steps) |
| `test.sh` | Regression checks for WR-01, WR-03, IN-01, G-02-1 and G-02-4 | ⚠️ present, two fixtures do not match production | The G-02-1 fixture uses a made-up format (test.sh:351). The G-02-3 loop always queues REA_TEST=1 (test.sh:487-489) |
| `02-REVIEW-DISPOSITION.md` | `open: 0` | ✓ VERIFIED (as of 16d17e4) | Predates the 21:18 re-review; see the process note |
| `.github/workflows/test.yml` | deleted | ✓ VERIFIED | absent |

### Key Link Verification

`verify.key-links` cannot resolve function-name `from:` values (exit 1, "Source file not found"), so I checked each link by hand:

| From | To | Via | Status | Details |
|---|---|---|---|---|
| macOS `write_profile` | `jdk_usable "$ours"` | outside `jdk_chosen` | WIRED | macos:231 `[ "$jdk_chosen" = false ] && ! jdk_usable "$ours"` |
| macOS `write_profile` branch a | profile block / session `JAVA_HOME` | dropping ours must reach the file and the session | ✗ NOT_WIRED | Only the local `ours` is cleared. The block is rewritten only if `profile_exports` is non-empty (macos:249), and the session value is never unset (gap 2) |
| macOS `jdk_owned` | `PROFILE_BEGIN..PROFILE_END` | sed range into a variable, grep through `<<<` | WIRED | macos:163-166; awk scope check finds 2 here-strings |
| Linux `install_jdk` die | `java -version` output | filter between `2>&1` and `head -3` | PARTIAL | Wired, but the pattern does not match the real `NOTE:` form (gap 1) |
| Windows `Install-Jdk` `$gone` | `Set-UserEnv -Replace` | `Test-Path ... -PathType Leaf` on `bin\java.exe` | WIRED | win:205-208. Join-Path throws before Test-Path on a missing drive (gap 3) |
| PROJECT.md Testing line | .claude/CLAUDE.md Testing line | byte-identical | WIRED | `diff` is empty |

### Data-Flow Trace (Level 4)

Not applicable: these are installer scripts with no rendered data. The relevant flow is ledger → `jdk_owned` → `write_profile` → profile block and session → `rea setup` (step 9). The verifier traced it in the WR-01 reproduction. The session `JAVA_HOME` handed to `rea setup` is the caller's inherited value when branch a fires, so for a dead owned JDK it is not driven by the ledger.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full suite, macOS Bash 3.2.57 | `/bin/bash ./test.sh` | 96 passed, 0 failed, 2 skipped (Linux-only) | ✓ PASS |
| Full suite, ubuntu:24.04 | `docker run --rm -v "$PWD":/src:ro ubuntu:24.04 bash -c 'cp -r /src /w && cd /w && ./test.sh'` | 63 passed, 0 failed, 11 skipped; all 4 new bash gap checks PASS | ✓ PASS |
| Real JDK `JDK_JAVA_OPTIONS` format | `JDK_JAVA_OPTIONS='-Dhttps.proxyPassword=hunter2 -Xbogus' openjdk@17/bin/java -version 2>&1 \| grep -v '^Picked up' \| head -3` | First line is `NOTE: Picked up JDK_JAVA_OPTIONS: -Dhttps.proxyPassword=hunter2 -Xbogus` | ✗ FAIL (gap 1) |
| CR-01 through the shipped `install_jdk` | harness `sandbox "$LINUX" 'unset JAVA_HOME; install_jdk'` with a stub JDK that prints the real NOTE line and exits 1 | rc=1; `error: ... java -version printed: NOTE: Picked up JDK_JAVA_OPTIONS: -Dhttps.proxyPassword=hunter2 -Xbogus` | ✗ FAIL (gap 1) |
| WR-01 plain `--no-ghidra` rerun, dead owned JDK | harness `sandbox "$MACOS"`, ledger `brew:openjdk@21`, old block exporting ours, no JDK under ours, nothing queued, `write_profile`, both modes | Both: warning "JAVA_HOME is left out of .bash_profile", but the block still exports the dead path. Session: dead path (export mode) vs `<unset>` (unset mode) | ✗ FAIL (gap 2) |
| WR-02 missing drive | pwsh 7.6.7, `$ErrorActionPreference='Stop'`, extracted shipped `Test-JdkUsable 'Q:\jdk-17'` | `THROW: Cannot find drive. A drive with the name 'Q' does not exist.`; `Test-Path -LiteralPath` returns False; `[IO.Path]::Combine` does not throw | ✗ FAIL (gap 3) |
| Summary commits exist | `git log 5e1e32f..HEAD` on the 4 source files | dd29259, 3c1259d, 0f17524, e9e01f1, c88ef3f, 0039deb, ed83bbf, 58bad6d, 84a334a all present | ✓ PASS |
| No Bash 4+ in the macOS script | `grep -cE 'mapfile\|declare -A\|${x,,}'` | 0 | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` exist, and no plan declares one. Step 7c does not apply.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| JAVA-01 | 02-03, 02-05, 02-07, 02-09 | Windows: after Temurin, session and user `JAVA_HOME` = Temurin 21; uninstall removes it; MSI-independent | ✓ SATISFIED as worded (real Windows: VERI-02) | SC4 row. Gap 3 is a crash on an unavailable-drive `JAVA_HOME` before Temurin is chosen; it does not change the post-install contract |
| JAVA-02 | 02-01, 02-02, 02-03, 02-04, 02-06, 02-09 | Every platform reuses `JAVA_HOME` only if JDK 21+, else installs its own | ⚠️ SATISFIED in normal paths; the Windows missing-drive edge is gap 3 | SC1 row; predicate tables for all three scripts |
| JAVA-03 | 02-02, 02-04, 02-06, 02-08 | macOS never writes a user's JDK 21+ `JAVA_HOME` into the profile | ✓ SATISFIED | SC2 row; IN-01 check |
| JAVA-04 | 02-02, 02-04, 02-06, 02-08 | macOS rerun keeps our `JAVA_HOME` in the single block | ✓ SATISFIED as worded | SC3 row. Gap 2 is the inverse case (a dead owned JDK is not dropped) and is not part of JAVA-04's wording |
| TEST-06 | 02-10 (Phase 1 requirement, revised) | Local runs only, no GitHub Actions | ✓ SATISFIED | G-02-6 row |

REQUIREMENTS.md maps JAVA-01 to JAVA-04 to Phase 2, and all four are claimed by plans. TEST-06 is a Phase 1 requirement that plan 02-10 re-touched. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| (all four source files) | - | TBD/FIXME/XXX/TODO/HACK | none found | - |
| rea-install-linux.sh | 381 | Filter pattern does not match the real `NOTE: Picked up` launcher line | 🛑 Blocker | Proxy credentials in `JDK_JAVA_OPTIONS` print in the error (gap 1) |
| test.sh | 351 | Fixture emits a format no JDK prints; the secret is placed in a different line | 🛑 Blocker (paired with the above) | The test passes against the defect it is meant to catch |
| rea-install-macos.sh | 231-234, 249 | The warning claims the value is "left out" when the block is not rewritten | 🛑 Blocker | A dead `JAVA_HOME` persists in the profile and reaches `rea setup` from shells that sourced it (gap 2) |
| test.sh | 487-489 | The test always queues `REA_TEST=1`, a fixture-only precondition that the default rerun lacks | ⚠️ Warning | Hides gap 2 |
| rea-install-windows.ps1 | 88, 205 | `Join-Path` on a caller-supplied path under `ErrorActionPreference Stop` | ⚠️ Warning (gap 3) | Provider crash instead of the D-04 warning on an unavailable drive |
| rea-install-macos.sh | 233 | Repair advice "Rerun without --no-ghidra" installs Ghidra, and does not repair a listed-but-broken formula (new review IN-01) | ℹ️ Info | Misleading advice; fix together with gap 2 |
| rea-install-windows.ps1 | 122, 130 | The generic `Set-UserEnv` hard-codes "has no java.exe" (new review IN-02) | ℹ️ Info | Wrong reason for any future `-Replace` caller |

### Prohibitions

| Plan | Prohibition | Tier | Verdict |
|---|---|---|---|
| 02-09 #1 / 02-01 #2 | MUST NOT print a `Picked up` line from `java -version` output | automated | **FAILED.** Enforcement evidence is fixture-only (test.sh:351 uses a format no JDK prints). Reproduced leak with a real JDK |
| 02-09 #2 | Never overwrite a user value holding `bin\java.exe` or one never recorded; no Machine `JAVA_HOME` | automated | Holds: the tests pass, and the only `'Machine'` read is `Path` (win:74) |
| 02-09 #3 | Disposition values and Source cells | automated | Holds: values are only `fixed`/`deferred`, with no pipe in any Source cell |
| 02-08 #1 | Never replace a set `JAVA_HOME` without the D-04 warning | automated | Holds: install_jdk:177 and write_profile branch c both warn; tested |
| 02-08 #2 | Never write a dead `JAVA_HOME` into the block | automated | Holds literally: no write happens. But a plain rerun *leaves* the dead line in place while saying it was left out (gap 2) |
| 02-08 #3 | No Bash 4+ in macOS | automated | Holds: 0 matches; the suite runs under 3.2.57 |
| 02-10 #1 | test.sh code unchanged | automated | Holds (diff above) |
| 02-10 #2 | No edits to Phase 1 artifacts or 01-* plan-list lines | automated | Holds |
| 02-06 #1 | The caller's `JAVA_HOME` must not alone decide keep or drop (judgment) | judgment, non-authoritative | **Still violated in the gap 2 edge:** what `rea setup` receives depends on the caller's shell. Flagged for human review |

### Process Note: 02-REVIEW-DISPOSITION.md vs the new 02-REVIEW.md

The disposition record (written 21:06) predates the re-review (21:18). The re-review reuses the ids CR-01, WR-01, WR-02, IN-01 and IN-02 for **new** findings, but the record's rows with those ids describe the **older** findings (CR-01 "fixed in 02-05", WR-01 "fixed in 02-08", and so on). The new findings are therefore not triaged yet, although the record still reads `open: 0`. According to the record's own footer, the next gate run drops the earlier decisions whose ids are reused. Gap-closure planning should record the new findings, preferably under fresh ids such as CR-301 and WR-301, so the 31 earlier decisions survive.

### Human Verification Required (still outstanding; does not change gaps_found)

1. **Real Windows (VERI-02).** Fresh install, a rerun after a Temurin upgrade, `-DryRun` in-process, and Windows PowerShell 5.1. Backstop truths 02-03 #9 (a rerun with an equal user value adds no warning or ledger line) and #10 (the first `java` after a winget install is Temurin's) need it, and so does the real User scope. Blocked on a physical device (UAT test 6).

### Gaps Summary

All three remaining gaps come from the same pattern: **each fix was tested only against the input shape its own test builds, and the production input differs.**

1. **G-02-1, Linux credential filter (BLOCKER).** A one-line fix: `grep -Ev '^(NOTE: )?Picked up '`. The test fixture must print the real `NOTE:` line with the secret in it, and must fail before the fix.
2. **G-02-3, macOS dead owned JDK on a plain `--no-ghidra` rerun (BLOCKER).** Branch a has to act on the profile and the session, not only the local `ours`: unset a session `JAVA_HOME` equal to ours, and remove the old block when nothing else is queued. The test needs an existing block and no queued export.
3. **WR-02, Windows `Join-Path` on an unavailable drive (lower severity, a regression at line 205).** Use `[IO.Path]::Combine` at lines 88 and 205, and add a `Q:\` driver case.

Closed in this round: G-02-2, G-02-4, G-02-5 and G-02-6, plus the earlier human items 5 and 7. All four roadmap success criteria and JAVA-01, JAVA-03 and JAVA-04 are met as worded. JAVA-02 is met everywhere except the gap 3 edge. Phase 3 (macOS unattended install and README) covers none of these, so nothing is deferred. A single small gap-closure plan covering 02-REVIEW.md CR-01, WR-01 and WR-02 (plus IN-01 wording) would close the phase.

---

_Verified: 2026-10-15T02:23:48Z_
_Verifier: Claude (gsd-verifier)_
