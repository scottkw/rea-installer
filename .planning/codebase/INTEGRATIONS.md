---
last_mapped_commit: 894cf00cc8f19f557bdbdee6cab36a3d5d6b5f25
last_mapped_at: 2026-10-14
---
# External Integrations

**Analysis Date:** 2026-10-14

This repository has no runtime integrations of its own: no database, no auth provider, no webhook receiver, no telemetry. Its integrations are the network endpoints and package sources that the three installer scripts contact when they run on a user's machine, plus the agent and tool registrations they hand off to REA.

## APIs & External Services

**REA (the product being installed):**
- REA - MCP server and CLI for AI coding agents. Upstream: https://github.com/morluto/rea and https://rea.tools/
  - Install channel: npm package `rea-agents`, always `@latest`
  - Scripts: `rea-install-macos.sh` (`PACKAGE` line 16), `rea-install-linux.sh` (`PACKAGE` line 21), `rea-install-windows.ps1` (`$Package` line 33)
  - Post-install: `rea setup` (interactive, or `rea setup --yes --all-detected` when `--yes` / `-Yes` is passed). Registers REA with detected agents (Claude Code, Codex, Cursor, Gemini CLI and others, per README).
  - Uninstall: `rea uninstall --purge-data`
  - Auth: None

**npm registry:**
- Used for `npm install --global rea-agents@latest`
  - macOS: `rea-install-macos.sh` line ~222
  - Linux: `rea-install-linux.sh` line ~460 (`--prefix "$HOME/.local"`)
  - Windows: `rea-install-windows.ps1` line ~207
- Auth: None (public package)

**Node.js distribution:**
- `https://nodejs.org/dist/latest-v24.x` - Node.js 24 LTS tarball, used on Linux only when no supported Node is present (`install_node`, `rea-install-linux.sh` ~line 292)
  - Integrity: tarball checked against `SHASUMS256.txt` from the same host
- Windows Node.js comes from winget `OpenJS.NodeJS.LTS`; macOS from Homebrew `node`

**Adoptium (Eclipse Temurin JDK 21):**
- `https://api.adoptium.net/v3/assets/latest/21/hotspot?...` - queried on Linux to resolve the JDK 21 download URL and checksum (`rea-install-linux.sh` ~line 312), then the tarball is fetched and verified against the checksum returned by that API
- Windows uses winget `EclipseAdoptium.Temurin.21.JDK`; macOS uses Homebrew `openjdk@21`

**Homebrew:**
- `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh` - installs Homebrew if absent (`rea-install-macos.sh` line ~162)
- `https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh` - removes Homebrew on uninstall, only if the script installed it (line ~307)
- Formulas and casks used: `node`, `ghidra`, `openjdk@21`, `apktool`, `rizin`, `binutils`, `wabt`, cask `android-platform-tools`
- Note: the Homebrew install and uninstall scripts are fetched and executed with `bash -c "$(curl ...)"` with no pinned checksum. This is a deliberate upstream-trust choice, and not the only unverified remote code: `rea-agents@latest` from npm (installed and then executed by `rea setup`), Homebrew/winget/distribution packages, and the Linux PyPI installs (pinned by version, not by hash) are also trusted without a pinned checksum. Only the GitHub release assets and the Node.js/Temurin archives are checksum-verified.

**Microsoft winget:**
- Package source for Windows system components (`winget install --id ... --exact --silent`), see `rea-install-windows.ps1` lines 84-95 and 260-263 for uninstall

**Python packages via uv (Linux only):**
- uv 0.12.21 binary from GitHub (see GitHub Releases below), then `uv venv --python 3.12` and `uv pip install --python <venv>` with pinned versions:
  - `pwntools==4.15.0`, `pyelftools==0.33`, `unicorn==2.1.2` (x64 only for pwntools; `--with-linux-tools`)
  - `mitmproxy==12.2.3` (`--with-linux-tools`)
- Python package index: PyPI, reached through uv (not pinned to a mirror)
- Python 3.12 interpreters are downloaded by uv into `~/.rea-installer/python` (`UV_PYTHON_INSTALL_DIR`)

**Linux distribution package managers:**
- apt (`apt-get`), dnf, and pacman. Package names are installed with `sudo` (`pkg_install` in `rea-install-linux.sh`). Only the distributions' default repositories are used.

## GitHub Release Downloads

All downloads below are pinned by version and by SHA-256. The scripts refuse a file whose checksum differs (`fetch` in `rea-install-linux.sh` ~line 218 uses `sha256sum -c`; `rea-install-windows.ps1` line 124 uses `Get-FileHash`; `rea-install-macos.sh` line 138 uses `shasum -a 256 -c`).

