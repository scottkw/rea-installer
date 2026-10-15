---
gsd_state_version: "1.0"
current_phase: 02
current_phase_name: Consistent Java Handling
status: verifying
stopped_at: Completed 02-10-PLAN.md
last_updated: "2026-10-15T02:48:14.327Z"
last_activity: 2026-10-14
last_activity_desc: Phase 02 execution started
state_head: 232256cc29f45bc68119d9f66d27accf42ccd363
progress:
  total_phases: 3
  completed_phases: 1
  total_plans: 15
  completed_plans: 15
  percent: 33
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-10-14)

**Core value:** Installing and uninstalling must never leave the user's machine in a silently broken or altered state: a failure stops loudly, a rerun recovers, and uninstall removes only what the script added.
**Current focus:** Phase 02 — Consistent Java Handling

## Current Position

Phase: 02 (Consistent Java Handling) — EXECUTING
Plan: 7 of 7
Status: Phase complete — ready for verification
Last activity: 2026-10-14 - Completed quick task 261014-tvi: Fix Linux Picked-up filter and macOS dead owned JAVA_HOME on --no-ghidra rerun

Progress: [███░░░░░░░] 33%

## Performance Metrics

**Velocity:**
- Total plans completed: 5
- Average duration: -
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 5 | - | - |

