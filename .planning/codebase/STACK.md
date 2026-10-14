---
last_mapped_commit: 894cf00cc8f19f557bdbdee6cab36a3d5d6b5f25
last_mapped_at: 2026-10-14
---
# Technology Stack

**Analysis Date:** 2026-10-14

## Languages

**Primary:**
- Bash - `rea-install-macos.sh` (Bash 3.2 compatible, the macOS default), `rea-install-linux.sh` (Bash, `set -euo pipefail`)
- PowerShell - `rea-install-windows.ps1` (Windows PowerShell 5.1 and PowerShell 7)

**Secondary:**
- Markdown - `README.md` (user documentation, status table, option reference)
- None of the other languages appear in the repo. The installer drives Python (via `uv`) and Node.js only indirectly, by installing packages for other tools.

## Runtime

**Environment:**
- This repository is not an application. It is a set of installer scripts that run on the end user's machine.
- macOS: system Bash 3.2 plus Homebrew (`brew`), installed on demand.
- Linux: Bash plus one of `apt-get`, `dnf`, or `pacman` (detected at runtime, `rea-install-linux.sh` ~line 99).
- Windows: Windows PowerShell 5.1 or PowerShell 7, plus `winget` (App Installer), which the script requires (`rea-install-windows.ps1` ~line 160).

**Target runtime for the installed product (REA):**
- Node.js 22.19+, 24.11+, or 26+ per the README. The scripts require 24.15+ on the 24.x line, because REA's SQLite analysis needs it.
- Linux installs Node.js 24.x from `https://nodejs.org/dist/latest-v24.x` into `~/.rea-installer/node` when no supported Node is present (`install_node` in `rea-install-linux.sh` ~line 292).
- Python 3.12, provisioned by `uv` into `~/.rea-installer/python` for the pwntools and mitmproxy venvs (`make_venv` in `rea-install-linux.sh` ~line 324).

**Package Managers:**
- Homebrew - macOS system packages (`brew_install` in `rea-install-macos.sh`). Formulas: `node`, `ghidra`, `openjdk@21`, `apktool`, `rizin`, `binutils`, `wabt`. Cask: `android-platform-tools`.
- apt / dnf / pacman - Linux system packages (`pkg_install` in `rea-install-linux.sh`, ~lines 160-205). Package names are mapped per manager (e.g. `ps` maps to `procps` on apt, `adb` to `adb`, `tshark` to `tshark`).
- winget - Windows system packages (`rea-install-windows.ps1` ~lines 84-95). Confirmed IDs: `OpenJS.NodeJS.LTS` (Node.js) and `EclipseAdoptium.Temurin.21.JDK` (JDK 21). Other `-WithExtras` and `-WithAndroid` components are installed through winget or GitHub downloads; see the script for the exact list.
- npm - installs the REA CLI package `rea-agents@latest` globally (`rea-install-macos.sh` line ~222, `rea-install-linux.sh` line ~460 with `--prefix ~/.local`, `rea-install-windows.ps1` line ~207).
- uv 0.12.21 - pinned Python tool manager, downloaded as a tarball on Linux (`UV_x64` / `UV_arm64` in `rea-install-linux.sh` lines 33-34). Installs Python 3.12 and pinned Python packages into private venvs.
- Lockfile: Not applicable. Versions are pinned inline in the scripts, not in a lockfile.

## Frameworks

**Core:**
- None. No application framework is used. The scripts are plain shell and PowerShell.

**Testing:**
- No automated test framework is present. Verification is manual: `--dry-run` / `-DryRun` output inspection, lint, and container runs (Ubuntu 24.04, Fedora 44, Arch Linux) as described in `README.md` ("Testing" and "Status" sections).
- Linting is referenced in `README.md` ("lint and dry runs pass") but no lint config (e.g. ShellCheck or PSScriptAnalyzer config file) is committed.

**Build/Dev:**
- None. There is no build step. Scripts are executed directly (`./rea-install-macos.sh`, `powershell -File .\rea-install-windows.ps1`).

## Key Dependencies

All of the following are downloaded or installed by the scripts at run time. None are vendored in this repository.

**Installed product (REA and its consumers):**
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

**Linux-only Python packages (private venvs under `~/.rea-installer/venvs`, installed via `uv pip install`):**
- `pwntools==4.15.0`, `pyelftools==0.33`, `unicorn==2.1.2` - ELF layout and recorded crash analysis (x64 only for pwntools).
- `mitmproxy==12.2.3` - native mitmproxy captures.

**Linux-only capture tools (`--with-linux-tools`):**
- TShark and capinfos, sigrok-cli, GDB - distro packages.

