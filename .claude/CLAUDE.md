<!-- GSD:project-start source:PROJECT.md -->

## Project

**rea-installer**

Three standalone installer scripts — `rea-install-linux.sh`, `rea-install-macos.sh`, `rea-install-windows.ps1` — that install REA (Reverse Engineer Anything) and the caller-supplied tools it uses (Node.js, Ghidra, a JDK, JADX, Apktool, adb, Rizin, objdump, WABT and Linux-only capture tools) with one command per platform. Everything they add is recorded in a ledger so `uninstall` removes exactly that and leaves pre-existing tools alone. Unofficial community project for people who want REA working with their AI coding agents without reading two dozen setup pages.

**Core Value:** Installing and uninstalling must never leave the user's machine in a silently broken or altered state: a failure stops loudly, a rerun recovers, and uninstall removes only what the script added.

### Constraints

- **Compatibility**: `rea-install-macos.sh` must run on macOS's Bash 3.2 (no `mapfile`, no associative arrays) — system shell on every Mac
- **Compatibility**: `rea-install-linux.sh` may use Bash 4+; Windows script must work on PowerShell 5.1 and 7
- **Distribution**: each script stays a single self-contained file — users run it via `curl | bash` or a single download
- **Safety**: dry-run must not change anything; uninstall must not remove anything the script didn't add
- **Testing**: CI can only exercise Linux containers, shellcheck, and PowerShell parsing — no real macOS/Windows installs in CI

<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Languages

- Bash - `rea-install-macos.sh` (Bash 3.2 compatible, the macOS default), `rea-install-linux.sh` (Bash, `set -euo pipefail`)
- PowerShell - `rea-install-windows.ps1` (Windows PowerShell 5.1 and PowerShell 7)
- Markdown - `README.md` (user documentation, status table, option reference)
- None of the other languages appear in the repo. The installer drives Python (via `uv`) and Node.js only indirectly, by installing packages for other tools.

## Runtime

- This repository is not an application. It is a set of installer scripts that run on the end user's machine.
- macOS: system Bash 3.2 plus Homebrew (`brew`), installed on demand.
- Linux: Bash plus one of `apt-get`, `dnf`, or `pacman` (detected at runtime, `rea-install-linux.sh` ~line 99).
- Windows: Windows PowerShell 5.1 or PowerShell 7, plus `winget` (App Installer), which the script requires (`rea-install-windows.ps1` ~line 160).
- Node.js 22.19+, 24.11+, or 26+ per the README. The scripts require 24.15+ on the 24.x line, because REA's SQLite analysis needs it.
- Linux installs Node.js 24.x from `https://nodejs.org/dist/latest-v24.x` into `~/.rea-installer/node` when no supported Node is present (`install_node` in `rea-install-linux.sh` ~line 292).
- Python 3.12, provisioned by `uv` into `~/.rea-installer/python` for the pwntools and mitmproxy venvs (`make_venv` in `rea-install-linux.sh` ~line 324).
- Homebrew - macOS system packages (`brew_install` in `rea-install-macos.sh`). Formulas: `node`, `ghidra`, `openjdk@21`, `apktool`, `rizin`, `binutils`, `wabt`. Cask: `android-platform-tools`.
- apt / dnf / pacman - Linux system packages (`pkg_install` in `rea-install-linux.sh`, ~lines 160-205). Package names are mapped per manager (e.g. `ps` maps to `procps` on apt, `adb` to `adb`, `tshark` to `tshark`).
- winget - Windows system packages (`rea-install-windows.ps1` ~lines 84-95). Confirmed IDs: `OpenJS.NodeJS.LTS` (Node.js) and `EclipseAdoptium.Temurin.21.JDK` (JDK 21). Other `-WithExtras` and `-WithAndroid` components are installed through winget or GitHub downloads; see the script for the exact list.
- npm - installs the REA CLI package `rea-agents@latest` globally (`rea-install-macos.sh` line ~222, `rea-install-linux.sh` line ~460 with `--prefix ~/.local`, `rea-install-windows.ps1` line ~207).
- uv 0.12.21 - pinned Python tool manager, downloaded as a tarball on Linux (`UV_x64` / `UV_arm64` in `rea-install-linux.sh` lines 33-34). Installs Python 3.12 and pinned Python packages into private venvs.
- Lockfile: Not applicable. Versions are pinned inline in the scripts, not in a lockfile.

## Frameworks

