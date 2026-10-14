---
phase: 01-loud-failures-safe-dry-run-and-regression-tests
plan: 04
subsystem: installer-macos-windows
tags: [bash, powershell, macos, windows, brew, staging-extract, uninstall]
status: complete

requires:
  - phase: 01-02
    provides: "Red checks in test.sh for FAIL-03, UNIN-01 macOS, FAIL-01 Windows, UNIN-01 Windows"
provides:
  - "brew_install warns 'brew install NAME failed.' and returns 1 before recording"
  - "macOS uninstall that warns and continues when rea uninstall fails"
  - "Staging Expand-PinnedArchive in rea-install-windows.ps1 ($ToolsDir\\.staging-<Folder>, Move-Item on success, archive kept on failure)"
  - "Windows Invoke-Uninstall that warns and continues when rea uninstall fails"
affects: [01-05]

actuals:
  tokens: 805
  tasks: 2
  commits: 2
plan_head_before: 78e77a3d1cbea9f35a64fc72a95a82b049c0364d
plan_head_after: 7566617202e8ff11b7cb5a0ac860544a9394c9ff

tech-stack:
  added: []
  patterns:
    - "Windows archive extracts go to $ToolsDir\\.staging-<Folder> and are moved to the target only on success, matching Linux unpack"
    - "A failed rea uninstall is a warning on all three platforms, with the same text"

key-files:
  created: []
  modified:
    - rea-install-macos.sh
    - rea-install-windows.ps1

key-decisions:
  - "brew_install prints its own failure line because brew's stderr can be empty (for example a killed process)"
  - "Callers of brew_install are unchanged: they already stop the run through errexit"
  - "Expand-PinnedArchive under -DryRun prints the tar command and returns before creating or deleting anything"

metrics:
  duration: 1m
  completed: 2026-10-14
---

# Phase 01 Plan 04: macOS and Windows loud failures Summary

macOS `brew_install` now reports and refuses to record a failed install, Windows extracts through a staging folder that is renamed only on success, and uninstall on both platforms finishes when the `rea` CLI is broken.

## What changed

- `rea-install-macos.sh`: `run brew install "$@" || { warn "brew install $name failed."; return 1; }` comes before `record`. Uninstall step 1 now reads `run "$rea_bin" uninstall --purge-data || warn "rea uninstall failed; remove agent registrations by hand."`, the same text as Linux.
- `rea-install-windows.ps1`: `Expand-PinnedArchive` extracts into `$ToolsDir\.staging-$Folder`. It removes any leftover staging folder first. A failure removes staging, keeps the verified archive and throws `Could not unpack <archive>: <error>`. Success moves the folder into place, then removes staging and the archive. `Invoke-Uninstall` wraps the `rea uninstall --purge-data` step in try/catch and calls `Warn` on failure.

## Verification

- `./test.sh` (pwsh 7 present): exit 0. PASS for FAIL-01 Windows (both checks), UNIN-01 Windows and the pwsh parse check. Only the two Linux-only checks were skipped.
- `/bin/bash ./test.sh` (Bash 3.2): exit 0, 31 PASS, including FAIL-03, UNIN-01 macOS, bash -n, shellcheck, the pipe guard and the profile round trip for the macOS script.
- Manual pwsh check: `Expand-PinnedArchive` with `$DryRun = $true` printed `> tar -xf ... -C ...\.staging-foo-1.0` and left the tools folder unchanged.
- Acceptance greps: no `??`, ternary or `-Parallel`; no `Write-Error`; the three strict-mode lines are unchanged; the JAVA_HOME caller and the macOS header (lines 2-11) are unchanged.

## Deviations from Plan

None. The plan was executed as written.

## Known Stubs

None.

## Remaining limits

- The Windows change was tested only under pwsh 7 on macOS with a stub `tar`. Real Windows `tar.exe` and PowerShell 5.1 were not run (v2 VERI-02).
- The plan says the full phase gate, including the Ubuntu container run, belongs to plan 01-05.

## Self-Check: PASSED

- FOUND: rea-install-macos.sh, rea-install-windows.ps1
- FOUND: 0c054fc, 7566617
