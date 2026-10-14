---
last_mapped_commit: 894cf00cc8f19f557bdbdee6cab36a3d5d6b5f25
last_mapped_at: 2026-10-14
---
<!-- refreshed: 2026-10-14 -->

# Architecture

**Analysis Date:** 2026-10-14

## System Overview

```text
┌──────────────────────────────────────────────────────────────────────┐
│                    User shell (Terminal / PowerShell)                 │
│        `rea-install-macos.sh` · `rea-install-linux.sh` ·              │
│        `rea-install-windows.ps1`   (argv: install|uninstall, flags)   │
└───────────────┬──────────────────────────────┬───────────────────────┘
                │ parse flags, dispatch         │ state reads/writes
                ▼                               ▼
┌──────────────────────────────┐   ┌─────────────────────────────────────┐
│  Phase functions (per script)│   │  Install ledger                     │
│  do_install / do_uninstall   │──▶│  `~/.rea-installer/installed`       │
│  (or Invoke-Install /        │   │  one `kind:value` line per change   │
│   Invoke-Uninstall)          │   │  (Windows: `~\.rea-installer\...`)  │
└───────────────┬──────────────┘   └─────────────────────────────────────┘
                │ run() / Invoke-Step wrappers (honor --dry-run)
                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ System package managers and downloads                                │
│  Homebrew · winget · apt/dnf/pacman · GitHub release tarballs (pinned)│
│  nodejs.org · Adoptium · npm (`rea-agents`) · uv (Linux venvs)        │
└───────────────┬─────────────────────────────────────────────────────┘
                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ REA CLI (`rea`): `rea setup` registers agents + skill; `rea uninstall` │
│ removes its own registrations and data                               │
└─────────────────────────────────────────────────────────────────────┘
```

The repository is a set of three independent, self-contained installer scripts. There is no shared library, build step, or runtime service; each script is run directly by the user.

## Pattern Overview

**Overall:** Single-file, procedural command-line installer per platform. Each script is a flat sequence of bash functions (or PowerShell functions) driven by a `case` / `switch` on a sub-command.

**Key Characteristics:**
- Three platform implementations that mirror one another: `rea-install-macos.sh` (340 lines), `rea-install-linux.sh` (593 lines), `rea-install-windows.ps1` (280 lines). Behaviour is intended to match across platforms (same subcommands, same flags where applicable, same ordering of steps).
- Two subcommands only: `install` and `uninstall`. Anything else prints usage or fails with `die`.
- Every mutation is routed through a single wrapper (`run` in bash, `Invoke-Step` in PowerShell), so `--dry-run` / `-DryRun` prints the command instead of running it.
- Every change that uninstall must reverse is appended to a ledger via `record` (bash) or `Add-Record` (PowerShell). Uninstall reads the ledger in reverse (`tac` in bash, `[array]::Reverse` in PowerShell) and removes only recorded items.
- No third-party code is linked in. Dependencies are fetched at runtime: distribution packages, Homebrew, winget, npm, or GitHub release assets pinned by URL and SHA-256 digest.
- Idempotence is by checking, not by state: `pkg_installed`, `brew_install`, `Test-WingetInstalled`, and "already present" checks skip work already done, and `record` deduplicates lines with `grep -qxF`.

## Layers

Each script is organised into the same logical layers, expressed as sections separated by comment banners (`# ---- environment`, `# ---- install`, `# ---- uninstall`, `# ---- main`).

**Helpers / output and safety layer:**
- Purpose: logging, error exit, command execution with dry-run, ledger write, confirmation prompt.
- Location: top of each script. macOS `rea-install-macos.sh` lines ~32–55 (`log`, `warn`, `die`, `run`, `record`, `confirm`, `usage`). Linux `rea-install-linux.sh` lines ~47–70 (same set plus `setting`, `tool_setting`, `arch`, `sudo_cmd`). Windows `rea-install-windows.ps1` lines ~48–70 (`Log`, `Warn`, `Invoke-Step`, `Add-Record`, `Confirm-Step`).
- Depends on: nothing beyond the shell.
- Used by: every phase function.

**Environment / detection layer:**
- Purpose: find existing tools and decide what to install or skip.
- macOS: `load_brew`, `load_nvm`, `node_supported`, `profile_file`, `hopper_apps` (`rea-install-macos.sh` ~58–118).
- Linux: `detect_pm` (apt, dnf, pacman), `check_pacman_synced`, `pkg_name`, `pkg_installed`, `pkg_available`, `pkg_list`, `pkg_owner`, `arch`, `load_nvm`, `node_supported`, `profile_file` (`rea-install-linux.sh` ~85–290). Package names are looked up per package manager through `pkg_name`.
- Windows: `Update-SessionPath`, `Test-NodeSupported`, `Test-WingetInstalled`, and ARM64 detection via `$isArm64` in `Invoke-Install`.
- Depends on: helpers layer.
- Used by: install and uninstall phases.