- None. No application framework is used. The scripts are plain shell and PowerShell.
- No automated test framework is present. Verification is manual: `--dry-run` / `-DryRun` output inspection, lint, and container runs (Ubuntu 24.04, Fedora 44, Arch Linux) as described in `README.md` ("Testing" and "Status" sections).
- Linting is referenced in `README.md` ("lint and dry runs pass") but no lint config (e.g. ShellCheck or PSScriptAnalyzer config file) is committed.
- None. There is no build step. Scripts are executed directly (`./rea-install-macos.sh`, `powershell -File .\rea-install-windows.ps1`).

## Key Dependencies

- `rea-agents` (npm) - the REA CLI and MCP server, `@latest`. Source: https://www.npmjs.com/package/rea-agents
- Ghidra 12.1.4 (build 20260921) - native binary analysis. Linux and Windows fetch the GitHub release zip with a pinned SHA-256; macOS uses Homebrew `ghidra`.
- JDK 21 - Eclipse Temurin on Linux and Windows, Homebrew `openjdk@21` on macOS. Used by Ghidra and JADX.
- JADX headless (`jadx-headless-mcp` 0.7.1 all-in-one jar) - Android APK decompilation. Pinned SHA-256.
- Apktool 3.0.3 - Android resources and manifests. Pinned SHA-256 on Linux and Windows; Homebrew on macOS.
- Android platform-tools (adb) - device and emulator access. Homebrew cask on macOS, distro package on Linux, winget or GitHub on Windows.
- Rizin 0.9.1 - offline native analysis. Linux x64 static build pinned with SHA-256, otherwise distro package or Homebrew.
- GNU binutils objdump - offline native analysis. Homebrew `binutils` on macOS (keg-only, set via `REA_OBJDUMP_COMMAND`).
- WABT 1.0.42 - WebAssembly tooling. Pinned archives on Linux (x64, arm64) and Windows (x64); Homebrew on macOS.
- Wakaru 1.14.0 - JavaScript bundle recovery. Linux x64 only, pinned SHA-256.
- `pwntools==4.15.0`, `pyelftools==0.33`, `unicorn==2.1.2` - ELF layout and recorded crash analysis (x64 only for pwntools).
- `mitmproxy==12.2.3` - native mitmproxy captures.
- TShark and capinfos, sigrok-cli, GDB - distro packages.
- `curl`, `unzip`, `xz`, `procps` (`ps`), `util-linux` (`prlimit`) - Linux base tools, installed if missing.
- Xcode Command Line Tools - macOS prerequisite for Homebrew and REA's process-capture helper (`swiftc`).
- `sha256sum` (Linux), `shasum -a 256` (macOS, JADX jar), and `Get-FileHash -Algorithm SHA256` (Windows) - used to verify every pinned download before use.
- Hopper - not installed by the scripts. `rea setup` offers it on macOS and Linux. Launcher path is `/opt/hopper/bin/Hopper` on Linux (`HOPPER_LAUNCHER` in `rea-install-linux.sh` line 26).

## Configuration

- The scripts write persistent environment settings, not read them from a file:
- Install state is recorded in `~/.rea-installer/installed` (`STATE_FILE` in `rea-install-macos.sh` line 15 and `rea-install-linux.sh`). Windows records in `$StateDir`. Each line is a record such as `brew:<name>`, `cask:<name>`, `npm:<path>`, `pkg:<name> <deps...>`, `winget:<id>`, `env:<name>`, `homebrew`.
- Downloaded artifacts live in `~/.rea-installer` (`STATE_DIR` on macOS and Linux) and are removed by `uninstall`.
- No `.env` file, `.nvmrc`, or `.python-version` file exists in the repository. Environment files were not read or quoted.
- Not applicable. No build config files (no `package.json`, `pyproject.toml`, `Makefile`, `.github/workflows`) are present.
- macOS: `PACKAGE`, `JDK_FORMULA`, `JADX_URL`, `JADX_SHA256` at the top of `rea-install-macos.sh`.
- Linux: `PACKAGE`, `NPM_PREFIX`, `GHIDRA`, `JADX`, `APKTOOL`, `WABT_x64`, `WABT_arm64`, `RIZIN_x64`, `UV_x64`, `UV_arm64`, `WAKARU_x64` at lines 16-35 of `rea-install-linux.sh`.
- Windows: `$Package`, `$JdkId`, and `$Downloads` hashtable at the top of `rea-install-windows.ps1` (lines 33-45).

