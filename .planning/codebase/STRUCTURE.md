---
last_mapped_commit: 894cf00cc8f19f557bdbdee6cab36a3d5d6b5f25
last_mapped_at: 2026-10-14
---
# Codebase Structure

**Analysis Date:** 2026-10-14

## Directory Layout

```
rea-installer/
├── rea-install-macos.sh        # macOS installer (Bash 3.2 compatible, Homebrew)
├── rea-install-linux.sh        # Linux installer (apt / dnf / pacman, Bash)
├── rea-install-windows.ps1     # Windows installer (PowerShell 5.1 / 7, winget)
├── README.md                   # User docs: status, quick start, component matrix, testing
├── LICENSE                     # MIT license
├── .gitignore                  # Ignores /graft/ (local graph cache)
├── .ignore                     # ripgrep config: re-admits graft/ for search
└── .planning/                  # GSD planning artefacts (not part of the installer)
    └── codebase/               # Codebase map documents (this file lives here)
```

There are no source subdirectories, no `tests/`, no `src/`, no build or package manifests. The repository root holds all tracked content. Git tracks 8 files (`git ls-files`).

## Directory Purposes

**`/` (repository root):**
- Purpose: holds the three installer scripts and the documentation they ship with.
- Contains: executable shell and PowerShell scripts, `README.md`, `LICENSE`, ignore files.
- Key files: `rea-install-macos.sh`, `rea-install-linux.sh`, `rea-install-windows.ps1`, `README.md`.

**`.planning/codebase/`:**
- Purpose: output of `/gsd-map-codebase`. Holds analysis documents consumed by planning and execution commands.
- Contains: `ARCHITECTURE.md`, `STRUCTURE.md`, and (from other focus areas) `STACK.md`, `INTEGRATIONS.md`, `CONVENTIONS.md`, `TESTING.md`, `CONCERNS.md`.
- Key files: all of the above once generated.
- Generated: Yes (by the GSD mapper agents).
- Committed: Decided by the orchestrator. Not part of the installer's runtime.

**`.planning/`:**
- Purpose: GSD workflow state for this repo.
- Generated: Yes.
- Committed: Not determined from this mapping pass.

**`graft/` (gitignored, absent from the tracked tree):**
- Purpose: local symbol graph cache for the `graft` MCP tools. Listed in `.gitignore`; `.ignore` re-admits `graft/` for ripgrep searches.
- Generated: Yes (`graft build`).
- Committed: No.

## Key File Locations

**Entry Points:**
- `rea-install-macos.sh`: macOS install and uninstall. Dispatch in the `# ---- main` section at the end of the file.
- `rea-install-linux.sh`: Linux install and uninstall. Dispatch at the end of the file.
- `rea-install-windows.ps1`: Windows install and uninstall. `param(...)` block at the top; `switch ($Command)` at the bottom.

**Configuration (in-script):**
- `rea-install-macos.sh` lines 14–15: `STATE_DIR`, `STATE_FILE` (ledger location).
- `rea-install-linux.sh` lines 17–18: `STATE_DIR`, `STATE_FILE`; lines ~ 20–30: pinned download URLs and SHA-256 digests (`WABT_x64`, `RIZIN_x64`, `UV_x64`/`UV_arm64`, `WAKARU_x64`, and related constants) and default flag variables.
- `rea-install-windows.ps1`: `$StateDir`, `$StateFile`, `$ToolsDir`, `$Package`, `$JdkId`, and the `$Downloads` hashtable (Ghidra, JADX, Apktool, WABT).

**Core Logic:**
- `rea-install-macos.sh`: `do_install` (~148), `do_uninstall` (~246), helpers (~32–146).
- `rea-install-linux.sh`: `do_install` (~339), `do_uninstall` (~503), package-manager abstraction (~85–218), download and unpack (~219–254), Node / JDK / venv installers (~255–338).
- `rea-install-windows.ps1`: `Invoke-Install` (~153), `Invoke-Uninstall` (~222), winget and download helpers (~77–152).

**Documentation:**
- `README.md`: status table, quick start, the three-script comparison, "What gets installed" matrix, options, uninstall, engineering notes, testing, known limitations, attribution.

**Testing:**
- No test files in the repository. Testing is described in the README's "Testing" section and was performed in external container and host runs (Ubuntu 24.04, Fedora 44, Arch Linux containers for Linux; dry runs only for macOS and Windows).

## Naming Conventions

**Files:**
- Scripts: `rea-install-<platform>.<ext>` where `<platform>` is `macos`, `linux`, or `windows`, and `<ext>` is `sh` for Bash or `ps1` for PowerShell.
- Docs: `UPPERCASE.md` (`README.md`) and GSD map files (`ARCHITECTURE.md`, `STRUCTURE.md`, etc.).
- Ignore files: dot-prefixed, no extension (`.gitignore`, `.ignore`).

