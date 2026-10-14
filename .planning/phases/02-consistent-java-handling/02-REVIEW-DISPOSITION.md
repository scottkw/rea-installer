---
phase: 02
review: 02-REVIEW.md
titles: json
findings:
  - id: WR-01
    severity: warning
    disposition: open
    title: "The CR-01 fix overwrites a `JAVA_HOME` the user chose, and says the script set it"
  - id: WR-02
    severity: warning
    disposition: open
    title: "A Windows dry run still replaces the caller's session `Path`"
  - id: WR-03
    severity: warning
    disposition: open
    title: "On a macOS `--no-ghidra` rerun, the profile's `JAVA_HOME` still depends on the caller's environment"
  - id: WR-04
    severity: warning
    disposition: open
    title: "The Linux layout-mismatch error says \"rerun\", but a rerun downloads and fails the same way"
  - id: IN-01
    severity: info
    disposition: open
    title: "The WR-07 dry-run fallback is unreachable on most Macs without Homebrew"
  - id: IN-02
    severity: info
    disposition: open
    title: "The dry-run fallback warning prints once per `jdk_home` call"
  - id: IN-03
    severity: info
    disposition: open
    title: "`install_ghidra` now requires `brew --prefix openjdk@21` even when Ghidra is already present and no JDK is owned"
  - id: IN-04
    severity: info
    disposition: open
    title: "An environmental `java -version` failure makes every Linux rerun delete and download the JDK again"
  - id: IN-05
    severity: info
    disposition: open
    title: "Gaps in test coverage for the new branches"
  - id: CR-01
    severity: critical
    disposition: fixed
    title: "Windows persists a version-specific Temurin path that a rerun can never repair"
  - id: WR-05
    severity: warning
    disposition: deferred
    title: "Windows uninstall deletes the user's `JAVA_HOME` even if the user changed it after install"
  - id: WR-06
    severity: warning
    disposition: deferred
    title: "The JDK check accepts a JRE, which REA rejects"
  - id: WR-07
    severity: warning
    disposition: fixed
    title: "macOS `jdk_home` turns a missing `brew` into a wrong path without failing"
  - id: WR-08
    severity: warning
    disposition: fixed
    title: "On a macOS rerun, the profile's `JAVA_HOME` depends on the caller's environment, not on what was installed"
  - id: WR-09
    severity: warning
    disposition: fixed
    title: "A broken `~/.rea-installer/jdk` on Linux makes every rerun die"
  - id: WR-10
    severity: warning
    disposition: fixed
    title: "The last Windows test cannot fail on its winget-ledger assertion"
  - id: IN-06
    severity: info
    disposition: deferred
    title: "Gaps in test coverage"
open: 9
total: 17
recorded: 2026-10-14T21:29:35.701Z
---

# Phase 02: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| WR-01 | warning | open | - |
| WR-02 | warning | open | - |
| WR-03 | warning | open | - |
| WR-04 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |
| IN-05 | info | open | - |
| CR-01 | critical | fixed | fixed in 02-05 (bccc843) (not in the current review) |
| WR-05 | warning | deferred | accepted 2026-10-14: the ledger stores only the variable name; a JAVA_HOME repointed by the user after install is removed by uninstall; known limitation. (not in the current review) |
| WR-06 | warning | deferred | accepted 2026-10-14: locked D-01 checks java -version only, so a JRE 21 JAVA_HOME is reused; known limitation. (not in the current review) |
| WR-07 | warning | fixed | fixed in 02-04 (f61a0b8) (not in the current review) |
| WR-08 | warning | fixed | fixed in 02-04 (4289e42) (not in the current review) |
| WR-09 | warning | fixed | fixed in 02-04 (a1f62a6) (not in the current review) |
| WR-10 | warning | fixed | fixed in 02-05 (e0e8d34) (not in the current review) |
| IN-06 | info | deferred | accepted 2026-10-14: WR-08 and self-check failure paths are now covered by 02-04 checks; the JRE row is not added because WR-06 is accepted. (not in the current review) |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
