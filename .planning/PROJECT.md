# rea-installer

## What This Is

Three standalone installer scripts — `rea-install-linux.sh`, `rea-install-macos.sh`, `rea-install-windows.ps1` — that install REA (Reverse Engineer Anything) and the caller-supplied tools it uses (Node.js, Ghidra, a JDK, JADX, Apktool, adb, Rizin, objdump, WABT and Linux-only capture tools) with one command per platform. Everything they add is recorded in a ledger so `uninstall` removes exactly that and leaves pre-existing tools alone. Unofficial community project for people who want REA working with their AI coding agents without reading two dozen setup pages.

## Core Value

Installing and uninstalling must never leave the user's machine in a silently broken or altered state: a failure stops loudly, a rerun recovers, and uninstall removes only what the script added.

## Requirements

### Validated

<!-- Inferred from the existing code and the README's Linux container testing. -->

- ✓ One-command `install` / `uninstall` on Linux (apt, dnf, pacman; x64 and arm64), macOS (Homebrew) and Windows (winget; x64 and ARM64) — existing
- ✓ Optional tool groups: `--no-ghidra`, `--with-android`, `--with-extras`, Linux `--with-linux-tools` — existing
- ✓ Pinned GitHub release downloads verified by SHA-256 before use — existing
- ✓ Install ledger (`~/.rea-installer/installed`) drives uninstall, reversed newest-first; pre-existing tools are left alone — existing
- ✓ Linux records the dependency set each package pulled in and removes it only when nothing else needs it — existing
- ✓ Settings persisted via a marked shell-profile block (macOS/Linux) or user environment variables (Windows) — existing
- ✓ `--dry-run` / `-DryRun` prints the plan — existing (HARD-03, HARD-12 fixed in Phase 1)
- ✓ Linux end-to-end install, reinstall and uninstall verified in Ubuntu 24.04, Fedora 44 and Arch containers — existing
- ✓ Failed archive extraction stops the install and leaves no partial folder (HARD-01) — Phase 1
- ✓ Failed package installs stop the install and are not recorded (HARD-02) — Phase 1
- ✓ Linux `--dry-run` succeeds on a fresh machine and changes nothing (HARD-03, HARD-12) — Phase 1
- ✓ Uninstall completes even when the `rea` CLI is broken (HARD-07) — Phase 1
- ✓ Repeatable `test.sh`, run locally (HARD-08) — v1; GitHub Actions removed by user decision in Phase 2
- ✓ Windows sets `JAVA_HOME` from the Temurin it installed, not from the MSI (HARD-04) — v1
- ✓ macOS respects an existing JDK 21+ `JAVA_HOME` and keeps its own across reruns (HARD-05, HARD-11) — v1
- ✓ All platforms reject an existing `JAVA_HOME` older than JDK 21 (HARD-06) — v1
- ✓ macOS installs without a terminal and under `--yes` with unattended Homebrew (HARD-09, HARD-10) — v1
- ✓ README Status / Testing / Known limitations match the shipped behaviour (DOCS-01) — v1

### Active

<!-- Next milestone not yet defined. Candidates from v1 (see milestones/v1-REQUIREMENTS.md v2 section and ROADMAP Backlog): -->

- [ ] Real-machine install, rerun and uninstall on a Mac (VERI-01)
- [ ] Real-machine install, rerun and uninstall on Windows x64 and ARM64 (VERI-02)
- [ ] Pin `rea-agents` and hash-pin PyPI installs (SUPP-01, SUPP-02)
- [ ] Backlog 999.1 / 999.2: no-npm dry run on macOS/Windows; Windows `JAVA_HOME` on an unavailable drive

### Out of Scope

- Real-hardware verification on macOS and Windows — fixes are made from code analysis and dry runs; real-machine confirmation is a separate, later task (user decision)
- Installing Binwalk, Unblob, pwndbg — no prebuilt binaries / too many separately pinned paths; feature work, not hardening
- Sharing helper code between the two bash scripts — each must run standalone via `curl | bash`
- Pinning `rea-agents` or hashing PyPI installs — kept out of v1; now a v2 candidate (SUPP-01/02)
- Linux `unpack` failing loudly on a top-folder mismatch (WR-01) — accepted as a known limitation; the JDK path handles it, other tools are documented in the README

## Context

**Current state (after v1, 2026-10-15):** v1 Installer Hardening shipped. Installers + `test.sh` are 2,436 lines (Linux 666, macOS 493, Windows 342, `test.sh` 935). `test.sh` passes locally: 119 passed / 0 failed on macOS Bash 3.2, 85 passed / 0 failed in `ubuntu:24.04`.

- Brownfield: codebase mapped in `.planning/codebase/` (2026-10-14).
- Findings source for v1: `.planning/AUDIT.md` (HARD-01..12), all addressed or accepted.
- Root cause behind HARD-01/02: bash turns `set -e` off inside `$(...)` and inside functions called on the left of `||`/`&&` or in an `if`. Verified under bash 3.2.57.
- README status: Linux tested end to end in containers before v1's fixes; macOS and Windows are dry runs and `test.sh` only. No real macOS/Windows run yet (VERI-01/02).
- Testing is local only: `/bin/bash ./test.sh` on macOS and `./test.sh` in a Linux container. No GitHub Actions.
- Known technical debt: deferred review findings per phase (see `milestones/v1-MILESTONE-AUDIT.md`), all listed in README Known limitations; backlog 999.1 and 999.2.

## Constraints

- **Compatibility**: `rea-install-macos.sh` must run on macOS's Bash 3.2 (no `mapfile`, no associative arrays) — system shell on every Mac
- **Compatibility**: `rea-install-linux.sh` may use Bash 4+; Windows script must work on PowerShell 5.1 and 7
- **Distribution**: each script stays a single self-contained file — users run it via `curl | bash` or a single download
- **Safety**: dry-run must not change anything; uninstall must not remove anything the script didn't add
- **Testing**: all testing is local — `/bin/bash ./test.sh` on macOS (Bash 3.2) and `./test.sh` in a local Linux container (docker); it covers Linux containers, shellcheck and PowerShell parsing, with no real macOS/Windows installs

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Scope milestone to AUDIT.md HARD-01..12 | Concrete, verified findings with acceptance checks | ✓ Good — 19/19 requirements shipped in 2 days |
| Fix macOS/Windows from code analysis, not real-hardware verification | No real-machine run in this milestone; tracked separately | ⚠️ Revisit — VERI-01/02 still needed before calling macOS/Windows tested |
| `test.sh` runs locally and in GitHub Actions | Catch regressions on every push, not just before release | Superseded 2026-10-14: GitHub Actions removed; see the next row |
| No GitHub Actions; all testing is local | User decision at Phase 2 UAT | ✓ Good |
| Accept WR-01, WR-02, WR-05 as known limitations | UAT decision; fix cost outweighed risk before Phase 2 | ✓ Good — documented in README; JDK layout case fixed in Phase 2 |
| README kept in sync with each fix | README makes specific status/limitation claims users rely on | ✓ Good — verified once in Phase 3, plus accepted findings at close |
| One "reuse JDK ≥21, else install our own" rule on all platforms | Linux trusts any JAVA_HOME, macOS overrides it — make them consistent | ✓ Good — took 10 plans; ownership by ledger, not caller's shell |
| Write regression checks red before each fix | Prove each check can fail | ✓ Good — caught weak checks (e.g. winget ledger) |
| Lean Phase 3 close: defer WR-02..07 as accepted, documented in README | User decision; revisit with VERI-01 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-10-15 after v1 milestone*