## Platform Requirements

- Bash, not a generic POSIX shell (`[[ ]]`, arrays, `<<<`, `${!v}`, `compgen`). `rea-install-macos.sh` must stay Bash 3.2 compatible; `rea-install-linux.sh` uses `mapfile` and needs Bash 4+. Running either with `sh` (dash on Ubuntu) fails.
- Windows PowerShell 5.1 or PowerShell 7 for `rea-install-windows.ps1`.
- Linux x64 or arm64 with apt, dnf, or pacman. Container testing used Ubuntu 24.04, Fedora 44, and Arch Linux.
- macOS on Apple silicon or Intel. Windows 10+ on x64 or ARM64 (the README says Ghidra and JADX are x64-only on Windows).
- Target machine is a developer workstation. The installer modifies the user's shell profile or user environment, installs system packages with `sudo` (Linux), `brew` (macOS), or `winget` (Windows), and installs REA into the user's npm global prefix.
- Status by platform (from `README.md`): Linux is tested end to end in containers; macOS and Windows are dry-run only.

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## Scope

- `rea-install-macos.sh` (Bash 3.2 compatible, macOS)
- `rea-install-linux.sh` (Bash, apt/dnf/pacman)
- `rea-install-windows.ps1` (Windows PowerShell 5.1 / PowerShell 7)
- `README.md`, `LICENSE`, `.gitignore`, `.ignore`

## Naming Patterns

- Installer scripts: `rea-install-<platform>.<ext>` (`rea-install-macos.sh`, `rea-install-linux.sh`, `rea-install-windows.ps1`). Keep the `rea-install-` prefix and the platform suffix for any new platform.
- Documentation: UPPERCASE for generated docs under `.planning/codebase/`, `README.md` for the user-facing doc.
- `snake_case`, verb-first: `load_brew`, `load_nvm`, `node_supported`, `brew_install`, `install_jdk`, `install_jadx_jar`, `remove_profile_block`, `pkg_install`, `pkg_available`, `apt_update_once`, `make_venv`.
- Top-level command handlers are `do_install` and `do_uninstall`. Predicates return status (`node_supported`, `pkg_installed`, `pkg_set_removable`) and are not used for output.
- Helper prefixes group related functions: `pkg_*` (Linux package-manager abstraction), `brew_*` (macOS), `install_*` (installs a single tool), `fetch`/`unpack` (downloads).
- Script constants and configuration: `UPPER_SNAKE_CASE`, e.g. `STATE_DIR`, `STATE_FILE`, `PACKAGE`, `JDK_FORMULA`, `JADX_URL`, `JADX_SHA256`, `PROFILE_BEGIN`, `GHIDRA`, `WABT_x64`, `WABT_arm64`.
- Mutable runtime state: `lower_snake_case` booleans stored as the strings `true`/`false`: `assume_yes`, `dry_run`, `with_ghidra`, `with_android`, `with_extras`, `with_linux_tools`. Test them with `[ "$dry_run" = true ]`, never with bare truthiness.
- Arrays and accumulators: `profile_exports` (macOS), `profile_lines` (Linux).
- Always declare function locals with `local`, e.g. `local kind=brew name="${!#}"`.
- Functions use approved `Verb-Noun` PascalCase: `Invoke-Install`, `Invoke-Uninstall`, `Invoke-Step`, `Get-PinnedFile`, `Expand-PinnedArchive`, `Set-UserEnv`, `Test-NodeSupported`, `Test-WingetInstalled`, `Add-Record`, `Confirm-Step`, `Update-SessionPath`, `Install-Jdk`.
- Script parameters are PascalCase switches and params: `-NoGhidra`, `-WithAndroid`, `-WithExtras`, `-Yes`, `-DryRun`.
- Script-scope configuration is `$PascalCase`: `$StateDir`, `$StateFile`, `$ToolsDir`, `$Package`, `$JdkId`, `$Downloads`.
- Local variables are `$camelCase`: `$hostArch`, `$isArm64`, `$launcher`, `$candidate`.
- Bash: long options in kebab-case with a matching short form only for `--yes|-y` and `--help|-h`: `--dry-run`, `--no-ghidra`, `--with-android`, `--with-extras`, `--with-linux-tools`.
- PowerShell: PascalCase switches that map one-to-one onto the Bash flags (`--with-android` -> `-WithAndroid`). Keep this mapping when adding a flag, and add the flag to all three scripts plus the README "Options" table.

