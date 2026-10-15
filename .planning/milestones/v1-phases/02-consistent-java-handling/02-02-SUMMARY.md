---
phase: 02-consistent-java-handling
plan: 02
subsystem: installer
tags: [bash, jdk, java_home, macos, homebrew, profile, test.sh]

requires:
  - phase: 02-consistent-java-handling
    provides: "jdk_usable DIR predicate in rea-install-macos.sh (plan 02-01)"
provides:
  - "macOS jdk_home: the stable brew --prefix openjdk@21 JDK home"
  - "macOS install_jdk reuses a JDK 21+ JAVA_HOME, warns once on an older one, installs openjdk@21 and self-checks it"
  - "macOS write_profile (former step 7): adds JAVA_HOME to the block only when it equals jdk_home"
  - "Step 4 records openjdk@21 before ghidra when a user JDK was reused; step 5 always calls install_jdk"
  - "test.sh stub brew plus JAVA-02, JAVA-03 and JAVA-04 macOS checks"
affects: [02-03 Windows JDK handling, 03 DOCS-01 README known limitations]

actuals:
  tokens: 1700
  tasks: 2
  commits: 2
plan_head_before: 30053368077d779ce8d30389d77b16e8a659c33f
plan_head_after: cdf0f7eff1deeff21d7c224cb253fea2f7ed8689

tech-stack:
  added: []
  patterns:
    - "Profile-time equality check: the block gets JAVA_HOME only when it equals the script's own JDK path, so reuse, rerun and deduplication are decided in one place"
    - "Stub brew in test.sh: --prefix prints a path under the temp HOME, list exits 0, so brew_install never installs"

key-files:
  created: []
  modified:
    - rea-install-macos.sh
    - test.sh

key-decisions:
  - "macOS install_jdk no longer touches profile_exports; write_profile appends JAVA_HOME once, and only when it is $(jdk_home)"
  - "Step 4 brew_installs openjdk@21 before ghidra when a user JDK is reused (assumption A3), so Homebrew's ghidra dependency is recorded and uninstall removes it"
  - "A second install_jdk call in the same run re-runs brew_install for openjdk@21 (idempotent, as RESEARCH accepted); no same-run flag was added"

patterns-established:
  - "Test macOS install steps by calling extracted functions (install_jdk, write_profile) with a stub brew; never load_brew or do_install"

requirements-completed: [JAVA-02, JAVA-03, JAVA-04]

coverage:
  - id: D1
    description: "macOS rerun (second write with install_jdk skipped) leaves one profile block with one export JAVA_HOME line pointing at the script's openjdk@21"
    requirement: JAVA-04
    verification:
      - kind: unit
        ref: "test.sh#JAVA-04 macOS rerun keeps one profile block exporting its own JAVA_HOME (Darwin, /bin/bash 3.2 and default shell)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A user JDK 21+ JAVA_HOME is reused, left unchanged, and never written to the macOS profile block"
    requirement: JAVA-03
    verification:
      - kind: unit
        ref: "test.sh#JAVA-03 macOS reused JDK 21 JAVA_HOME is not written to the profile (Mac and ubuntu:24.04)"
        status: pass
      - kind: other
        ref: "mutation check: dropping the jdk_home equality in write_profile, or the jdk_usable reuse in install_jdk, turns this check FAIL"
        status: pass
    human_judgment: false
  - id: D3
    description: "A JDK 17 JAVA_HOME gets one D-04 warning over two install_jdk calls and is replaced by the openjdk@21 home"
    requirement: JAVA-02
    verification:
      - kind: unit
        ref: "test.sh#JAVA-02 macOS install_jdk replaces a JDK 17 JAVA_HOME with openjdk@21 (Mac and ubuntu:24.04)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Step 4 installs and records openjdk@21 before ghidra when a user JDK was reused; step 5 always goes through install_jdk; uninstall removes ghidra before openjdk@21"
    requirement: JAVA-03
    verification:
      - kind: other
        ref: "plan Task 2 awk order check (order ok) and a real-brew dry run with a stub user JDK 21 printing brew install openjdk@21 then brew install ghidra"
        status: pass
    human_judgment: true
    rationale: "Recording brew:openjdk@21 on a real install, and the uninstall order, need a real Homebrew install; checked by code reading and dry run only (as with FAIL-03)."

duration: 3min
completed: 2026-10-14
status: complete
---

# Phase 2 Plan 02: macOS JDK 21 rule and rerun-safe profile block Summary

**On macOS a usable user `JAVA_HOME` (JDK 21+) is now reused and never written to the profile, an older one is replaced by Homebrew `openjdk@21` after one warning, and `write_profile` keeps exactly one `export JAVA_HOME=` line for the script's own JDK across reruns.**

## Performance

- **Duration:** about 3 min from the first edit (reading not counted)
- **Started:** 2026-10-14T19:32:28Z
- **Completed:** 2026-10-14T19:35:04Z
- **Tasks:** 2 of 2
- **Files modified:** 2

## Accomplishments

