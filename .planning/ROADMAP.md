# Roadmap: rea-installer

## Overview

This milestone hardens the three existing installer scripts so they never leave a machine silently broken. First, a repeatable `test.sh` and CI go in alongside the failure-handling fixes. The regression checks are written red against the current scripts, then turned green by making extraction and package-install failures stop loudly, making Linux dry runs truly side-effect-free, and letting uninstall finish even when the `rea` CLI is broken. Second, all three platforms adopt one Java rule ("reuse JDK 21 or newer, else install our own") and keep `JAVA_HOME` across reruns. Last, the macOS script runs unattended under `--yes` or without a terminal, and the README is brought in line with everything that changed. macOS and Windows fixes are verified by code analysis, dry runs and lint, not by real-machine runs (deferred to v2 VERI-01/02).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Loud Failures, Safe Dry Run, and Regression Tests** - Failed extracts/package installs stop loudly, dry runs change nothing, uninstall survives a broken `rea`, all guarded by `test.sh` in CI (completed 2026-10-14)
- [ ] **Phase 2: Consistent Java Handling** - Reuse an existing JDK 21+ `JAVA_HOME` on Linux, macOS and Windows, otherwise install and record our own, and keep it across reruns
- [ ] **Phase 3: macOS Unattended Install and README Sync** - macOS install works without a terminal and under `--yes`; README Status/Testing/Known limitations match the milestone

## Phase Details

### Phase 1: Loud Failures, Safe Dry Run, and Regression Tests

**Goal**: A failed install step stops with an error and leaves nothing half-done, a dry run changes nothing, uninstall finishes even with a broken `rea` CLI, and a `test.sh` run locally and in CI proves it
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: FAIL-01, FAIL-02, FAIL-03, DRY-01, DRY-02, UNIN-01, TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06
**Success Criteria** (what must be TRUE):
  1. Maintainer runs `./test.sh` locally and it passes: `shellcheck` and `bash -n` on both bash scripts, a PowerShell parse of the Windows script, a profile-block add-then-remove that leaves a sample profile byte-identical, and the `node_supported` table (22.18 no, 22.19 yes, 24.14 no, 24.15 yes, 26.0 yes); GitHub Actions runs the same `test.sh` on every push and pull request
  2. `./rea-install-linux.sh install --dry-run --with-android` in a fresh `ubuntu:24.04` container with no Node.js exits 0 with a printed plan, and Linux `install --dry-run` / `uninstall --dry-run` leave `~/.rea-installer/node` and an empty `~/.agents/skills` in place
  3. A forced archive-extraction failure (Linux `unpack`, Windows `Expand-PinnedArchive`) exits non-zero, leaves no partial tool folder, and a rerun extracts again; a failed Linux package install stops with the "X is required" error and writes no `pkg:X` ledger entry; a failed macOS `brew install` is reported and the formula is not recorded
  4. `test.sh` contains checks for the FAIL-01, FAIL-02 and DRY-01 behaviors that were run and seen failing against the unfixed scripts, and pass after the fixes
  5. With a `rea` CLI that exits non-zero, `uninstall` on Linux, macOS and Windows prints a warning and still removes every other recorded item (packages, profile block or user variables, `~/.rea-installer`)

**Plans**: 5/5 plans complete
Plans:
**Wave 1**
- [x] 01-01-PLAN.md — Walking skeleton: source guard, `test.sh` (static, profile, `node_supported` checks) and GitHub Actions workflow

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 01-02-PLAN.md — Red regression checks (FAIL-01/02/03, DRY-01/02, UNIN-01 on three platforms) and committed `01-RED.log`

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 01-03-PLAN.md — Linux fixes: staging `unpack`, loud `pkg_install`, side-effect-free dry runs, uninstall survives broken `rea`
- [x] 01-04-PLAN.md — macOS and Windows fixes: reported `brew_install` failure, staging `Expand-PinnedArchive`, uninstall survives broken `rea`

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 01-05-PLAN.md — Phase gate: full `test.sh` green on Mac (both bash versions) and in `ubuntu:24.04`, and CI green on both runners