## Code Style

- Indent with 2 spaces. No tabs.
- Shebang `#!/bin/bash` (not `/bin/sh`). Every script begins with `set -euo pipefail` right after the header comment.
- Use `[[ ... ]]` for string and regex tests (`[[ "$reply" =~ ^[Yy] ]]`). Use `[ ... ]` for simple POSIX-style tests and `(( ... ))` for integer arithmetic.
- Use `$(...)` for command substitution. Quote every expansion (`"$HOME"`, `"$STATE_FILE"`).
- Put one-line `case` arms and short guards on a single line: `[ "$1" = --cask ] && kind=cask`, `command -v node >/dev/null 2>&1 || return 1`.
- Use `printf` rather than `echo` for anything that prints variable data (`printf '%s\n' "$line"`).
- Long-line `curl` and `jq`-style pipelines may continue with a trailing `\`, indented 2 extra spaces.
- Section headers use a banner comment line of the form `# ---------------------------------------------------------------- <name>` to separate `environment`, `install`, `uninstall`, `main`. Maintain this structure: helpers above, `do_install`/`do_uninstall` in the middle, argument parsing and the `case "$cmd"` dispatch at the bottom.
- Indent with 4 spaces. Opening braces on the same line as the statement, `} else {` style.
- Begin with `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`, and `$ProgressPreference = 'SilentlyContinue'`. Keep all three.
- Use single-quoted strings for literals and double-quoted only for interpolation (`"==> $Message"`, `"$Package@latest"`).
- Use `@(...)` for array literals passed to native commands (`Invoke-Step winget @('install', '--id', $Id, ...)`).
- Use `[version]`, `-match`, and `-notin` for comparisons, not string-based checks.
- Use `[Environment]::GetEnvironmentVariable(...)` for persistent user/machine variables.
- No linter configuration is tracked. The macOS and Linux scripts are checked with `shellcheck`, and the README documents `bash -n` and `shellcheck` under `/bin/bash` 3.2 for macOS.
- Where a `shellcheck` rule is intentionally violated, annotate the line inline with a reason, matching the existing pattern:
- Do not add a blanket `shellcheck disable` at the top of a file.

## Import Organization

- Bash: `brew`, `npm`, `curl`, `uv`, `dpkg-query`, `rpm`, `pacman`, `apt-get`, `dnf`, `shasum` or `sha256sum`.
- PowerShell: `winget`, `npm`, `tar`, `Invoke-WebRequest`, `Get-FileHash`.

## Error Handling

- Bash: call `die "message"`, which prints `error: message` to stderr and exits 1. Example: `die "this script supports macOS only."`.
- PowerShell: `throw "message"`, usually with a specific cause (`throw "Checksum mismatch for $(Split-Path $d.Url -Leaf); refusing to use it."`). Do not use `Write-Error` for fatal paths.
- Bash: call `warn "message"`, which prints `warning: message` to stderr. Continue execution when the step is optional.
- PowerShell: call `Warn` (the wrapper for `Write-Warning`).
- Bash: rely on `set -e`, but wrap optional steps with `|| true` or an explicit fallback. Examples: `pkg_install adb || true`, `pkg_install tshark || true`. Where a fallback exists, follow it with a `warn` so the skip is visible (`warn "pwntools could not be installed; skipping it."`).
- PowerShell: `Invoke-Step` runs a native command and throws when `$LASTEXITCODE -ne 0`. Use `Invoke-Step` for any command whose failure should stop the install, and call the native command directly only when its exit code is intentionally checked (`winget list ... *> $null; $LASTEXITCODE -eq 0`).
- Every non-package-manager download is verified against a pinned SHA-256 before use:
- On mismatch, delete the `.part` file and stop. Never keep an unverified file.
- Download to `"$path.part"`, then `mv` to the final name only after verification. This keeps a failed download from being mistaken for a complete one on rerun.
- All side effects must go through the `run` helper (Bash) or `Invoke-Step` (PowerShell), which print the command and skip execution under `--dry-run`/`-DryRun`. Writes to the state file go through `record`/`Add-Record`, which also honor dry run.
- Do not call a mutating command directly (`brew install`, `npm install`, `rm -rf`) outside these wrappers, unless guarded by an explicit `[ "$dry_run" = true ] ||` check (as the final `rm -rf "$STATE_DIR"` in uninstall is). Known violations to fix: `rm -rf "$STATE_DIR/node"` in Linux `install_node` and `rmdir ~/.agents/skills ~/.agents` in Linux `do_uninstall` (`.planning/AUDIT.md` HARD-03, HARD-12).
- Before installing, check whether the tool is already present (`brew list --versions`, `pkg_installed`, `Test-WingetInstalled`, `command -v`). If present, log `"<name> already installed (left as-is)"` and do not record it.
- Record only what the script adds, in `~/.rea-installer/installed` (`STATE_FILE`). Entry formats are prefix-typed: `brew:NAME`, `cask:NAME`, `pkg:NAME DEP...`, `npm:PATH`, `profile:PATH`, `app:PATH`, `hopper:OWNER`, `winget:ID`, `env:NAME`. Add a new kind by adding a new prefix and a matching arm in `do_uninstall`.
- Uninstall reads the ledger in reverse order (`tail -r` on macOS, `tac` on Linux, `[array]::Reverse` on Windows) so dependencies are removed after their dependents.
- Several sites suppress errors with `2>/dev/null` and then fall back with `|| true` or `|| echo ""`, for example in `hopper_apps`, `pkg_owner`, `rmdir "$HOME/.agents/skills" ... || true`, and the `npm_bin` / `rea_bin` lookups. These are acceptable where absence is an expected state. Do not add new `|| true` on steps that are required for the install to be correct. Make them fail loudly instead.

