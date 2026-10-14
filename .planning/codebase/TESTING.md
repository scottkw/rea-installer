---
last_mapped_commit: 894cf00cc8f19f557bdbdee6cab36a3d5d6b5f25
last_mapped_at: 2026-10-14
---
# Testing Patterns

**Analysis Date:** 2026-10-14

## Summary

The repository has **no automated test suite**. There are no test files, no test runner, no test dependencies, no CI configuration and no coverage tooling in the tracked tree. Verification is manual and is documented in the README's "Testing" section. The patterns below describe that process so new changes are verified the same way.

Because the code is three installer scripts that mutate the system (Homebrew, npm, apt/dnf/pacman, winget, shell profiles, user environment variables), the risk is concentrated in:
- correct dry-run behavior (nothing mutates),
- idempotent reruns,
- exact uninstall (only recorded items are removed),
- download integrity (checksum enforcement).

## Test Framework

**Runner:** None. No `bats`, `pytest`, Pester or similar is configured.

**Assertion library:** None.

**Static checks in use:**
- Bash: `bash -n` (syntax) and `shellcheck` (lint). The README states these were run under the system `/bin/bash` 3.2 for macOS.
- PowerShell: the PowerShell language parser (`[System.Management.Automation.Language.Parser]::ParseFile`), run under PowerShell 7 on macOS.

**Run commands** (the static and dry-run checks used by the project):

```bash
bash -n rea-install-macos.sh                 # Syntax check, macOS
bash -n rea-install-linux.sh                 # Syntax check, Linux
shellcheck rea-install-macos.sh rea-install-linux.sh   # Lint both Bash scripts
```

```bash
pwsh -NoProfile -Command '$e=$null; [System.Management.Automation.Language.Parser]::ParseFile("rea-install-windows.ps1",[ref]$null,[ref]$e) | Out-Null; $e'   # Parse check; empty output means no errors
```

```bash
./rea-install-macos.sh install --dry-run --with-android --with-extras
./rea-install-macos.sh uninstall --dry-run
./rea-install-linux.sh install --dry-run --with-android --with-extras --with-linux-tools
./rea-install-linux.sh uninstall --dry-run
```

```powershell
powershell -ExecutionPolicy Bypass -File .\rea-install-windows.ps1 install -DryRun -WithAndroid -WithExtras
powershell -ExecutionPolicy Bypass -File .\rea-install-windows.ps1 uninstall -DryRun
```

The parse-check command above is a suggested form for the PowerShell parser; it is not committed to the repo.

**Coverage:** Not measured. There is no coverage requirement and no coverage tool. The global "80%+ coverage" rule in `/Users/ken/dev/CLAUDE.md` does not apply to these scripts because no coverage tool can run against Bash or PowerShell here. Verification evidence is the dry-run output, the static checks and the container and sandbox runs described below.

## Test File Organization

**Location:** There are no test files. Tests are not co-located or separated, because none exist.

**If tests are added:** Put them in a top-level `tests/` directory, named after the script under test (`tests/linux_profile_block.bats`, etc.), so they do not get mixed into the install scripts. Do not add test files to the repo root, which holds the user-facing scripts and README.

## Verification Process (documented in README)

### 1. Static checks

- Syntax: `bash -n` on each Bash script. macOS must pass under `/bin/bash` 3.2, not only a newer bash, because that is the macOS default. Do not use Bash 4+ features (associative arrays, `mapfile` is used only in the Linux script, `${var,,}`) in `rea-install-macos.sh`.
- Lint: `shellcheck` on each Bash script. Any intentional suppression needs an inline `# shellcheck disable=SCxxxx  # reason` comment.
- PowerShell: parse with the PowerShell parser; the README reports this as the check for `rea-install-windows.ps1`.

### 2. Dry runs

Every script accepts `--dry-run` (`-DryRun` on Windows). In dry-run mode:
- `run` (Bash) and `Invoke-Step` (PowerShell) print each command but do not execute it.
- `record` / `Add-Record` do not write the ledger.
- Checksum verification and file moves are skipped (`if [ "$dry_run" = false ]; then ...`).
- `pkg_available` returns success without querying the package manager.
- Missing tools that would be resolved at runtime are substituted with placeholders (`/usr/bin/$2` on Linux, `<Temurin JAVA_HOME>` on Windows) so the plan can still be printed.

A dry run is the minimum check for any change. Read the printed plan and confirm each `$`/`>` line is what you intended.

**Windows x64 and ARM64 dry-run cases** (from the README): run both, because the ARM64 path skips Ghidra and JADX. The README also records a rejection test for 32-bit Windows (`throw` on a non-AMD64/ARM64 `PROCESSOR_ARCHITECTURE`).

### 3. Download and checksum tests

- Confirm a tampered checksum is rejected: the script must delete `*.part`, print the error and not move the file into place.
- The macOS README entry records the JADX checksum being verified against the real download. Repeat this check when a pin changes.
- The Windows README entry records the real download, checksum and extraction path for WABT.

When updating a pinned URL or hash, verify the hash against the upstream release asset digest, not a copy from another script, and update every script that pins the same asset (the same JADX jar is pinned in both `rea-install-macos.sh` and `rea-install-linux.sh`, and in `rea-install-windows.ps1`).

### 4. Sandboxed profile-block tests

Shell-profile editing is tested in a sandboxed home directory (README, macOS entry). Procedure:
1. Create a temporary `HOME` containing a profile file with existing content.
2. Run install with `--dry-run` or `--yes` where safe, or run `remove_profile_block` directly against the file.
3. Confirm exactly one `# >>> rea-installer >>>` / `# <<< rea-installer <<<` block exists after install, and that uninstall removes only that block.

