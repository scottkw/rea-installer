---
phase: 01
review: 01-REVIEW.md
titles: json
findings:
  - id: WR-01
    severity: warning
    disposition: deferred
    title: "`unpack` hides archive-layout mismatches by moving the whole staging folder"
  - id: WR-02
    severity: warning
    disposition: deferred
    title: "Rizin and Wakaru now trust a partial folder left by an earlier failed run"
  - id: WR-03
    severity: warning
    disposition: open
    title: "DRY-01/DRY-02 compare file names only, so a dry run that edits a file still passes"
  - id: WR-04
    severity: warning
    disposition: open
    title: "`pkg_install` still swallows a failing `pkg_list`, which can corrupt the ledger"
  - id: WR-05
    severity: warning
    disposition: deferred
    title: "A failed package or brew install records nothing, leaving partial changes uninstall cannot remove"
  - id: WR-06
    severity: warning
    disposition: open
    title: "The PowerShell parse check uses the pwsh 7 parser, so 5.1-incompatible syntax passes CI"
  - id: WR-07
    severity: warning
    disposition: open
    title: "macOS install, including `--dry-run`, dies at the final step without a terminal"
  - id: IN-01
    severity: info
    disposition: open
    title: "The dry-run plan differs from what a real run would do"
  - id: IN-02
    severity: info
    disposition: open
    title: "CI action pinned by a mutable tag, and the jobs have no timeout"
  - id: IN-03
    severity: info
    disposition: open
    title: "Regression gaps in the new checks"
  - id: IN-04
    severity: info
    disposition: open
    title: "Uninstall removes `~/.agents` without a ledger entry"
open: 8
total: 11
recorded: 2026-10-14T16:59:33.309Z
---

# Phase 01: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| WR-01 | warning | deferred | accepted as known limitation in UAT test 2 (2026-10-14) |
| WR-02 | warning | deferred | accepted as known limitation in UAT test 2 (2026-10-14) |
| WR-03 | warning | open | - |
| WR-04 | warning | open | - |
| WR-05 | warning | deferred | accepted as known limitation in UAT test 2 (2026-10-14) |
| WR-06 | warning | open | - |
| WR-07 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
