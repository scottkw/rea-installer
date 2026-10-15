---
phase: 03
review: 03-REVIEW.md
titles: json
findings:
  - id: CR-01
    severity: critical
    disposition: fixed
    title: "A Homebrew installed by the script is never added to PATH, so the final `rea doctor` fails in a new terminal on Apple silicon"
  - id: WR-01
    severity: warning
    disposition: fixed
    title: "`sudo -v` keeps a cached root credential live after Homebrew's installer exits, while unpinned third-party code runs"
  - id: WR-02
    severity: warning
    disposition: deferred
    title: "A Homebrew install that fails partway is orphaned, and a rerun adopts it as the user's"
  - id: WR-03
    severity: warning
    disposition: deferred
    title: "Items kept because there was no terminal are lost from the ledger, because uninstall deletes `~/.rea-installer` anyway"
  - id: WR-04
    severity: warning
    disposition: deferred
    title: "Piped into bash, Homebrew's installer inherits the script's stdin and is forced non-interactive, even with a terminal and without `--yes`"
  - id: WR-05
    severity: warning
    disposition: deferred
    title: "The failure hint blames sudo for every Homebrew failure, and an inherited `INTERACTIVE` makes the `--yes` path abort"
  - id: WR-06
    severity: warning
    disposition: deferred
    title: "A dry run now downloads Homebrew's installer and dies offline, and prints the whole installer as the plan"
  - id: WR-07
    severity: warning
    disposition: deferred
    title: "The Homebrew uninstall step does not stop when its download fails, and `--yes` does not get past Homebrew's own prompt"
  - id: WR-08
    severity: warning
    disposition: fixed
    title: "macOS uninstall exits with no message when the recorded npm cannot run, contradicting the README"
  - id: IN-01
    severity: info
    disposition: deferred
    title: "Gaps in the new tests"
  - id: IN-02
    severity: info
    disposition: deferred
    title: "`confirm` exits under `set -u` if a future caller leaves out ITEM"
  - id: IN-03
    severity: info
    disposition: fixed
    title: "The README says installing Ghidra always \"installs and records\" `openjdk@21`"
open: 0
total: 12
recorded: 2026-10-15T13:59:02.267Z
---

# Phase 03: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| CR-01 | critical | fixed | fixed 2026-10-15: quick 261015-d2b (714dc7d) adds brew shellenv to the profile block when the script installed Homebrew; test.sh checks |
| WR-01 | warning | fixed | fixed 2026-10-15: quick 261015-d2b (a79425e) runs sudo -k after the installer when sudo -v cached a ticket; test.sh checks |
| WR-02 | warning | deferred | accepted 2026-10-15: lean Phase 3 close by user decision; not fixed this milestone, revisit with VERI-01 real-Mac run |
| WR-03 | warning | deferred | accepted 2026-10-15: lean Phase 3 close by user decision; not fixed this milestone, revisit with VERI-01 real-Mac run |
| WR-04 | warning | deferred | accepted 2026-10-15: lean Phase 3 close by user decision; not fixed this milestone, revisit with VERI-01 real-Mac run |
| WR-05 | warning | deferred | accepted 2026-10-15: lean Phase 3 close by user decision; not fixed this milestone, revisit with VERI-01 real-Mac run |
| WR-06 | warning | deferred | accepted 2026-10-15: lean Phase 3 close by user decision; not fixed this milestone, revisit with VERI-01 real-Mac run |
| WR-07 | warning | deferred | accepted 2026-10-15: lean Phase 3 close by user decision; not fixed this milestone, revisit with VERI-01 real-Mac run |
| WR-08 | warning | fixed | fixed 2026-10-15: quick 261015-d2b (c013784) README now says macOS uninstall stops when the recorded npm cannot run; code unchanged |
| IN-01 | info | deferred | accepted 2026-10-15: lean Phase 3 close by user decision; not fixed this milestone, revisit with VERI-01 real-Mac run |
| IN-02 | info | deferred | accepted 2026-10-15: lean Phase 3 close by user decision; not fixed this milestone, revisit with VERI-01 real-Mac run |
| IN-03 | info | fixed | fixed 2026-10-15: quick 261015-d2b (c013784) README says openjdk@21 is installed and recorded only if not already present |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