## Logging

- `log "message"` prints `==> message` to stdout. Use for step headers and progress.
- `warn "message"` prints `warning: message` to stderr. Use for recoverable issues.
- `die "message"` prints `error: message` to stderr and exits 1.
- `run cmd args...` prints the command as `  $ cmd args` (quoted with `printf %q`) before executing it. This is the only way the user sees what is about to change.
- `Log "message"` prints `==> message` via `Write-Host`.
- `Warn "message"` prints via `Write-Warning`.
- `Invoke-Step` prints `  > File args` before executing.
- Use `Write-Host` for plain output; avoid `Write-Output` for user-facing text, because it pollutes return values. The existing code adds `| Out-Null` and comments such as `# keep tar output out of the return value` where a function returns a value.
- Do not print secrets, tokens or full environment dumps.
- Do not add `echo`-based debug output to committed code.

## Comments

- Explain the reason for a non-obvious choice, especially version pins, platform quirks and reasons for avoiding a default. The existing comments do this well, for example:
- Put the rationale in the comment, not a description of what the next line does. The line already shows what it does.
- Reference the upstream source when a value is pinned (REA docs path, release URL, `SHASUMS256.txt`).
- Each script starts with a usage block, then the option list, then a paragraph describing the ledger. `usage()` prints this block by slicing the file with `sed -n '2,N p' "$0"`, so keep the header comment in the expected position and length (see Function Design).
- The Windows script uses a `<# ... #>` comment-based help block. Keep `.SYNOPSIS`-style text inside it; the `default` case of the main `switch` prints the first 15 lines.

## Function Design

- Keep helpers small and single-purpose. The longest functions are `do_install` (macOS ~95 lines, Linux ~160 lines) and `do_uninstall`. When adding a new tool, add a dedicated `install_<tool>` function and call it from `do_install`, rather than growing the body inline. The existing Linux `do_install` blocks are numbered (`# 1. Base tools`, `# 2. Node.js + npm`, ...) and new steps should follow that numbering.
- Bash: take positional parameters and read them with `local name="$1"`. For variadic commands, use `"$@"` and pass through `run`. Use `shift` before reading extra arguments (`make_venv` does this).
- PowerShell: use `[CmdletBinding()]`/`param()` only at script scope. Helper functions take typed positional parameters: `function Set-UserEnv([string]$Name, [string]$Value)`.
- Bash: functions print their result on stdout for command substitution (`path="$(fetch "$1")"`, `hopper_apps`), and return status for predicates. Do not mix both in one function.
- PowerShell: functions return the last expression or use `return $value` explicitly. Suppress unwanted pipeline output with `| Out-Null` or `*> $null`.
- Both Bash scripts build `usage()` from the header comment with a hard-coded line range: `sed -n '2,11p'` (macOS) and `sed -n '2,15p'` (Linux). When you change the header, update the range, or better, make the range computed from the header end marker. Keep this in mind on any header edit.

## Module Design

