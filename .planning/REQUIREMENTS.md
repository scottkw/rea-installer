# Requirements: rea-installer

**Defined:** 2026-10-14
**Core Value:** Installing and uninstalling must never leave the user's machine in a silently broken or altered state: a failure stops loudly, a rerun recovers, and uninstall removes only what the script added.

Source for every requirement: `.planning/AUDIT.md` (HARD-xx in parentheses has location, scenario, fix and acceptance check).

## v1 Requirements

### Failure Handling

- [ ] **FAIL-01**: When extracting a downloaded archive fails (Linux or Windows), the install stops with an error and no partial tool folder is left, so a rerun extracts again (HARD-01)
- [ ] **FAIL-02**: When a Linux system package install fails, the install stops with the "X is required" error for required tools, and the failed package is not recorded in the ledger (HARD-02)
- [ ] **FAIL-03**: When a macOS `brew install` fails, the formula is not recorded and the failure is reported (HARD-02)

### Dry Run

- [ ] **DRY-01**: User can run `./rea-install-linux.sh install --dry-run` (including `--with-android`) on a fresh machine with no Node.js and it exits 0 with a printed plan (HARD-03)
- [ ] **DRY-02**: Linux `install --dry-run` and `uninstall --dry-run` change nothing on disk (no `rm -rf` of `~/.rea-installer/node`, no `rmdir` of `~/.agents`) (HARD-03, HARD-12)

### Java

- [ ] **JAVA-01**: On Windows, after Temurin is installed, `JAVA_HOME` points at Temurin 21 for the session and is saved as a user variable that uninstall removes, whether or not the MSI set it (HARD-04)
- [ ] **JAVA-02**: On every platform, an existing `JAVA_HOME` is reused only if it is JDK 21 or newer; otherwise the script installs its own JDK (HARD-05, HARD-06)
- [ ] **JAVA-03**: On macOS, a user's existing JDK ≥21 `JAVA_HOME` is never overwritten in the shell profile (HARD-05)
- [ ] **JAVA-04**: On macOS, rerunning `install` (with `--with-extras` or `--with-android`) keeps `JAVA_HOME` in the single profile block when it points at the script's own JDK (HARD-11)

### Uninstall

- [ ] **UNIN-01**: When `rea uninstall --purge-data` fails or the `rea` CLI is broken, uninstall warns and still removes every other recorded item on Linux, macOS and Windows (HARD-07)

### Testing

- [ ] **TEST-01**: Maintainer can run `./test.sh` locally: it runs `shellcheck` and `bash -n` on both bash scripts and parses the PowerShell script (HARD-08)
- [ ] **TEST-02**: `test.sh` verifies that adding then removing the profile block leaves the rest of a sample profile byte-identical (HARD-08)
- [ ] **TEST-03**: `test.sh` verifies `node_supported` accepts/rejects a table of Node versions (22.18 no, 22.19 yes, 24.14 no, 24.15 yes, 26.0 yes) (HARD-08)
- [ ] **TEST-04**: `test.sh` runs Linux `install --dry-run` in a fresh `ubuntu:24.04` container and expects exit 0 with no changes (HARD-08)
- [ ] **TEST-05**: `test.sh` includes checks that fail before and pass after the FAIL-01, FAIL-02 and DRY-01 fixes (HARD-08)
- [ ] **TEST-06**: GitHub Actions runs `test.sh` on every push and pull request (HARD-08)

### macOS Polish

- [ ] **MAC-01**: macOS `install` without a terminal (CI, non-tty ssh) warns to run `rea setup` manually instead of failing (HARD-09)
- [ ] **MAC-02**: macOS `install --yes` on a Mac without Homebrew installs Homebrew without waiting for Return (HARD-10)

### Documentation

- [ ] **DOCS-01**: README Status, Testing and Known limitations sections reflect every fix in this milestone (including the new test harness and CI)

## v2 Requirements

### Verification

- **VERI-01**: Full install, rerun and uninstall verified on a real Mac
- **VERI-02**: Full install, rerun and uninstall verified on real Windows x64 and ARM64 (confirms JAVA-01 and the WinLibs `objdump` PATH)

### Supply chain

- **SUPP-01**: Pin `rea-agents` to a version instead of `@latest`
- **SUPP-02**: Install PyPI packages with `--require-hashes`

## Out of Scope

| Feature | Reason |
|---------|--------|
| Real-hardware verification in this milestone | User decision: fix from code analysis; tracked as v2 VERI-01/02 |
| Binwalk, Unblob, pwndbg | No prebuilt binaries / many separately pinned paths; feature work, not hardening |
| Shared helper library across the bash scripts | Each script must stay standalone for `curl \| bash` |
| Real macOS/Windows installs in CI | CI runners can't safely exercise agent registration and system installs; Linux containers + lint only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FAIL-01 | Phase 1 | Pending |
| FAIL-02 | Phase 1 | Pending |
| FAIL-03 | Phase 1 | Pending |
| DRY-01 | Phase 1 | Pending |
| DRY-02 | Phase 1 | Pending |
| JAVA-01 | Phase 2 | Pending |
| JAVA-02 | Phase 2 | Pending |
| JAVA-03 | Phase 2 | Pending |
| JAVA-04 | Phase 2 | Pending |
| UNIN-01 | Phase 1 | Pending |
| TEST-01 | Phase 1 | Pending |
| TEST-02 | Phase 1 | Pending |
| TEST-03 | Phase 1 | Pending |
| TEST-04 | Phase 1 | Pending |
| TEST-05 | Phase 1 | Pending |
| TEST-06 | Phase 1 | Pending |
| MAC-01 | Phase 3 | Pending |
| MAC-02 | Phase 3 | Pending |
| DOCS-01 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0 ✓

---
*Requirements defined: 2026-10-14*
*Last updated: 2026-10-14 after roadmap creation (traceability filled)*
