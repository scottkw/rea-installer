---
gsd_state_version: "1.0"
current_phase: 02
current_phase_name: consistent-java-handling
status: executing
stopped_at: Completed 02-04-PLAN.md
last_updated: "2026-10-14T21:13:01.649Z"
last_activity: 2026-10-14
last_activity_desc: Phase 2 execution started
state_head: e42bdd0bb05dde48b5cd2da6ce13368758450e2c
progress:
  total_phases: 3
  completed_phases: 1
  total_plans: 10
  completed_plans: 9
  percent: 33
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-10-14)

**Core value:** Installing and uninstalling must never leave the user's machine in a silently broken or altered state: a failure stops loudly, a rerun recovers, and uninstall removes only what the script added.
**Current focus:** Phase 2 — Consistent Java Handling

## Current Position

Phase: 02 (consistent-java-handling) — READY TO EXECUTE
Plan: 3 of 3
Status: Ready to execute
Last activity: 2026-10-14 — Phase 2 execution started

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

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 2]: JAVA-01 (HARD-04) rests on an unverified assumption about the Temurin MSI; fix must work whether or not the MSI sets `JAVA_HOME`. Real-Windows confirmation is v2 VERI-02.
- [Phase 2]: Open audit question: does REA find Ghidra on macOS without `GHIDRA_INSTALL_DIR`?
- [Phase 2]: WR-01 — Linux `unpack` nests the tool one folder deep if the JDK archive's top folder name differs; `install_jdk` rework should address it.
- [Phase 3]: WR-07 — macOS `rea setup </dev/tty` dies without a terminal (MAC-01).
- [All]: No real macOS/Windows runs this milestone; verification is code analysis, dry runs, lint and Linux containers.

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-10-14T21:13:01.616Z
Stopped at: Completed 02-04-PLAN.md
Resume file: None