**Notes**: Shared root cause for FAIL-01/02 is bash turning `set -e` off inside `$(...)` and inside functions called on the left of `||`/`&&` or in `if` (verified on bash 3.2.57). Write the TEST-04/TEST-05 checks first and capture them failing before applying the fixes. Fixes must stay Bash 3.2 compatible in the macOS script and PowerShell 5.1/7 compatible on Windows; each script stays a single standalone file.

### Phase 2: Consistent Java Handling

**Goal**: Linux, macOS and Windows all follow one rule (reuse an existing `JAVA_HOME` only if it is JDK 21 or newer, otherwise install and record the script's own JDK) and the script's own `JAVA_HOME` survives reruns
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: JAVA-01, JAVA-02, JAVA-03, JAVA-04
**Success Criteria** (what must be TRUE):
  1. With `JAVA_HOME` pointing at a JDK 17, `install` on Linux, macOS or Windows installs its own JDK 21 instead of trusting it; with `JAVA_HOME` pointing at JDK 21 or newer, it reuses the existing one and installs no JDK
  2. On macOS, with `JAVA_HOME` already set to a JDK 21+, `install` writes no `JAVA_HOME` line into the shell profile block
  3. On macOS, two `install --with-extras` (or `--with-android`) runs in a row leave exactly one profile block that still exports `JAVA_HOME` pointing at the script's `openjdk@21`
  4. On Windows, after Temurin is installed, `JAVA_HOME` is set for the session to the Temurin 21 folder (derived from the `java` now on PATH) and saved as a user variable that `uninstall` removes, whether or not the MSI set it; confirmed by code review and the `test.sh` PowerShell parse, with real-Windows confirmation deferred to VERI-02

**Plans**: 5/5 plans executed
Plans:
**Wave 1**
- [x] 02-01-PLAN.md — Linux tracer: `jdk_usable` (both bash scripts), Linux `install_jdk` reuses only JDK 21+, predicate table and single-JDK dry-run checks

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 02-02-PLAN.md — macOS: `jdk_home`, reworked `install_jdk`, `write_profile` keeps our `JAVA_HOME` across reruns and never writes a user's; Ghidra's `openjdk@21` recorded

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 02-03-PLAN.md — Windows: `Test-JdkUsable`, `Install-Jdk` derives `JAVA_HOME` from the installed Temurin and saves it as a recorded user variable; pwsh driver checks

**Gap closure** *(from 02-VERIFICATION.md and 02-REVIEW.md)*
- [x] 02-04-PLAN.md — Wave 1: macOS rerun restores its own `JAVA_HOME` from the ledger or old block (SC3, WR-08); `jdk_home` fails loudly (WR-07); Linux replaces a broken `~/.rea-installer/jdk` (WR-09)
- [x] 02-05-PLAN.md — Wave 2: Windows repairs a stale `JAVA_HOME` it owns (CR-01), dry run leaves the session alone (WR-03), winget-ledger assertion can fail (WR-10); record all review dispositions

**Notes**: HARD-04 rests on an unverified assumption about the Temurin MSI's `FeatureJavaHome` default; the fix must work either way. Audit open question worth checking here: whether REA finds Ghidra on macOS without `GHIDRA_INSTALL_DIR` (Homebrew cask install; script never sets it). The macOS JDK decision line (`[ -n "$JAVA_HOME" ] || install_jdk`) is touched by both FAIL-03 (Phase 1) and this phase.

### Phase 3: macOS Unattended Install and README Sync

**Goal**: The macOS installer completes unattended (no terminal, or `--yes` on a Mac without Homebrew), and the README's Status, Testing and Known limitations sections accurately describe every fix, the new test harness and CI
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: MAC-01, MAC-02, DOCS-01
**Success Criteria** (what must be TRUE):
  1. macOS `install` run without a terminal (CI, non-tty ssh) prints a warning telling the user to run `rea setup` manually instead of failing
  2. macOS `install --yes` on a Mac without Homebrew runs the Homebrew installer non-interactively and never waits for Return
  3. README Status, Testing and Known limitations sections list each fix from this milestone, describe `./test.sh` and the GitHub Actions run, and still state that macOS and Windows are verified by dry run and lint only (real-machine runs pending)

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Loud Failures, Safe Dry Run, and Regression Tests | 5/5 | Complete    | 2026-10-14 |
| 2. Consistent Java Handling | 5/5 | In Progress | - |
| 3. macOS Unattended Install and README Sync | 0/TBD | Not started | - |