**Functions (bash):**
- `snake_case`, lowercase. Phase functions prefixed `do_` (`do_install`, `do_uninstall`). Helpers use noun or verb forms: `brew_install`, `pkg_installed`, `remove_profile_block`, `load_nvm`.
- Globals: `snake_case` for flags and runtime state (`dry_run`, `assume_yes`, `with_ghidra`, `pm`); `UPPER_CASE` for constants and paths (`STATE_DIR`, `STATE_FILE`, `WABT_x64`).
- Pinned download constants use `<TOOL>_<arch>` (`x64`, `arm64`).

**Functions (PowerShell):**
- `Verb-Noun` PascalCase (`Invoke-Install`, `Invoke-Step`, `Test-WingetInstalled`, `Get-PinnedFile`, `Set-UserEnv`, `Add-Record`). Output helpers use `Log` and `Warn`.
- Script-scope variables are `$PascalCase` (`$StateFile`, `$ToolsDir`, `$Downloads`).

**Flags:**
- Bash: GNU-style long options (`--dry-run`, `--with-android`, `--no-ghidra`, `--yes`/`-y`).
- PowerShell: switches (`-DryRun`, `-WithAndroid`, `-NoGhidra`, `-Yes`).
- Each flag maps to one variable in the script's parsing loop (`--with-android` sets `with_android=true`; `-WithAndroid` sets `$WithAndroid`).

**Ledger kinds:**
- Lowercase kind, colon, value: `clt`, `homebrew`, `profile:`, `npm:`, `app:`, `hopper:`, `pkg:`, `winget:`, `env:`.

**Directories (runtime, under the user home):**
- `~/.rea-installer/` (ledger and tool downloads). Windows: `%USERPROFILE%\.rea-installer\`.
- `~/.agents/skills` (REA's shared skill folder, removed on Linux uninstall only when empty).

## Where to Add New Code

**New tool or option on one platform:**
- Add the flag to the parse loop in that platform's `# ---- main` section, and a matching global default near the top of the file.
- Add the install step in that platform's `do_install` / `Invoke-Install`, call through `run` / `Invoke-Step`, and call `record` / `Add-Record` with a new or existing `kind:value`.
- Add the matching reverse branch in that platform's `do_uninstall` / `Invoke-Uninstall`.
- Update the matrix in `README.md` ("What gets installed") and the usage text (`usage()` in bash; the `.SYNOPSIS` header comment in PowerShell).

**New tool on all platforms:**
- Implement in each of `rea-install-macos.sh`, `rea-install-linux.sh`, `rea-install-windows.ps1` in the same change. The scripts share no code (see ARCHITECTURE.md), so there is no shared file to edit.

**New pinned download:**
- Bash: add a `NAME_arch="URL SHA256"` constant next to the existing ones in `rea-install-linux.sh`, and use `fetch` then `unpack`.
- PowerShell: add an entry to `$Downloads` in `rea-install-windows.ps1` with `Url` and `Sha`, and read it with `Get-PinnedFile` or `Expand-PinnedArchive`.
- Do not commit a URL without its SHA-256 digest.

**New helper function:**
- Bash: place it under the matching banner section (`# ---- environment`, `# ---- install`, or `# ---- uninstall`) in the script that needs it. Avoid adding to the shared header helpers unless every script needs it.
- PowerShell: place it under the function block above `# ---- main` in the same file.

**Tests:**
- There is no test directory. Verify changes with `--dry-run` / `-DryRun` output review, `bash -n` syntax checks for the `.sh` files, and the container or host runs described in README "Testing".

**Documentation:**
- User-facing changes: `README.md`.
- Codebase maps: `.planning/codebase/` (regenerated by `/gsd-map-codebase`).

## Special Directories

**`.planning/`:**
- Purpose: GSD planning and codebase analysis output.
- Generated: Yes.
- Committed: Not determined from this mapping pass.

**`graft/` (gitignored):**
- Purpose: local symbol graph cache for graft.
- Generated: Yes (`graft build`).
- Committed: No (`.gitignore` contains `/graft/`).

**Runtime state directories (created by the scripts, not in the repo):**
- `~/.rea-installer/`: install ledger (`installed`) and `tools/` on Windows. Removed by uninstall.
- Created on demand inside the user's home by the Linux installer: Node.js tarball install, JDK, Ghidra, WABT, Rizin, uv, Wakaru, and private Python venvs for `--with-linux-tools`.

---

*Structure analysis: 2026-10-14*
