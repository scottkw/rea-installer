---
phase: 02-consistent-java-handling
plan: 04
subsystem: installer
tags: [bash, jdk, java_home, macos, linux, homebrew, temurin, profile, test.sh, gap-closure]

requires:
  - phase: 02-consistent-java-handling
    provides: "jdk_usable, macOS jdk_home/install_jdk/write_profile, Linux install_jdk (plans 02-01, 02-02)"
provides:
  - "macOS jdk_owned OURS: true when the ledger has brew:openjdk@21 or the profile has export JAVA_HOME=\"OURS\""
  - "macOS install_ghidra (former inline step 4); its Ghidra-already-available branch calls install_jdk when jdk_owned"
  - "macOS jdk_home dies on a failing brew --prefix; a dry run without brew plans Homebrew's default prefix with a warning"
  - "Linux install_jdk replaces an unusable ~/.rea-installer/jdk on rerun and refuses an extracted archive without bin/java"
  - "Seven new test.sh checks plus a reworked JAVA-04 rerun check that runs with JAVA_HOME unset"
affects: [02-05 review disposition (WR-07, WR-08, WR-09 fixed), 02 re-verification, 03 DOCS-01]

actuals:
  tokens: 3488
  tasks: 3
  commits: 3
plan_head_before: f9892af8de7675719a3d8734ed63cf867598f20c
plan_head_after: a1f62a6e3cd88d04954346a0efd55594b32c830b

tech-stack:
  added: []
  patterns:
    - "Ownership from the ledger or the script's own profile line, never from the caller's environment"
    - "Functions captured with $(...) are assigned in a plain statement, so a die inside them stops the run under set -e"
    - "Stubs that sit at the end of a pipe drain stdin, so the writer never dies of SIGPIPE under pipefail"

key-files:
  created: []
  modified:
    - rea-install-macos.sh
    - rea-install-linux.sh
    - test.sh

key-decisions:
  - "macOS rerun restores the script's JAVA_HOME when jdk_owned (ledger brew:openjdk@21 or the block's own export line); install_jdk still reuses a usable user JDK and never writes it (JAVA-03)"
  - "macOS jdk_home calls brew only when brew is on PATH, so brew's own error stays visible on a real failure and a dry run without brew prints no 'command not found'"
  - "Linux install_jdk refuses an empty Adoptium release name, because the new bin/java cleanup would otherwise target TOOLS_DIR itself"

patterns-established:
  - "install_<tool> extraction lets test.sh drive the real step code without do_install (the real brew would come first on PATH)"

requirements-completed: [JAVA-02, JAVA-03, JAVA-04]

coverage:
  - id: D1
    description: "macOS rerun with JAVA_HOME unset keeps the script's openjdk@21 JAVA_HOME in the single profile block (WR-08, SC3)"
    requirement: JAVA-04
    verification:
      - kind: unit
        ref: "test.sh#JAVA-04 macOS rerun keeps one profile block exporting its own JAVA_HOME"
        status: pass
      - kind: unit
        ref: "test.sh#JAVA-04 macOS rerun with JAVA_HOME unset restores its own JAVA_HOME from the ledger"
        status: pass
    human_judgment: false
  - id: D2
    description: "macOS rerun that owns openjdk@21 still reuses a usable user JDK 21 and writes no JAVA_HOME line"
    requirement: JAVA-03
    verification:
      - kind: unit
        ref: "test.sh#JAVA-03 macOS rerun reuses a JDK 21 JAVA_HOME even when it owns openjdk@21"
        status: pass
    human_judgment: false
  - id: D3
    description: "macOS jdk_home stops a real run when brew --prefix fails; a dry run without brew plans the default prefix (WR-07)"
    requirement: JAVA-02
    verification:
      - kind: unit
        ref: "test.sh#JAVA-02 macOS install_jdk stops when brew cannot locate openjdk@21"
        status: pass
      - kind: unit
        ref: "test.sh#JAVA-02 macOS dry run without brew plans the default Homebrew JDK path"
        status: pass
    human_judgment: false
  - id: D4
    description: "Linux rerun replaces a broken ~/.rea-installer/jdk, dry run only plans it, and an archive without bin/java never becomes the trusted JDK (WR-09)"
    requirement: JAVA-02
    verification:
      - kind: unit
        ref: "test.sh#JAVA-02 Linux install_jdk plans to replace a broken ~/.rea-installer/jdk"
        status: pass
      - kind: unit
        ref: "test.sh#JAVA-02 Linux install_jdk replaces a broken ~/.rea-installer/jdk on rerun"
        status: pass
      - kind: unit
        ref: "test.sh#JAVA-02 Linux install_jdk stops on a Temurin archive without bin/java"
        status: pass
      - kind: integration
        ref: "docker run ubuntu:24.04 bash ./test.sh (phase gate)"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-10-14