**Recent Trend:**
- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 2min | 2 tasks | 4 files |
| Phase 01 P02 | 3min | 3 tasks | 2 files |
| Phase 01 P03 | 2min | 2 tasks | 1 files |
| Phase 01 P04 | 1m | 2 tasks | 2 files |
| Phase 01 P05 | 3m | 2 tasks | 0 files |
| Phase 02 P01 | 2 min | 2 tasks | 3 files |
| Phase 02 P02 | 3 min | 2 tasks | 2 files |
| Phase 02 P03 | 3 min | 2 tasks | 2 files |
| Phase 02 P04 | 7 min | 3 tasks | 3 files |
| Phase 02 P05 | 4 min | 3 tasks | 3 files |
| Phase 02 P06 | 4min | 2 tasks | 3 files |
| Phase 02 P07 | 3min | 3 tasks | 3 files |
| Phase 02 P08 | 4min | 2 tasks | 2 files |
| Phase 02 P09 | 3 min | 3 tasks | 4 files |
| Phase 02 P10 | 3 min | 2 tasks | 6 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: Test harness (TEST-01..06) shares Phase 1 with the FAIL/DRY/UNIN fixes so TEST-05's "fails before, passes after" checks are written red and turned green within one phase, and CI is never left red between phases
- [Roadmap]: macOS polish (MAC-01/02) and README sync (DOCS-01) form the final phase; DOCS-01 is verified once against all fixes
- [Phase 01]: Source guard (return 0 2>/dev/null) && return 0 sits after the main banner in both bash scripts; usage() header ranges unchanged
- [Phase 01]: test.sh need(): missing tool SKIPs locally, FAILs in CI; docker and shellcheck expected absent on Darwin
- [Phase 01]: test.sh tar stub is switched by STUB_TAR (fail = partial foo-1.0 then exit 1, else real /usr/bin/tar), shared by bash and pwsh checks
- [Phase 01]: 01-RED.log committed alone at 3aa4a0e before any installer fix; FAIL-01/02/03 and UNIN-01 checks were shown to go green on scratch-patched copies
- [Phase 01]: Linux unpack extracts into $TOOLS_DIR/.staging-<name>, renames on success, keeps the verified archive on failure; Rizin and Wakaru use it (tar -xf)
- [Phase 01]: Linux install_node/install_jdk only log the download under --dry-run; rea setup probes /dev/tty by opening it
- [Phase 01]: brew_install prints its own failure line because brew's stderr can be empty
- [Phase 01]: Windows Expand-PinnedArchive stages extracts in .staging-<Folder> and keeps the archive on failure, matching Linux
- [Phase 01]: A failed rea uninstall is a warning with the same text on macOS, Linux and Windows
- [Phase 01]: Phase 01 CI gate reads the run for the phase code HEAD (770a678); later docs-only tracking commits are outside the gate
- [Phase 01 UAT]: WR-01, WR-02, WR-05 accepted as known limitations (deferred in 01-REVIEW-DISPOSITION.md)
- [Phase 02]: jdk_usable (JDK 21+ via java -version, fail closed) shared byte-identical by both bash scripts; Linux install_jdk reuses only a JDK 21+ JAVA_HOME
- [Phase 02]: Linux post-install jdk_usable self-check dies loudly; java -version output never printed
- [Phase 02]: macOS write_profile adds JAVA_HOME to the profile block only when it equals jdk_home (the script's own openjdk@21), so a reused user JDK is never written and reruns keep ours
- [Phase 02]: macOS step 4 brew_installs openjdk@21 before ghidra when a user JDK is reused, so Homebrew's ghidra dependency is recorded and uninstall removes it
- [Phase 02]: Windows Install-Jdk derives JAVA_HOME from the first java on the refreshed PATH, checks it with Test-JdkUsable, sets the session value before Set-UserEnv, and throws (no Machine JAVA_HOME fallback) when it is not JDK 21+
- [Phase 02]: Windows stale user JAVA_HOME after a Temurin upgrade accepted as a known limitation for DOCS-01; A1/A2 deferred to VERI-02
- [Phase 02]: macOS rerun restores the script's JAVA_HOME when jdk_owned (ledger brew:openjdk@21 or the block's own export line); a usable user JDK 21+ is still reused and never written
- [Phase 02]: macOS jdk_home dies on a failing brew --prefix; a dry run without brew plans Homebrew's default prefix with a warning; every caller assigns it in a plain statement
- [Phase 02]: Linux install_jdk replaces an unusable ~/.rea-installer/jdk on rerun (through run) and refuses an extracted Temurin folder without bin/java or an empty release name
- [Phase 02]: Windows rerun replaces a user JAVA_HOME only when the ledger holds env:JAVA_HOME (CR-01); a value the script never set keeps D-05 warn-and-leave
- [Phase 02]: Windows -DryRun changes no session variable: $JdkPlanned marks the planned JDK and Set-UserEnv returns before Set-Item (WR-03, supersedes D-09 placeholder)
- [Phase 02]: Accepted review findings are stored as deferred with an 'accepted 2026-10-14:' Source cell, because the disposition gate resets other values to open
- [Phase 02]: macOS write_profile keeps the script's JAVA_HOME by ownership (ledger brew:openjdk@21 or old block export) plus the usable-user-JDK check, never by the caller's shell (G-02-1)
- [Phase 02]: Linux install_jdk moves a one-level-deeper Temurin bin/java folder into place; any other layout stops and asks for a report, not a rerun (WR-04)
- [Phase 02]: Windows replaces a user JAVA_HOME only when the ledger holds env:JAVA_HOME and the saved folder no longer exists (WR-01, D-05)
- [Phase 02]: Restored review decisions use 3-digit ids WR-101..WR-104 and IN-101..IN-105 so a re-review cannot collide with them
- [Phase 02]: macOS write_profile: outside jdk_chosen the owned JDK must run before it is written; a dead owned JDK is left out with a warning, and a set non-21 JAVA_HOME is replaced only with the D-04 warning (WR-01, WR-03)
- [Phase 02]: macOS jdk_owned counts only the script's own PROFILE_BEGIN..PROFILE_END block as ownership; a user export JAVA_HOME line is ignored (IN-01)
- [Phase 02]: Linux install_jdk error drops java -version lines starting Picked up before head -3, so proxy credentials are never printed (G-02-1)
- [Phase 02]: Windows Install-Jdk replaces a ledger-owned user JAVA_HOME when its bin\java.exe is not a file; a value holding a JDK is kept (G-02-4, WR-02)
- [Phase 02]: Review IN-02 (no-npm dry-run) deferred as accepted, backlog 999.1; Phase 2 review dispositions at open 0
- [Phase 02]: No GitHub Actions; all testing is local: /bin/bash ./test.sh on macOS (Bash 3.2) and ./test.sh in a local Linux container (G-02-6)
- [Phase 02]: Completed Phase 1 history keeps its text; the Phase 1 criterion that named GitHub Actions gets a dated note instead of a rewrite

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 2]: JAVA-01 (HARD-04) rests on an unverified assumption about the Temurin MSI; fix must work whether or not the MSI sets `JAVA_HOME`. Real-Windows confirmation is v2 VERI-02.
- [Phase 2]: Open audit question: does REA find Ghidra on macOS without `GHIDRA_INSTALL_DIR`?
- [Phase 2]: WR-01 — Linux `unpack` nests the tool one folder deep if the JDK archive's top folder name differs; `install_jdk` rework should address it.
- [Phase 3]: WR-07 — macOS `rea setup </dev/tty` dies without a terminal (MAC-01).
- [All]: No real macOS/Windows runs this milestone; verification is code analysis, dry runs, lint and Linux containers.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 261014-tvi | Fix Linux Picked-up filter and macOS dead owned JAVA_HOME on --no-ghidra rerun | 2026-10-14 | 232256c | [261014-tvi-fix-linux-picked-up-filter-and-macos-dea](./quick/261014-tvi-fix-linux-picked-up-filter-and-macos-dea/) |

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-10-15T02:13:14.318Z
Stopped at: Completed 02-10-PLAN.md
Resume file: None