- Each script is self-contained and runs top-to-bottom. There is no sourcing between the scripts, and no shared library file. Logic that is duplicated across the three scripts (logging, `record`, `confirm`, `run`, `setting`) is intentionally repeated so each script can be copied and run on its own. Do not introduce a shared module without a deliberate decision to change this.
- End each Bash script with a `case "$cmd" in install) ...; uninstall) ...; -h|--help|"") usage ;; *) die ... ;; esac` block, as the existing scripts do.
- The argument loop is a `while (($# > 0))` with a `case "$1"` that maps each flag to a `*_flag=true` variable and calls `die "unknown option: $1"` on unknowns.
- PowerShell uses `switch ($Command)` with a `default` that prints the help header.
- Bash: export a setting for `rea setup` with `setting NAME VALUE` (Linux), which both exports it for the current run and queues it for the shell profile. macOS uses `export NAME=...` directly plus `profile_exports+=(...)`.
- PowerShell: persistent environment settings go through `Set-UserEnv`. It skips when the value is already set, and warns and leaves a different existing value unchanged.
- Shell profile: macOS writes `~/.zshrc` for zsh and `~/.bash_profile` otherwise. Linux writes `~/.zshrc` for zsh and `~/.bashrc` otherwise. Do not assume they match when changing profile handling.
- `sed -i` takes an empty-string argument on macOS (`sed -i ''`) and none on Linux (`sed -i`). Keep the two forms in their own scripts.
- `tail -r` (macOS) versus `tac` (Linux) for reverse ordering.

## Language and Style Notes

- Commit messages are short imperative sentences in sentence case, with no prefix or scope: `Add MIT license`, `Harden Linux installer from container testing`, `Support Windows on ARM64`. Follow this format.
- User-facing text uses sentence case and ends with a period, e.g. `"Done. Open a new terminal, restart your agent(s), then check health with: ..."`.
- Prompts use `[y/N]` with `N` as the default. The default must remain "no" for any destructive action.

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## System Overview

```text

```

## Pattern Overview

- Three platform implementations that mirror one another: `rea-install-macos.sh` (340 lines), `rea-install-linux.sh` (593 lines), `rea-install-windows.ps1` (280 lines). Behaviour is intended to match across platforms (same subcommands, same flags where applicable, same ordering of steps).
- Two subcommands only: `install` and `uninstall`. Anything else prints usage or fails with `die`.
- Every mutation is routed through a single wrapper (`run` in bash, `Invoke-Step` in PowerShell), so `--dry-run` / `-DryRun` prints the command instead of running it.
- Every change that uninstall must reverse is appended to a ledger via `record` (bash) or `Add-Record` (PowerShell). Uninstall reads the ledger in reverse (`tac` on Linux, `tail -r` on macOS, `[array]::Reverse` in PowerShell) and removes only recorded items.
- No third-party code is linked in. Dependencies are fetched at runtime: distribution packages, Homebrew, winget, npm, or GitHub release assets pinned by URL and SHA-256 digest.
- Idempotence is by checking, not by state: `pkg_installed`, `brew_install`, `Test-WingetInstalled`, and "already present" checks skip work already done, and `record` deduplicates lines with `grep -qxF`.

## Layers