**Acquisition layer:**
- Purpose: fetch and verify external artifacts.
- Linux: `fetch` (`rea-install-linux.sh` ~219) and `unpack` (~239) handle pinned downloads. Pins are declared at the top of the file as `NAME_arch="URL SHA256"` strings (e.g. `WABT_x64`, `RIZIN_x64`, `UV_arm64`, `WAKARU_x64`).
- Windows: `$Downloads` hashtable at the top of `rea-install-windows.ps1` (keys `ghidra`, `jadx`, `apktool`, `wabt`, each with `Url` and `Sha`), read by `Get-PinnedFile` (~115) and `Expand-PinnedArchive` (~133).
- macOS: `brew_install` (~99) for Homebrew formulae and casks; the JADX jar is fetched by `install_jadx_jar` (~130).
- Depends on: helpers, environment layers.
- Used by: install phase.

**Install phase:**
- Purpose: perform the install in a fixed order.
- Location: macOS `do_install` (`rea-install-macos.sh` ~148–242); Linux `do_install` (~339–502) with helpers `install_node` (~292), `install_jdk` (~305), `make_venv` (~324); Windows `Invoke-Install` (`rea-install-windows.ps1` ~153–220) with `Install-Jdk` (~144).
- Depends on: all lower layers.
- Used by: main dispatch.

**Uninstall phase:**
- Purpose: reverse the ledger.
- Location: macOS `do_uninstall` (`rea-install-macos.sh` ~246–316); Linux `do_uninstall` (~503–~575); Windows `Invoke-Uninstall` (`rea-install-windows.ps1` ~222–272).
- Behaviour: reads `~/.rea-installer/installed`, processes entries in reverse, and dispatches on the `kind:` prefix (`clt`, `homebrew`, `profile`, `npm`, `app`, `pkg`, `hopper`, `env`, `winget`). Calls `rea uninstall --purge-data` (Windows, ~236) to let REA clean its own data first, then removes the ledger directory.
- Depends on: ledger file and helpers.

**Main dispatch:**
- Purpose: parse flags and route to a phase.
- Location: the `# ---- main` section at the bottom of each script (macOS ~318–340; Linux ~ 540–593; Windows ~274–280 via `param(...)` and `switch`).
- Depends on: install and uninstall phases.

## Data Flow

### Primary Install Path (all platforms, same order)

1. Parse flags (`--yes`, `--dry-run`, `--no-ghidra`, `--with-android`, `--with-extras`, and on Linux `--with-linux-tools`). Each sets a shell variable (`assume_yes`, `dry_run`, `with_ghidra`, etc.) or a PowerShell switch.
2. Ensure base requirements: Xcode Command Line Tools and Homebrew (macOS); package manager and `sudo`-capable access (Linux); winget (Windows). Each successful step is written to the ledger (`clt`, `homebrew`, `pkg:...`, `winget:...`).
3. Ensure a supported Node.js (`node_supported`). If absent, install via Homebrew (macOS), nodejs.org tarball into the home directory (Linux `install_node`), or winget `OpenJS.NodeJS.LTS` (Windows).
4. Install JDK 21 (default), Ghidra 12.1.4 (skipped with `--no-ghidra`; skipped on Windows ARM64 and Linux arm64 where REA lacks support), then optional groups.
5. Install REA: `npm install --global rea-agents@latest` (Windows also appends `@latest` through `$Package@latest`). Record `npm:<path to npm>`.
6. Run `rea setup` (with `--yes --all-detected` on Windows when `-Yes` is set). On macOS and Linux, Hopper is offered; its app name is recorded as `app:` or `hopper:` entries when newly added.
7. Append REA environment settings to the shell profile (`profile:<file>`) on macOS and Linux (`profile_lines` array). On Windows, persistent user environment variables are set with `Set-UserEnv` and recorded as `env:<NAME>`.

### Ledger Format

- Path: `~/.rea-installer/installed` (`STATE_FILE` in `rea-install-macos.sh:15` and `rea-install-linux.sh:18`; `$StateFile` in `rea-install-windows.ps1`).
- Format: one `kind:value` record per line. Records are deduplicated on write.
- Known kinds: `clt`, `homebrew`, `profile:<path>`, `npm:<path>`, `app:<name>`, `hopper:<owner>`, `pkg:<name> <added packages>`, `winget:<id>`, `env:<name>`.
- Non-state artefacts go under `~/.rea-installer/tools` (Windows: `$ToolsDir`; Linux and macOS write downloads and venvs under the same directory tree).