status: complete
---

# Phase 2 Plan 04: Rerun JDK gap closure (WR-07, WR-08, WR-09) Summary

**macOS reruns now restore the script's openjdk@21 JAVA_HOME from the ledger or the old profile block instead of the caller's shell, macOS jdk_home stops loudly when brew cannot locate openjdk@21, and Linux reruns replace a broken ~/.rea-installer/jdk instead of dying every time.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-10-14T21:04Z
- **Completed:** 2026-10-14T21:11Z
- **Tasks:** 3 (1 tracer, 2 auto, all TDD)
- **Files modified:** 3

## Accomplishments

- WR-08 / ROADMAP SC3: `jdk_owned` plus `install_ghidra` make a macOS rerun with `JAVA_HOME` unset, Ghidra on PATH and Android off keep `export JAVA_HOME="<openjdk@21 home>"` in the one profile block. The JAVA-04 check no longer supplies its own `JAVA_HOME`.
- JAVA-03 still holds on rerun: a usable user JDK 21 is reused and not written, even when the ledger owns openjdk@21.
- WR-07: `jdk_home` dies with `could not locate Homebrew's openjdk@21 (brew --prefix failed).`. All three callers assign it in a plain statement. A dry run without brew warns and plans `/opt/homebrew` (arm64) or `/usr/local` (Intel).
- WR-09: Linux `install_jdk` warns `the JDK at <dir> does not run; downloading it again.`, removes only `$STATE_DIR/jdk` through `run`, and downloads again. An extracted folder without `bin/java` is removed, and the run stops before the move. The user JDK 17 file is byte-identical afterwards.

## Task Commits

1. **Task 1 (tracer): restore the macOS JAVA_HOME on rerun from what the script installed** - `4289e42`
2. **Task 2: stop the macOS installer when brew cannot locate openjdk@21** - `f61a0b8`
3. **Task 3: replace a broken Linux JDK on rerun instead of stopping every time** - `a1f62a6`

Commit messages follow the project convention in `.claude/CLAUDE.md` (short imperative sentence, no prefix), which takes precedence over the GSD `type(phase-plan):` form.

## Red evidence

Seen before each fix, with the new tests in place and the production fix not yet applied.

Task 1, `/bin/bash ./test.sh` after the `install_ghidra` refactor and before `jdk_owned`:

```
FAIL: JAVA-04 macOS rerun keeps one profile block exporting its own JAVA_HOME
FAIL: JAVA-04 macOS rerun with JAVA_HOME unset restores its own JAVA_HOME from the ledger
FAIL: JAVA-03 macOS rerun reuses a JDK 21 JAVA_HOME even when it owns openjdk@21
```

The first one's output showed the WR-08 bug itself. The rewritten block held only `export REA_TEST=1`, with no `JAVA_HOME`.

Task 2, `/bin/bash ./test.sh` before the `jdk_home` rework:

```
FAIL: JAVA-02 macOS install_jdk stops when brew cannot locate openjdk@21
FAIL: JAVA-02 macOS dry run without brew plans the default Homebrew JDK path
```

The second one's output showed `brew: command not found` and `JAVA_HOME=/libexec/openjdk.jdk/Contents/Home`, as WR-07 describes.

Task 3, `./test.sh` before the `install_jdk` fix (stable over three runs):

```
FAIL: JAVA-02 Linux install_jdk plans to replace a broken ~/.rea-installer/jdk
FAIL: JAVA-02 Linux install_jdk replaces a broken ~/.rea-installer/jdk on rerun
FAIL: JAVA-02 Linux install_jdk stops on a Temurin archive without bin/java
```

The rerun check died with `the downloaded JDK at .../jdk does not run.`. The bad-layout check showed `mv .../tools/jdk-21.0.5+11 .../jdk` followed by the same error, so the bad layout had become the trusted JDK.

## Verification