- Purpose: logging, error exit, command execution with dry-run, ledger write, confirmation prompt.
- Location: top of each script. macOS `rea-install-macos.sh` lines ~32–55 (`log`, `warn`, `die`, `run`, `record`, `confirm`, `usage`). Linux `rea-install-linux.sh` lines ~47–70 (same set plus `setting`, `tool_setting`, `arch`, `sudo_cmd`). Windows `rea-install-windows.ps1` lines ~48–70 (`Log`, `Warn`, `Invoke-Step`, `Add-Record`, `Confirm-Step`).
- Depends on: nothing beyond the shell.
- Used by: every phase function.
- Purpose: find existing tools and decide what to install or skip.
- macOS: `load_brew`, `load_nvm`, `node_supported`, `profile_file`, `hopper_apps` (`rea-install-macos.sh` ~58–118).
- Linux: `detect_pm` (apt, dnf, pacman), `check_pacman_synced`, `pkg_name`, `pkg_installed`, `pkg_available`, `pkg_list`, `pkg_owner`, `arch`, `load_nvm`, `node_supported`, `profile_file` (`rea-install-linux.sh` ~85–290). Package names are looked up per package manager through `pkg_name`.
- Windows: `Update-SessionPath`, `Test-NodeSupported`, `Test-WingetInstalled`, and ARM64 detection via `$isArm64` in `Invoke-Install`.
- Depends on: helpers layer.
- Used by: install and uninstall phases.
- Purpose: fetch and verify external artifacts.
- Linux: `fetch` (`rea-install-linux.sh` ~219) and `unpack` (~239) handle pinned downloads. Pins are declared at the top of the file as `NAME_arch="URL SHA256"` strings (e.g. `WABT_x64`, `RIZIN_x64`, `UV_arm64`, `WAKARU_x64`).
- Windows: `$Downloads` hashtable at the top of `rea-install-windows.ps1` (keys `ghidra`, `jadx`, `apktool`, `wabt`, each with `Url` and `Sha`), read by `Get-PinnedFile` (~115) and `Expand-PinnedArchive` (~133).
- macOS: `brew_install` (~99) for Homebrew formulae and casks; the JADX jar is fetched by `install_jadx_jar` (~130).
- Depends on: helpers, environment layers.
- Used by: install phase.
- Purpose: perform the install in a fixed order.
- Location: macOS `do_install` (`rea-install-macos.sh` ~148–242); Linux `do_install` (~339–502) with helpers `install_node` (~292), `install_jdk` (~305), `make_venv` (~324); Windows `Invoke-Install` (`rea-install-windows.ps1` ~153–220) with `Install-Jdk` (~144).
- Depends on: all lower layers.
- Used by: main dispatch.
- Purpose: reverse the ledger.
- Location: macOS `do_uninstall` (`rea-install-macos.sh` ~246–316); Linux `do_uninstall` (~503–~575); Windows `Invoke-Uninstall` (`rea-install-windows.ps1` ~222–272).
- Behaviour: reads `~/.rea-installer/installed`, processes entries in reverse, and dispatches on the `kind:` prefix (`clt`, `homebrew`, `brew`, `cask`, `profile`, `npm`, `app`, `pkg`, `hopper`, `env`, `winget`). Calls `rea uninstall --purge-data` (Windows, ~236) to let REA clean its own data first, then removes the ledger directory.
- Depends on: ledger file and helpers.
- Purpose: parse flags and route to a phase.
- Location: the `# ---- main` section at the bottom of each script (macOS ~318–340; Linux ~ 540–593; Windows ~274–280 via `param(...)` and `switch`).
- Depends on: install and uninstall phases.

## Data Flow

### Primary Install Path (all platforms, same order)

### Ledger Format

- Path: `~/.rea-installer/installed` (`STATE_FILE` in `rea-install-macos.sh:15` and `rea-install-linux.sh:18`; `$StateFile` in `rea-install-windows.ps1`).
- Format: one `kind:value` record per line. Records are deduplicated on write.
- Known kinds: `clt`, `homebrew`, `brew:<formula>`, `cask:<cask>`, `profile:<path>`, `npm:<path>`, `app:<name>`, `hopper:<owner>`, `pkg:<name> <added packages>`, `winget:<id>`, `env:<name>`.
- Non-state artefacts go under `~/.rea-installer/tools` (Windows: `$ToolsDir`; Linux and macOS write downloads and venvs under the same directory tree).

### Uninstall Path

- All persistent state is the ledger file plus the files it points to. There is no in-memory state between runs; each invocation re-derives everything from the environment and the ledger.
- Process-level flags (`assume_yes`, `dry_run`, `with_*`, `pm`, `apt_updated`) are globals set during argument parsing. On Linux, `apt_updated` ensures `apt-get update` runs at most once per invocation.

## Key Abstractions

- Purpose: the only mechanism for uninstall to know what was added.
- Examples: `rea-install-macos.sh` (`record` ~41), `rea-install-linux.sh` (`record` ~56), `rea-install-windows.ps1` (`Add-Record` ~58).
- Pattern: append-only, deduplicated, `kind:value` text. Uninstall branches on `kind`.
- Purpose: single choke point for side effects.
- Examples: `rea-install-macos.sh` (`run` ~36); `rea-install-windows.ps1` (`Invoke-Step` ~51).
- Pattern: print the command with shell quoting (`printf ' %q'`), then execute unless dry-run. Code that bypasses it (direct `rm -rf`, `SetEnvironmentVariable`) must check `dry_run`/`$DryRun` itself; e.g. `[ "$dry_run" = true ] || rm -rf "$STATE_DIR"`.
- Purpose: reproducible downloads with integrity check.
- Examples: `UV_x64`, `WAKARU_x64` strings at the top of `rea-install-linux.sh`; `$Downloads` in `rea-install-windows.ps1`.
- Pattern: URL and SHA-256 are declared together; version bumps change both.
- Purpose: map one logical tool to the distro-specific package name for apt, dnf, or pacman.
- Example: `rea-install-linux.sh` ~112.