### Uninstall Path

1. Run `rea uninstall` (with purge) where REA is present, so REA removes its agent registrations, skills and data first.
2. Read the ledger in reverse order and reverse each entry by kind.
3. Remove the ledger directory unless `--dry-run`. The Linux script also removes `~/.agents/skills` and `~/.agents` if they are empty (`rmdir`), because REA leaves them behind.

**State Management:**
- All persistent state is the ledger file plus the files it points to. There is no in-memory state between runs; each invocation re-derives everything from the environment and the ledger.
- Process-level flags (`assume_yes`, `dry_run`, `with_*`, `pm`, `apt_updated`) are globals set during argument parsing. On Linux, `apt_updated` ensures `apt-get update` runs at most once per invocation.

## Key Abstractions

**Ledger record (`record` / `Add-Record`):**
- Purpose: the only mechanism for uninstall to know what was added.
- Examples: `rea-install-macos.sh` (`record` ~41), `rea-install-linux.sh` (`record` ~56), `rea-install-windows.ps1` (`Add-Record` ~58).
- Pattern: append-only, deduplicated, `kind:value` text. Uninstall branches on `kind`.

**Dry-run wrapper (`run` / `Invoke-Step`):**
- Purpose: single choke point for side effects.
- Examples: `rea-install-macos.sh` (`run` ~36); `rea-install-windows.ps1` (`Invoke-Step` ~51).
- Pattern: print the command with shell quoting (`printf ' %q'`), then execute unless dry-run. Code that bypasses it (direct `rm -rf`, `SetEnvironmentVariable`) must check `dry_run`/`$DryRun` itself; e.g. `[ "$dry_run" = true ] || rm -rf "$STATE_DIR"`.

**Pinned artifact (`fetch`, `Get-PinnedFile`, `Get-PinnedFile` consumers):**
- Purpose: reproducible downloads with integrity check.
- Examples: `UV_x64`, `WAKARU_x64` strings at the top of `rea-install-linux.sh`; `$Downloads` in `rea-install-windows.ps1`.
- Pattern: URL and SHA-256 are declared together; version bumps change both.

**Platform-specific package names (`pkg_name`, Linux):**
- Purpose: map one logical tool to the distro-specific package name for apt, dnf, or pacman.
- Example: `rea-install-linux.sh` ~112.

## Entry Points

**`rea-install-macos.sh`:**
- Location: `/Users/ken/dev/rea-installer/rea-install-macos.sh`
- Triggers: `./rea-install-macos.sh install|uninstall [flags]`
- Responsibilities: macOS (Apple silicon and Intel) install via Homebrew and npm; Bash 3.2 compatible (noted in README).

**`rea-install-linux.sh`:**
- Location: `/Users/ken/dev/rea-installer/rea-install-linux.sh`
- Triggers: `./rea-install-linux.sh install|uninstall [flags]`
- Responsibilities: Linux x64 and arm64 on apt, dnf, or pacman systems; distro packages plus pinned downloads into the home directory; optional Linux-only tooling via `--with-linux-tools`.

**`rea-install-windows.ps1`:**
- Location: `/Users/ken/dev/rea-installer/rea-install-windows.ps1`
- Triggers: `powershell -ExecutionPolicy Bypass -File .\rea-install-windows.ps1 install|uninstall [-Switches]`
- Responsibilities: Windows 10+ x64 and ARM64; winget plus pinned GitHub downloads; `-WithAndroid`, `-WithExtras`, `-NoGhidra`, `-Yes`, `-DryRun`.

**`README.md`:**
- Not executable. Serves as the user contract: component matrix, option reference, testing status.

## Architectural Constraints