Use a throwaway `HOME` (for example, `HOME=$(mktemp -d) ./rea-install-macos.sh ...`). Do not run install tests against a real profile.

### 5. Container tests (Linux)

The Linux script was tested end to end in containers:
- Ubuntu 24.04 (x64)
- Fedora 44 (arm64)
- Arch Linux (x64)

Each run followed the same sequence, on a read-only copy of the script:
1. **Install** with every option (`--with-android --with-extras --with-linux-tools`), then run each configured tool at its pinned version and run `rea doctor`.
2. **Reinstall** from a shell that already has the profile block loaded. Expect no re-downloads, one profile block, and unchanged settings.
3. **Uninstall**, then compare the installed-package list (`dpkg-query` / `rpm -qa` / `pacman -Qq`) to the list captured before install. Expect zero leftover packages and zero pre-existing packages removed, except for dependencies the distribution protects (Fedora `systemd`).

Use a fresh container per distribution. Capture the package list before and after with `pkg_list`-equivalent commands, and diff them.

### 6. Not yet run

The README records these as untested on real hardware. They are the highest-value remaining checks and should be run in a disposable environment before release:
- a full macOS install (it changes the tester's own agent configuration),
- any real Windows run, including `winget` installs, Temurin setting `JAVA_HOME`, WinLibs putting `objdump` on `PATH`, and the ARM64 detection in `Invoke-Install`.

## Test Structure (manual procedure, no suite)

Each manual run should record:
- the script commit (`git rev-parse --short HEAD`),
- the OS and architecture (`uname -a`, or `$env:PROCESSOR_ARCHITECTURE` on Windows),
- the exact command line,
- the printed plan from `--dry-run`,
- the ledger file (`~/.rea-installer/installed`) before and after, and
- the result of `rea doctor` when install succeeds.

## Mocking

**Framework:** None. Scripts are not unit-tested, so there is no mocking library.

**Substitution used in practice:**
- Dry-run mode stands in for mocking: `run` and `Invoke-Step` replace execution with printing.
- The Windows README entry used a **stubbed `winget`** on PowerShell 7 on macOS to exercise the install path without a real Windows host. Use the same approach for other package managers: put a stub command first on `PATH` that logs its arguments and exits 0 or the expected status.
- `HOME` redirection replaces the real profile and state directory (`STATE_DIR="$HOME/.rea-installer"`, `$HOME/.zshrc`, `$HOME/.bashrc`, `$HOME/.agents`).

**What to stub:**
- Package managers (`brew`, `apt-get`, `dnf`, `pacman`, `winget`) and `npm` when testing flow and ledger writes.
- Network downloads: prefer a local HTTP server or a pre-placed file with the right hash for the `fetch` path. Do not change the pinned SHA in the script to make a test pass.
- `rea` itself, when testing only the installer's uninstall ordering.

**What NOT to stub:**
- The checksum comparison (`shasum -a 256 -c -`, `sha256sum -c -`, `Get-FileHash`). It is the security control. Test it against real and tampered files.
- The ledger format. Uninstall depends on the exact line format written by `record`, so test a recorded file with `cat` and `grep -x`.

## Fixtures and Factories

**Test data:** None committed.

**Locations for fixtures** (if added): `tests/fixtures/`. Keep fixtures small and keep any fake checksums clearly labeled, so they are never mistaken for the real pins in the scripts.

## Coverage

**Requirements:** None enforced.

**Measured:** No.

## Test Types

**Unit tests:** None. The helper functions (`node_supported`, `pkg_installed`, `remove_profile_block`, `Test-NodeSupported`) are testable in principle by sourcing the script or dot-sourcing it, but the scripts run `set -euo pipefail` and the main dispatch at load time, so sourcing executes the main `case`. Before writing unit tests, move the dispatch into a `main "$@"` function guarded by a `[[ "${BASH_SOURCE[0]}" == "$0" ]]` check. This is a change to the scripts, so do it deliberately.

**Integration tests:** The container runs (Linux) and sandboxed-HOME runs (macOS profile handling) are the closest existing equivalent. These are manual.

**End-to-end tests:** Manual install and uninstall on a clean machine or container. Not automated.

## Common Patterns

**Dry-run assertion pattern (manual):**

```bash
out="$(./rea-install-linux.sh install --dry-run --yes 2>&1)"
grep -q '^==> Installing rea-agents' <<<"$out" || echo "missing npm step"
grep -q 'npm install --global' <<<"$out" || echo "npm step did not print"
```

**Idempotency check pattern (manual):**

```bash
./rea-install-linux.sh install --yes
./rea-install-linux.sh install --yes   # second run should log "already" and not re-download
grep -c '# >>> rea-installer >>>' ~/.bashrc   # expect 1
```

**Ledger check pattern (manual):**

```bash
cat ~/.rea-installer/installed          # every line should be one recorded prefix (brew:, pkg:, npm:, profile:, ...)
```

**Checksum rejection pattern (manual):**

```bash

# Corrupt a download and confirm the script refuses it and leaves no .part file.

printf 'x' >> ~/.rea-installer/tools/apktool_3.0.3.jar.part   # only if the part file exists
```

Use these as starting points. Prefer a repeatable script in `tests/` over ad hoc shell history once a test directory exists.

---

*Testing analysis: 2026-10-14*
