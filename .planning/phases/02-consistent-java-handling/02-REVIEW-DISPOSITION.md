---
phase: 02
review: 02-REVIEW.md
titles: json
findings:
  - id: CR-01
    severity: critical
    disposition: open
    title: "Windows persists a version-specific Temurin path that a rerun can never repair"
  - id: WR-01
    severity: warning
    disposition: open
    title: "Windows takes the first `java` on PATH as Temurin and throws when it is anything else"
  - id: WR-02
    severity: warning
    disposition: open
    title: "`Install-Jdk` now always replaces the session PATH"
  - id: WR-03
    severity: warning
    disposition: open
    title: "A Windows dry run overwrites the caller's `JAVA_HOME` with a placeholder"
  - id: WR-04
    severity: warning
    disposition: open
    title: "A user-scope `JAVA_HOME` older than 21 stays persistent on Windows, unlike on Linux and macOS"
  - id: WR-05
    severity: warning
    disposition: open
    title: "Windows uninstall deletes the user's `JAVA_HOME` even if the user changed it after install"
  - id: WR-06
    severity: warning
    disposition: open
    title: "The JDK check accepts a JRE, which REA rejects"
  - id: WR-07
    severity: warning
    disposition: open
    title: "macOS `jdk_home` turns a missing `brew` into a wrong path without failing"
  - id: WR-08
    severity: warning
    disposition: open
    title: "On a macOS rerun, the profile's `JAVA_HOME` depends on the caller's environment, not on what was installed"
  - id: WR-09
    severity: warning
    disposition: open
    title: "A broken `~/.rea-installer/jdk` on Linux makes every rerun die"
  - id: WR-10
    severity: warning
    disposition: open
    title: "The last Windows test cannot fail on its winget-ledger assertion"
  - id: IN-01
    severity: info
    disposition: open
    title: "The macOS dry run lists `brew install openjdk@21` twice"
  - id: IN-02
    severity: info
    disposition: open
    title: "A reused JDK logs \"Using JDK at ...\" twice"
  - id: IN-03
    severity: info
    disposition: open
    title: "macOS writes the user's own `JAVA_HOME` when it matches Homebrew's path"
  - id: IN-04
    severity: info
    disposition: open
    title: "The Windows warning says it will install a JDK when Temurin is already installed"
  - id: IN-05
    severity: info
    disposition: open
    title: "The Windows Apktool launcher ignores the JDK the script chose"
  - id: IN-06
    severity: info
    disposition: open
    title: "Gaps in test coverage"
open: 17
total: 17
recorded: 2026-10-14T19:50:10.780Z
---

# Phase 02: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| CR-01 | critical | open | - |
| WR-01 | warning | open | - |
| WR-02 | warning | open | - |
| WR-03 | warning | open | - |
| WR-04 | warning | open | - |
| WR-05 | warning | open | - |
| WR-06 | warning | open | - |
| WR-07 | warning | open | - |
| WR-08 | warning | open | - |
| WR-09 | warning | open | - |
| WR-10 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |
| IN-05 | info | open | - |
| IN-06 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