## Entry Points

- Location: `/Users/ken/dev/rea-installer/rea-install-macos.sh`
- Triggers: `./rea-install-macos.sh install|uninstall [flags]`
- Responsibilities: macOS (Apple silicon and Intel) install via Homebrew and npm; Bash 3.2 compatible (noted in README).
- Location: `/Users/ken/dev/rea-installer/rea-install-linux.sh`
- Triggers: `./rea-install-linux.sh install|uninstall [flags]`
- Responsibilities: Linux x64 and arm64 on apt, dnf, or pacman systems; distro packages plus pinned downloads into the home directory; optional Linux-only tooling via `--with-linux-tools`.
- Location: `/Users/ken/dev/rea-installer/rea-install-windows.ps1`
- Triggers: `powershell -ExecutionPolicy Bypass -File .\rea-install-windows.ps1 install|uninstall [-Switches]`
- Responsibilities: Windows 10+ x64 and ARM64; winget plus pinned GitHub downloads; `-WithAndroid`, `-WithExtras`, `-NoGhidra`, `-Yes`, `-DryRun`.
- Not executable. Serves as the user contract: component matrix, option reference, testing status.

## Architectural Constraints

- **Threading:** Single-threaded, sequential. No parallel downloads or installs.
- **Global state:** Script-level globals in each file (`assume_yes`, `dry_run`, `with_ghidra`, `with_android`, `with_extras`, `with_linux_tools`, `profile_lines`, `pm`, `apt_updated` in `rea-install-linux.sh`; equivalent `$Downloads`, `$StateDir`, `$StateFile`, `$ToolsDir`, `$Package`, `$JdkId` in `rea-install-windows.ps1`). They are set once during argument parsing or at file load and treated as read-only afterwards, except `apt_updated`, `profile_lines`, and `pm`, which are updated as the run proceeds.
- **Shell compatibility:** `rea-install-macos.sh` must run on Bash 3.2 (macOS default). Avoid Bash 4+ features such as associative arrays and `mapfile` there. `rea-install-linux.sh` uses `mapfile` and needs Bash 4+.
- **Strict mode:** Both bash scripts run `set -euo pipefail`. Note that bash turns `set -e` off inside `$(...)` and inside any function called on the left of `||`/`&&` or in an `if` condition, so failures there are not caught (see `.planning/AUDIT.md` HARD-01/02). The Windows script sets `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'` at the top.
- **Elevation:** Linux uses `sudo_cmd`, which skips `sudo` when already root. Windows and macOS Homebrew install paths do not elevate by themselves.
- **No shared code:** The three scripts duplicate helper logic (`log`/`Log`, `run`/`Invoke-Step`, `record`/`Add-Record`, `confirm`/`Confirm-Step`, `load_nvm`, `node_supported`, `profile_file`, `remove_profile_block` appear in both bash files). Changes to ledger format or safety behaviour must be applied to each script by hand.
- **Ledger coupling:** Uninstall depends on exact `kind:value` strings written by install. Renaming a kind in one phase without updating the matching uninstall branch leaves stale installs.
- **Pinned versions:** Versions and digests are hard-coded in the scripts and in the README matrix; they must be updated together.

## Anti-Patterns

### Duplicated helper logic across the bash scripts

### Uninstall that trusts the ledger without re-checking

### Plain `sed -n` usage text parsing

## Error Handling

- Argument validation with `die "unknown option: $1"` and `die "unknown command: $cmd (use install or uninstall)"`.
- Warnings with `warn` (stderr) for recoverable conditions, such as an existing tool that is left as-is.
- External commands are checked with `command -v` / `Get-Command` before use.
- Downloads are verified against pinned SHA-256 digests before unpacking (Linux `fetch`, Windows `Get-PinnedFile`).
- Interactive prompts read from `/dev/tty` in bash (`confirm`) so they still work when stdin is piped; `--yes` bypasses prompts.

## Cross-Cutting Concerns

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-fast` for a trivial task inline, with no subagents and no PLAN.md
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