- **Threading:** Single-threaded, sequential. No parallel downloads or installs.
- **Global state:** Script-level globals in each file (`assume_yes`, `dry_run`, `with_ghidra`, `with_android`, `with_extras`, `with_linux_tools`, `profile_lines`, `pm`, `apt_updated` in `rea-install-linux.sh`; equivalent `$Downloads`, `$StateDir`, `$StateFile`, `$ToolsDir`, `$Package`, `$JdkId` in `rea-install-windows.ps1`). They are set once during argument parsing or at file load and treated as read-only afterwards, except `apt_updated`, `profile_lines`, and `pm`, which are updated as the run proceeds.
- **Shell compatibility:** `rea-install-macos.sh` must run on Bash 3.2 (macOS default). Avoid Bash 4+ features such as associative arrays and `mapfile`.
- **Strict mode:** Bash scripts rely on the shell defaults plus explicit `die` on errors; Windows script sets `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'` at the top.
- **Elevation:** Linux uses `sudo_cmd`, which skips `sudo` when already root. Windows and macOS Homebrew install paths do not elevate by themselves.
- **No shared code:** The three scripts duplicate helper logic (`log`/`Log`, `run`/`Invoke-Step`, `record`/`Add-Record`, `confirm`/`Confirm-Step`, `load_nvm`, `node_supported`, `profile_file`, `remove_profile_block` appear in both bash files). Changes to ledger format or safety behaviour must be applied to each script by hand.
- **Ledger coupling:** Uninstall depends on exact `kind:value` strings written by install. Renaming a kind in one phase without updating the matching uninstall branch leaves stale installs.
- **Pinned versions:** Versions and digests are hard-coded in the scripts and in the README matrix; they must be updated together.

## Anti-Patterns

### Duplicated helper logic across the bash scripts

**What happens:** `rea-install-macos.sh` and `rea-install-linux.sh` each define their own `run`, `record`, `confirm`, `load_nvm`, `node_supported`, `profile_file`, and `remove_profile_block`.
**Why it's wrong:** A fix to one (for example, to ledger deduplication or the Node version check) silently leaves the other behind. The Windows script duplicates the same concepts in PowerShell.
**Do this instead:** When changing one of these helpers, make the matching change in every script in the same commit, and check the README support matrix still agrees. Do not extract a shared file unless the scripts need to stop being standalone (they currently are meant to be copied or run on their own).

### Uninstall that trusts the ledger without re-checking

**What happens:** Uninstall branches on ledger lines and calls `brew uninstall`, `winget uninstall`, `npm uninstall`, or `rm -rf` based on the record alone (for example `rea-install-linux.sh` line ~ 540 region and `rea-install-windows.ps1` ~ 259–266, which only checks `Test-WingetInstalled` before removal).
**Why it's wrong:** If the ledger and system have drifted (a package removed by hand, or the ledger copied between machines), the uninstall may still act on something the user now owns. The guarantee in the README ("removes only what it installed") depends on the ledger being accurate.
**Do this instead:** Keep the existence check before each destructive branch (as the Windows `winget` branch does) and extend it where missing, and keep `--dry-run` output reviewed before a real uninstall.

### Plain `sed -n` usage text parsing

**What happens:** `usage()` prints lines of the script header with `sed -n '2,11p' "$0"`, and the PowerShell help is extracted with `Get-Content $PSCommandPath -TotalCount 15`.
**Why it's wrong:** The usage text is coupled to the line numbers of the header comment. Editing the header changes the help output, and the range can silently truncate it.
**Do this instead:** When editing the header comment, check `./rea-install-macos.sh --help` and `./rea-install-linux.sh --help` (and the Windows script with no arguments) still print the full option list.

## Error Handling

**Strategy:** Fail fast. Bash scripts use `die` (prints `error: ...` to stderr and exits 1) on invalid input or missing prerequisites. Windows uses `$ErrorActionPreference = 'Stop'` so non-terminating errors become terminating ones.

**Patterns:**
- Argument validation with `die "unknown option: $1"` and `die "unknown command: $cmd (use install or uninstall)"`.
- Warnings with `warn` (stderr) for recoverable conditions, such as an existing tool that is left as-is.
- External commands are checked with `command -v` / `Get-Command` before use.
- Downloads are verified against pinned SHA-256 digests before unpacking (Linux `fetch`, Windows `Get-PinnedFile`).
- Interactive prompts read from `/dev/tty` in bash (`confirm`) so they still work when stdin is piped; `--yes` bypasses prompts.

## Cross-Cutting Concerns

**Logging:** `log` (`==> message`) for progress, `warn` for warnings, `die` for fatal errors. Windows uses `Write-Host` for progress and `Write-Warning` for warnings. No log file is written.

**Validation:** Flag parsing rejects unknown options. Node.js version is validated against the REA-supported ranges (22.19+, 24.15+ on the 24.x line, 26+) by `node_supported` / `Test-NodeSupported`.

**Authentication:** None. The scripts do not hold credentials. Hopper (commercial) and other paid tools are not installed by the scripts and need the user's own licence.

**Dry-run:** Enforced at the `run` / `Invoke-Step` boundary and by explicit `dry_run` checks at direct side-effect sites. Any new side effect must go through one of these or check the flag.

---

*Architecture analysis: 2026-10-14*
