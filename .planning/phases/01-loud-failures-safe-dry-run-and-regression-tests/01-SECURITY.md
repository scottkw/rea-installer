---
phase: "01"
slug: "loud-failures-safe-dry-run-and-regression-tests"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-10-14"
---

# Phase 01 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Internet to user's shell | `curl \| bash` feeds the script to bash; the source guard sits on that path | installer script text |
| test.sh to maintainer's machine | test.sh sources installer functions that write to `$HOME`, the ledger and shell profiles | file system writes |
| test.sh to Docker | Repo mounted into an ubuntu:24.04 container | repo files (read-only) |
| test.sh to pwsh | Driver dot-sources the Windows script, whose `Invoke-Uninstall` removes `$StateDir` | file system writes |
| GitHub Actions runner | Third-party action code runs with the workflow token | read-only repo token |
| Release hosts to `$TOOLS_DIR` / `$ToolsDir` | Downloaded archives verified by pinned or published SHA-256 | binaries |
| Installer to user's home and system packages | `rm -rf`, `mv`, sudo package installs, brew, winget, user env vars | system state |
| GitHub Actions API to maintainer shell | `gh` reads run status with the maintainer's own auth; nothing is written | CI status |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-01-01 | Tampering | Source guard (linux/macos) | high | mitigate | `(return 0 2>/dev/null) && return 0` at rea-install-linux.sh:579, rea-install-macos.sh:322; GUARD check in test.sh | closed |
| T-01-02 | Tampering | test.sh sandbox writes | high | mitigate | `export HOME="$work/home"` before sourcing (test.sh:32); pwsh runs use `$work/pwsh-home` | closed |
| T-01-03 | Tampering | test.sh cleanup | medium | mitigate | `trap 'rm -rf "${work:?}"' EXIT` (test.sh:18) | closed |
| T-01-04 | Elevation of privilege | test.yml token | medium | mitigate | `permissions: contents: read`; no secrets; no `pull_request_target` | closed |
| T-01-05 | Tampering | `actions/checkout` tag | medium | accept | Pinned to `v7.0.1` per D-12 | closed |
| T-01-06 | Tampering | UNIN-01 bash checks | high | mitigate | Temp HOME, `npm:` pinned to stub path (test.sh:204), no `brew:`/`cask:` lines (test.sh:190-198) | closed |
| T-01-07 | Tampering | pwsh driver `Invoke-Uninstall` | high | mitigate | Driver overrides `$ToolsDir`/`$StateDir`/`$StateFile` (test.sh:277-279); stubs first on PATH | closed |
| T-01-08 | Tampering | docker run | low | mitigate | `--rm --network none -v "$root:/src:ro"` (test.sh:241, 253) | closed |
| T-01-09 | Repudiation | 01-RED.log | low | mitigate | Header records platform, bash version, UTC date, commit 3c96f26 | closed |
| T-01-10 | Tampering | `unpack` partial extract | high | mitigate | `.staging-<name>` then `mv` on success (rea-install-linux.sh:243-255) | closed |
| T-01-11 | Tampering | `fetch` checksum die inside `unpack` | high | mitigate | `archive="$(fetch "$1")" \|\| exit 1` (rea-install-linux.sh:245) | closed |
| T-01-12 | Tampering | `unpack` cleanup `rm -rf` | medium | mitigate | Only staging and archive removed, via `run` (rea-install-linux.sh:246-255) | closed |
| T-01-13 | Tampering | Dry-run mutations | medium | mitigate | `run`-wrapped removals; `[ "$dry_run" = true ] \|\|` guards (rea-install-linux.sh:382, 569) | closed |
| T-01-14 | Denial of service | Uninstall blocked by broken `rea` (Linux) | medium | mitigate | `\|\| warn` (rea-install-linux.sh:523) | closed |
| T-01-15 | Repudiation | Failed package recorded as installed | medium | mitigate | `\|\| return 1` on each install command (rea-install-linux.sh:173-176) | closed |
| T-01-16 | Tampering | `Expand-PinnedArchive` partial extract | high | mitigate | `.staging-$Folder`, `Move-Item` on success, `Could not unpack` throw (rea-install-windows.ps1:134-157) | closed |
| T-01-17 | Tampering | `Expand-PinnedArchive` cleanup | medium | mitigate | Only `Join-Path $ToolsDir ".staging-$Folder"` and the archive are removed | closed |
| T-01-18 | Repudiation | `brew_install` records a failed formula | medium | mitigate | `warn` + `return 1` before `record` (rea-install-macos.sh:106) | closed |
| T-01-19 | Denial of service | Uninstall blocked by broken `rea` (macOS, Windows) | medium | mitigate | `\|\| warn` (rea-install-macos.sh:261); try/catch + `Warn` (rea-install-windows.ps1:255) | closed |
| T-01-20 | Repudiation | CI gate reads a run for another commit | medium | mitigate | `gh run list --commit "$(git rev-parse HEAD)"`; run 38601604074 recorded for 770a678 | closed |
| T-01-21 | Tampering | Gate turned green by editing tests | medium | mitigate | No commits to test.sh, test.yml or installers since 01-05 base 770a678 | closed |
| T-01-SC | Tampering | npm/pip/cargo installs | low | accept | No registry packages added in any plan | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01-01 | T-01-05 | Tag pin instead of SHA pin for a GitHub-owned action (user decision D-12); SHA pinning tracked as IN-02 | plan 01-01 | 2026-10-14 |
| AR-01-02 | T-01-SC | No registry packages are installed by this phase; existing pins unchanged | plans 01-01..01-05 | 2026-10-14 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-10-14 | 22 | 22 | 0 | /gsd-secure-phase (L1 grep-depth, auditor skipped per short-circuit) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-10-14