- `jdk_home` prints `$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home`.
- `install_jdk` follows the Linux rule. When `JAVA_HOME` is not already ours, it either reuses it (if `jdk_usable`) or prints the D-04 warning. Then it calls `brew_install openjdk@21`, exports our path and runs the self-check `jdk_usable "$ours" || die "Homebrew openjdk@21 at <path> does not run."` (not in dry runs). It never prints `java -version` output.
- Step 7 is now `write_profile`. Its first statement adds `JAVA_HOME` only when it equals `jdk_home`, and the rest of the step-7 body is unchanged.
- Step 5 (Android) calls `install_jdk` unconditionally. Step 4 (Ghidra) calls `brew_install openjdk@21` before `brew_install ghidra` when a user JDK was reused.
- test.sh has a stub brew and three macOS checks. JAVA-04 runs on Darwin only (BSD `sed -i ''`). JAVA-03 and JAVA-02 macOS run on every OS.

## Task Commits

1. **Task 1 (tracer): macOS rerun keeps the script's own JAVA_HOME in one profile block** - `2d5d75d` (Keep the macOS JAVA_HOME in the profile block across reruns)
2. **Task 2: reuse a JDK 21+, replace a JDK 17, record Ghidra's openjdk@21** - `cdf0f7e` (Reuse a JDK 21+ JAVA_HOME on macOS and record Ghidra's openjdk@21)

## Files Created/Modified

- `rea-install-macos.sh` - `jdk_home`, reworked `install_jdk`, new `write_profile`, step 4 and step 5 changes. The header (lines 1-11), the source guard and `do_uninstall` are unchanged.
- `test.sh` - new section "JAVA-02/03/04 macOS install_jdk and profile" after the jdk_usable table

## Verification

- Phase gate: `exit: default=0 bash32=0 ubuntu=0` and no FAIL lines. The Mac ran 57 passes and 2 Linux-only skips under both shells. ubuntu:24.04 ran 47 passes and 10 skips, including `SKIP: JAVA-04 macOS ... (macOS only)` and PASS for JAVA-03 macOS and JAVA-02 macOS.
- Tracer gate: Task 1's `<verify>` was re-run and passed before Task 2 started.
- Mutation check (Task 2 RED substitute). The JAVA-03/JAVA-02 macOS checks already passed after Task 1, because Task 1 rewrote `install_jdk`. To show they are not vacuous, I ran two scratch copies of the scripts: one with the `jdk_home` equality removed from `write_profile`, one with the `jdk_usable` reuse removed from `install_jdk`. Each made JAVA-03 macOS FAIL.
- A real-brew dry run on this Mac with no `JAVA_HOME` printed one block with `export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"`. With a stub user JDK 21 in `JAVA_HOME`, it logged "Using JDK at ...", planned `brew install openjdk@21` before `brew install ghidra`, and wrote no `JAVA_HOME` line.
- All acceptance criteria for both tasks pass. The step 4 awk order check prints "order ok".

## Decisions Made

See key-decisions in the frontmatter.

## Deviations from Plan

None. The plan was executed as written.

**Note:** Task 2 has `tdd="true"`, but its tests could not fail first: the behaviour they check was delivered by Task 1's planned `install_jdk` rewrite. RED was shown with the mutation check above instead. Following the plan, tests and implementation went into one commit.

## Known Limitations (for Phase 3 DOCS-01)

- **Rerun from a shell that never sourced the block (plan-checker advisory).** JAVA-04 holds for a rerun from a new terminal that sourced the profile. A rerun from a shell with no `JAVA_HOME` (Ghidra already on PATH, Android off) does not call `install_jdk`, so the rewritten block drops `JAVA_HOME`. Homebrew's `ghidraRun` still falls back to `openjdk@21`. This belongs in the README Known limitations.
- **Ghidra and openjdk@21.** Homebrew's `ghidra` formula depends on `openjdk@21`. With Ghidra being installed, the script installs and records `openjdk@21` even when a user JDK 21+ is reused, so ROADMAP success criterion 1 ("installs no JDK") holds on macOS only with `--no-ghidra` or when Ghidra is already present. The README should say this.
- **User JAVA_HOME equal to the script's path.** If the user already set `JAVA_HOME` to exactly the `openjdk@21` opt path, the block gets an identical `export JAVA_HOME=` line. Uninstall removes only the block line; the user's own line stays.
- **Duplicate install line in dry run.** When `openjdk@21` is not installed, a dry run with `--with-android` prints `brew install openjdk@21` twice (step 4 and step 5). In a real run the second call logs "already installed (left as-is)". RESEARCH accepted this as idempotent; it is cosmetic.

## Deferred Follow-ups (not implemented)

- **macOS `GHIDRA_INSTALL_DIR`.** REA does not find Homebrew's Ghidra without it, because Homebrew keeps the tree in `libexec`. Candidate fix: export and queue `GHIDRA_INSTALL_DIR="$(brew --prefix ghidra)/libexec"`. This is its own follow-up, not this phase.
- README line 163 should say "a JDK 21+ in `JAVA_HOME`" (Phase 3 DOCS-01). Homebrew Ghidra is a formula, not a cask.

## Issues Encountered

None.

## Known Stubs

None.

## Next Phase Readiness

Ready for 02-03 (Windows JDK handling).

## Self-Check: PASSED

- FOUND: rea-install-macos.sh, test.sh
- FOUND: 2d5d75d, cdf0f7e (ancestors of HEAD)
