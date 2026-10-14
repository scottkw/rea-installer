---
phase: 02
review: 02-REVIEW.md
titles: json
findings:
  - id: CR-01
    severity: critical
    disposition: fixed
    title: "Windows persists a version-specific Temurin path that a rerun can never repair"
  - id: WR-01
    severity: warning
    disposition: deferred
    title: "Windows takes the first `java` on PATH as Temurin and throws when it is anything else"
  - id: WR-02
    severity: warning
    disposition: deferred
    title: "`Install-Jdk` now always replaces the session PATH"
  - id: WR-03
    severity: warning
    disposition: fixed
    title: "A Windows dry run overwrites the caller's `JAVA_HOME` with a placeholder"
  - id: WR-04
    severity: warning
    disposition: deferred
    title: "A user-scope `JAVA_HOME` older than 21 stays persistent on Windows, unlike on Linux and macOS"
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
  - id: IN-01
    severity: info
    disposition: deferred
    title: "The macOS dry run lists `brew install openjdk@21` twice"
  - id: IN-02
    severity: info
    disposition: deferred
    title: "A reused JDK logs \"Using JDK at ...\" twice"
  - id: IN-03
    severity: info
    disposition: deferred
    title: "macOS writes the user's own `JAVA_HOME` when it matches Homebrew's path"
  - id: IN-04
    severity: info
    disposition: deferred
    title: "The Windows warning says it will install a JDK when Temurin is already installed"
  - id: IN-05
    severity: info
    disposition: deferred
    title: "The Windows Apktool launcher ignores the JDK the script chose"
  - id: IN-06
    severity: info
    disposition: deferred
    title: "Gaps in test coverage"
open: 0
total: 17
recorded: 2026-10-14T19:50:10.780Z
---

# Phase 02: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| CR-01 | critical | fixed | fixed in 02-05 (bccc843) |
| WR-01 | warning | deferred | accepted 2026-10-14: Temurin's bin is expected first on the refreshed PATH and the script stops naming the folder otherwise; real-Windows check is VERI-02. |
| WR-02 | warning | deferred | accepted 2026-10-14: the PATH refresh runs only when no JDK 21 JAVA_HOME is usable; session-only Node setups are rare; revisit with VERI-02. |
| WR-03 | warning | fixed | fixed in 02-05 (e0e8d34) |
| WR-04 | warning | deferred | accepted 2026-10-14: D-05 keeps a user-set Windows JAVA_HOME while the session and rea setup use JDK 21; candidate for README known limitations. |
| WR-05 | warning | deferred | accepted 2026-10-14: the ledger stores only the variable name; a JAVA_HOME repointed by the user after install is removed by uninstall; known limitation. |
| WR-06 | warning | deferred | accepted 2026-10-14: locked D-01 checks java -version only, so a JRE 21 JAVA_HOME is reused; known limitation. |
| WR-07 | warning | fixed | fixed in 02-04 (f61a0b8) |
| WR-08 | warning | fixed | fixed in 02-04 (4289e42) |
| WR-09 | warning | fixed | fixed in 02-04 (a1f62a6) |
| WR-10 | warning | fixed | fixed in 02-05 (e0e8d34) |
| IN-01 | info | deferred | accepted 2026-10-14: cosmetic duplicate brew install line in the macOS dry-run plan. |
| IN-02 | info | deferred | accepted 2026-10-14: cosmetic duplicate Using JDK log line. |
| IN-03 | info | deferred | accepted 2026-10-14: a user JAVA_HOME equal to Homebrew's openjdk@21 path is written with the same value; harmless. |
| IN-04 | info | deferred | accepted 2026-10-14: warning wording only. |
| IN-05 | info | deferred | accepted 2026-10-14: pre-existing Apktool launcher behavior outside this phase's JAVA_HOME rule. |
| IN-06 | info | deferred | accepted 2026-10-14: WR-08 and self-check failure paths are now covered by 02-04 checks; the JRE row is not added because WR-06 is accepted. |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