- Task 1 verify (both automated commands): pass. Also `install_ghidra ok` from the awk order check.
- Task 2 verify: pass. `jdk_home calls that are not plain assignments: 0`.
- Task 3 verify: pass. `rm -rf lines in install_jdk on other paths: 0`.
- Phase gate: `exit: default=0 bash32=0 ubuntu=0` and no `FAIL:` line. The local runs gave 80 passed, 0 failed, 2 skipped. ubuntu:24.04 gave 54 passed, 0 failed, 10 skipped, and the JAVA-04 Darwin-only check printed SKIP there as expected. Every other new check printed PASS in ubuntu.
- Acceptance greps: all pass. Header lines 1-11 (macOS) and 1-15 (Linux) and both source guards are unchanged (the first diff hunks start at line 135 on macOS and line 340 on Linux).

## Decisions Made

See `key-decisions` in the frontmatter.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The JAVA-04 rerun check could not go red as written**
- **Found during:** Task 1, red step
- **Issue:** With the plan's sandboxes (`install_jdk; write_profile`, then `install_ghidra; write_profile`), run 2 queued no export. `write_profile` therefore skipped the rewrite and left run 1's block untouched, so the check passed before the fix. The real failure needs a rewrite, which is what `--with-extras` does in ROADMAP SC3.
- **Fix:** Both runs add `profile_exports+=("export REA_TEST=1")` before `write_profile`. The check then went red for the WR-08 reason. All the plan's assertions are kept.
- **Files modified:** test.sh
- **Commit:** 4289e42

**2. [Rule 1 - Bug] The node stub raced the curl stub into SIGPIPE**
- **Found during:** Task 3, red step
- **Issue:** The plan's node stub "ignores its stdin". Exiting unread made the `curl` stub die of SIGPIPE, and `pipefail` then stopped `install_jdk` silently with rc 141 and no output. That is a flaky test, not WR-09.
- **Fix:** The node stub runs `cat >/dev/null` before it prints. The comment in test.sh says why.
- **Files modified:** test.sh
- **Commit:** a1f62a6

**3. [Rule 2 - Missing critical] Empty Adoptium release name guard**
- **Found during:** Task 3
- **Issue:** If the metadata yielded an empty `release`, `unpack` would return `$TOOLS_DIR` itself. The new `run rm -rf "$dir"` would then delete every tool under it, which the plan's prohibition forbids. The old code had the same hole with `mv`.
- **Fix:** `[ -n "$release" ] || die "could not read the Temurin 21 release from Adoptium."` before `unpack`.
- **Files modified:** rea-install-linux.sh
- **Commit:** a1f62a6

**4. [Rule 1 - Refinement] jdk_home calls brew only when it is on PATH**
- **Found during:** Task 2
- **Issue:** Calling `brew --prefix` with no brew prints `brew: command not found` on a dry run, which is the noise WR-07 reported. Hiding stderr would hide brew's real error on a failing real run.
- **Fix:** A `have_brew` check. brew's stderr stays visible when brew exists. The dry-run fallback is used only when brew is absent.
- **Files modified:** rea-install-macos.sh
- **Commit:** f61a0b8

**Total deviations:** 4 auto-fixed (3 Rule 1, 1 Rule 2). **Impact:** Two test fixes made the checks able to fail for the intended reason. One safety guard and one stderr refinement add no new behavior beyond the plan.

## Issues Encountered

- A hand reproduction under zsh (the tool shell) used zsh's hashed real `node` and gave misleading output. It was redone under `/bin/bash`, which is what showed the SIGPIPE cause.

## Known limitations (unchanged, noted for DOCS-01)

- The WR-07 dry-run warning can print more than once per run, because `jdk_home` runs in a subshell. This only happens on a dry run on a Mac without Homebrew.
- If Adoptium's archive layout really nests `bin/java` (Phase 1 WR-01), every rerun now stops with `has no bin/java ... rerun to download it again.` and downloads again. It stops loudly and never trusts a bad layout, but it does not fix the layout.

## Next Phase Readiness

Ready for 02-05: set WR-07, WR-08 and WR-09 to `fixed` in 02-REVIEW-DISPOSITION.md, then re-verify the phase.

## Self-Check: PASSED

- FOUND: rea-install-macos.sh, rea-install-linux.sh, test.sh
- FOUND: 4289e42, f61a0b8, a1f62a6 (ancestors of HEAD)
- Commits measured: `git rev-list --count f9892af..HEAD` = 3