**Infrastructure and helpers used by the scripts:**
- `curl`, `unzip`, `xz`, `procps` (`ps`), `util-linux` (`prlimit`) - Linux base tools, installed if missing.
- Xcode Command Line Tools - macOS prerequisite for Homebrew and REA's process-capture helper (`swiftc`).
- `sha256sum` (Linux), `shasum -a 256` (macOS, JADX jar), and `Get-FileHash -Algorithm SHA256` (Windows) - used to verify every pinned download before use.

**Optional commercial tool:**
- Hopper - not installed by the scripts. `rea setup` offers it on macOS and Linux. Launcher path is `/opt/hopper/bin/Hopper` on Linux (`HOPPER_LAUNCHER` in `rea-install-linux.sh` line 26).

## Configuration

**Environment:**
- The scripts write persistent environment settings, not read them from a file:
  - macOS and Linux: a marked block in the shell profile (file chosen by `$SHELL`: zsh → `~/.zshrc`, otherwise `~/.bash_profile` on macOS or `~/.bashrc` on Linux; block delimited by `PROFILE_BEGIN` / `PROFILE_END`, `rea-install-macos.sh` lines 22-23 and `rea-install-linux.sh` lines 22-23). macOS exports only `JAVA_HOME`, `REA_OBJDUMP_COMMAND` and `REA_WABT_BIN_DIRECTORY` (`REA_JADX_MCP_JAR` is exported for the run only, not persisted). Linux exports `JAVA_HOME`, `PATH` additions for the npm prefix and Node, `GHIDRA_INSTALL_DIR`, `REA_JADX_MCP_JAR`, `REA_APKTOOL_COMMAND`, `REA_RIZIN_COMMAND`, `REA_WABT_BIN_DIRECTORY`, `REA_TSHARK_COMMAND`, `REA_CAPINFOS_COMMAND`, `REA_SIGROK_COMMAND`, `REA_PWNTOOLS_PYTHON`, `REA_WAKARU_COMMAND`, `REA_MITMDUMP_COMMAND` (not `REA_OBJDUMP_COMMAND`; objdump is found on `PATH`).
  - Windows: user-scope environment variables set through `[Environment]::SetEnvironmentVariable`, with the same `REA_*` names where applicable (`rea-install-windows.ps1` lines 99-111, 189-202).
- Install state is recorded in `~/.rea-installer/installed` (`STATE_FILE` in `rea-install-macos.sh` line 15 and `rea-install-linux.sh`). Windows records in `$StateDir`. Each line is a record such as `brew:<name>`, `cask:<name>`, `npm:<path>`, `pkg:<name> <deps...>`, `winget:<id>`, `env:<name>`, `homebrew`.
- Downloaded artifacts live in `~/.rea-installer` (`STATE_DIR` on macOS and Linux) and are removed by `uninstall`.
- No `.env` file, `.nvmrc`, or `.python-version` file exists in the repository. Environment files were not read or quoted.

**Build:**
- Not applicable. No build config files (no `package.json`, `pyproject.toml`, `Makefile`, `.github/workflows`) are present.

**Version pins (single source of truth is the script constants):**
- macOS: `PACKAGE`, `JDK_FORMULA`, `JADX_URL`, `JADX_SHA256` at the top of `rea-install-macos.sh`.
- Linux: `PACKAGE`, `NPM_PREFIX`, `GHIDRA`, `JADX`, `APKTOOL`, `WABT_x64`, `WABT_arm64`, `RIZIN_x64`, `UV_x64`, `UV_arm64`, `WAKARU_x64` at lines 16-35 of `rea-install-linux.sh`.
- Windows: `$Package`, `$JdkId`, and `$Downloads` hashtable at the top of `rea-install-windows.ps1` (lines 33-45).

## Platform Requirements

**Development (to edit or run the scripts):**
- Bash, not a generic POSIX shell (`[[ ]]`, arrays, `<<<`, `${!v}`, `compgen`). `rea-install-macos.sh` must stay Bash 3.2 compatible; `rea-install-linux.sh` uses `mapfile` and needs Bash 4+. Running either with `sh` (dash on Ubuntu) fails.
- Windows PowerShell 5.1 or PowerShell 7 for `rea-install-windows.ps1`.
- Linux x64 or arm64 with apt, dnf, or pacman. Container testing used Ubuntu 24.04, Fedora 44, and Arch Linux.
- macOS on Apple silicon or Intel. Windows 10+ on x64 or ARM64 (the README says Ghidra and JADX are x64-only on Windows).

**Production (where the installer runs and what it produces):**
- Target machine is a developer workstation. The installer modifies the user's shell profile or user environment, installs system packages with `sudo` (Linux), `brew` (macOS), or `winget` (Windows), and installs REA into the user's npm global prefix.
- Status by platform (from `README.md`): Linux is tested end to end in containers; macOS and Windows are dry-run only.

---

*Stack analysis: 2026-10-14*
