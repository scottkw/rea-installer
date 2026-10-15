# Phase 3: macOS Unattended Install and README Sync - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md. This log preserves the alternatives considered.

**Date:** 2026-10-14
**Phase:** 03-macos-unattended-install-and-readme-sync
**Areas discussed:** No-terminal behavior, Homebrew + sudo under --yes, README shape, How MAC-01/02 are tested

---

## No-terminal behavior

| Question | Options | Selected |
|---|---|---|
| Step 9 with no tty and no --yes | Warn and skip (Linux parity) / Fall back to --yes --all-detected | Warn and skip |
| confirm() with no tty | No-tty = No with a warning / Leave it (deferred) | No-tty = No with a warning |
| Linux confirm() parity | Both bash scripts / macOS only | Both bash scripts |
| Xcode CLT dialog on a headless Mac | README limitation only / softwareupdate -i under --yes | README limitation only |

## Homebrew + sudo under --yes

| Question | Options | Selected |
|---|---|---|
| sudo for NONINTERACTIVE Homebrew | sudo -v first if a tty exists / Just NONINTERACTIVE=1 | sudo -v first if a tty exists |
| When to set NONINTERACTIVE=1 | Only under --yes / --yes or no tty | Only under --yes |
| Homebrew failure message | Add a sudo hint / Keep current messages | Add a sudo hint |

## README shape

| Question | Options | Selected |
|---|---|---|
| Where fixes are listed | Folded into existing sections / New changelog / Both | Folded into existing sections |
| Testing section | New subsection plus table updates / Table rows only | New subsection plus table updates |
| Known limitations to add (multi) | WR-01/02/05; Windows stale JAVA_HOME; macOS unattended prereqs; Dry run without npm | All four |
| Status rows | Keep "Dry runs only", add test.sh / Rewrite with more detail | Keep "Dry runs only", add test.sh |

## How MAC-01/02 are tested

| Question | Options | Selected |
|---|---|---|
| Reaching no-tty branches | Tty path variable seam / setsid in Linux container / Code review only | Tty path variable seam |
| MAC-02 check | Dry-run output check / Stubbed curl real run / Code review only | Dry-run output check |

## Claude's Discretion

- Seam variable name and form (prefer internal, not a documented env var)
- Warning/die wording
- Whether the tty probe becomes a helper within each script
- README prose and placement

## Deferred Ideas

- Headless CLT install via softwareupdate
- Ghidra discovery on macOS without GHIDRA_INSTALL_DIR (open for VERI-01)
- Backlog 999.1 / 999.2 unchanged
