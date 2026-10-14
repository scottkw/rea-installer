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
- ✓ `--dry-run` / `-DryRun` prints the plan — existing (has known violations, see HARD-03, HARD-12)
- ✓ Linux end-to-end install, reinstall and uninstall verified in Ubuntu 24.04, Fedora 44 and Arch containers — existing

### Active

<!-- Installer hardening milestone. Source: .planning/AUDIT.md (HARD-01..HARD-12). -->

- [ ] Failed archive extraction stops the install and leaves no partial folder (HARD-01)
- [ ] Failed package installs stop the install and are not recorded (HARD-02)
- [ ] Linux `--dry-run` succeeds on a fresh machine and changes nothing (HARD-03, HARD-12)
- [ ] Windows sets `JAVA_HOME` reliably after installing Temurin (HARD-04)
- [ ] macOS respects an existing `JAVA_HOME` and keeps its own across reruns (HARD-05, HARD-11)
- [ ] All platforms reject an existing `JAVA_HOME` older than JDK 21 (HARD-06)
- [ ] Uninstall completes even when the `rea` CLI is broken (HARD-07)
- [ ] Repeatable `test.sh`, run locally and in GitHub Actions (HARD-08)
- [ ] macOS polish: no-tty `rea setup`, non-interactive Homebrew under `--yes` (HARD-09, HARD-10)
- [ ] README Status / Testing / Known limitations updated to match each fix

### Out of Scope

- Real-hardware verification on macOS and Windows — fixes are made from code analysis and dry runs; real-machine confirmation is a separate, later task (user decision)
- Installing Binwalk, Unblob, pwndbg — no prebuilt binaries / too many separately pinned paths; feature work, not hardening
- Sharing helper code between the two bash scripts — each must run standalone via `curl | bash`
- Pinning `rea-agents` or hashing PyPI installs — supply-chain tightening is a separate decision, not part of this milestone

## Context

- Brownfield: codebase mapped in `.planning/codebase/` (corrected 2026-10-14 after `/code-review high`).
- Findings source: `.planning/AUDIT.md` (`/ponytail-audit` + `/code-review high`, 2026-10-14). Each HARD item has location, scenario, fix and acceptance check.
- Root cause behind HARD-01/02: bash turns `set -e` off inside `$(...)` and inside functions called on the left of `||`/`&&` or in an `if`. Verified under bash 3.2.57.
- README status: Linux tested end to end in containers; macOS and Windows dry runs only.
- No automated tests or CI exist today.

## Constraints

- **Compatibility**: `rea-install-macos.sh` must run on macOS's Bash 3.2 (no `mapfile`, no associative arrays) — system shell on every Mac
- **Compatibility**: `rea-install-linux.sh` may use Bash 4+; Windows script must work on PowerShell 5.1 and 7
- **Distribution**: each script stays a single self-contained file — users run it via `curl | bash` or a single download
- **Safety**: dry-run must not change anything; uninstall must not remove anything the script didn't add
- **Testing**: CI can only exercise Linux containers, shellcheck, and PowerShell parsing — no real macOS/Windows installs in CI

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Scope milestone to AUDIT.md HARD-01..12 | Concrete, verified findings with acceptance checks | — Pending |
| Fix macOS/Windows from code analysis, not real-hardware verification | No real-machine run in this milestone; tracked separately | — Pending |
| `test.sh` runs locally and in GitHub Actions | Catch regressions on every push, not just before release | — Pending |
| README kept in sync with each fix | README makes specific status/limitation claims users rely on | — Pending |
| One "reuse JDK ≥21, else install our own" rule on all platforms | Linux trusts any JAVA_HOME, macOS overrides it — make them consistent | — Pending |

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
*Last updated: 2026-10-14 after initialization*