| Artifact | Version | Source URL host | Used by | Verified in |
|---|---|---|---|---|
| Ghidra | 12.1.4 (build 20260921) | github.com/NationalSecurityAgency/ghidra | Linux (x64 only for decompiler), Windows (x64) | `rea-install-linux.sh` line 27, `rea-install-windows.ps1` line 38 |
| JADX headless (`jadx-headless-mcp`) | 0.7.1 | github.com/1013503897/jadx-headless-mcp | macOS, Linux, Windows | `rea-install-macos.sh` lines 19-20, `rea-install-linux.sh` line 28, `rea-install-windows.ps1` line 40 |
| Apktool | 3.0.3 | github.com/iBotPeaches/Apktool | Linux, Windows (macOS uses Homebrew) | `rea-install-linux.sh` line 29, `rea-install-windows.ps1` line 42 |
| WABT | 1.0.42 | github.com/WebAssembly/wabt | Linux (x64, arm64), Windows (x64) | `rea-install-linux.sh` lines 30-31, `rea-install-windows.ps1` line 44 |
| Rizin | 0.9.1 (static build) | github.com/rizinorg/rizin | Linux x64 when `--with-extras` | `rea-install-linux.sh` line 32 |
| uv | 0.12.21 | github.com/astral-sh/uv | Linux (x64, arm64) | `rea-install-linux.sh` lines 33-34 |
| Wakaru | 1.14.0 | github.com/pionxzh/wakaru | Linux x64 when `--with-linux-tools` | `rea-install-linux.sh` line 35 |

## Data Storage

**Databases:**
- None. The installer does not store data in a database.
- REA's own data (`~/.rea`) is created by REA and removed by `rea uninstall --purge-data`. It is not managed by this repository.

**File Storage:**
- Local filesystem only. The scripts use:
  - `~/.rea-installer/` (`STATE_DIR` in macOS and Linux scripts): downloads, JDK, Node.js, Python venvs, uv cache, and the `installed` ledger file (`STATE_FILE`)
  - Windows: the state directory is `$StateDir` in `rea-install-windows.ps1`, and downloads go under the same root
  - Shell profile, chosen by `$SHELL` on both platforms: zsh → `${ZDOTDIR:-$HOME}/.zshrc`; otherwise `~/.bash_profile` (macOS) or `~/.bashrc` (Linux). The settings live inside a marked block delimited by `# >>> rea-installer >>>` and `# <<< rea-installer <<<`
  - Windows: user environment variables, not a file

**Caching:**
- None in the repository. Linux sets `UV_CACHE_DIR` to `~/.rea-installer/uv-cache` so uv's cache is removed with the state directory.

## Authentication & Identity

**Auth Provider:**
- Not applicable. The scripts do not authenticate to any service. All downloads are anonymous public HTTPS. No tokens, API keys, or credentials are read, stored, or required.

**Credentials:**
- None are read. The repository contains no `.env`, `.npmrc`, `.netrc`, or key files.

## Agent Registrations (Handoff to REA)

The scripts do not talk to agents directly. They invoke REA's own setup, which writes registrations into each detected agent's configuration:
- Agents named in README: Claude Code, Codex, Cursor, Gemini CLI, and others
- Triggered by: `rea setup` (macOS, Linux, Windows) and `rea setup --yes --all-detected` when `--yes` / `-Yes` is passed
- REA also installs its own skill files; `rea uninstall --purge-data` removes registrations and skill files
- Hopper (commercial, optional): REA's setup may offer to install it on macOS and Linux. The Linux launcher path is `/opt/hopper/bin/Hopper` (`HOPPER_LAUNCHER`, `rea-install-linux.sh` line 26)

## Monitoring & Observability

**Error Tracking:**
- None

**Logs:**
- Console output only. `--dry-run` / `-DryRun` prints each command without running it (`run` helper, `Invoke-Step` in the Windows script).
- Install ledger at `~/.rea-installer/installed` is used for uninstall, not for observability.

## CI/CD & Deployment

**Hosting:**
- GitHub: source at https://github.com/scottkw/rea-installer (issue link in `README.md`). The repository has no `.github/` directory, so no workflows are committed.

**CI Pipeline:**
- None committed. Testing is manual, per `README.md` "Testing" section (container runs on Linux; dry runs on macOS and Windows).

**Distribution:**
- Scripts are distributed by cloning this repository. No package, installer binary, or signed artifact is produced.

## Environment Configuration

**Required env vars (set by the scripts, not required by them):**
- `JAVA_HOME` - JDK 21 location for Ghidra, JADX, Apktool
- `REA_JADX_MCP_JAR`, `REA_APKTOOL_COMMAND`, `REA_RIZIN_COMMAND`, `REA_WABT_BIN_DIRECTORY`, `REA_OBJDUMP_COMMAND`, `REA_TSHARK_COMMAND`, `REA_CAPINFOS_COMMAND`, `REA_SIGROK_COMMAND`, `REA_PWNTOOLS_PYTHON`, `REA_WAKARU_COMMAND`, `REA_MITMDUMP_COMMAND` - locations REA reads to find its tools
- `GHIDRA_INSTALL_DIR` - honoured on Windows if already set (left as-is)
- `NVM_DIR` - honoured on macOS and Linux when locating an existing nvm-managed Node
- `PATH` - prepended with the npm prefix and the script-managed Node.js when needed
- `UV_PYTHON_INSTALL_DIR`, `UV_CACHE_DIR` - set by the Linux script to keep uv's data under `~/.rea-installer`
- `DEBIAN_FRONTEND=noninteractive` - set for apt installs on Linux

**Secrets location:**
- Not applicable. The repository holds no secrets. Users are not asked for credentials.

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None. The scripts make only outbound HTTPS GETs for downloads, plus package-manager calls. They do not POST telemetry or user data.

---

*Integration audit: 2026-10-14*
