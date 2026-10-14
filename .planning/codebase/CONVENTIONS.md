---
last_mapped_commit: 894cf00cc8f19f557bdbdee6cab36a3d5d6b5f25
last_mapped_at: 2026-10-14
---
# Coding Conventions

**Analysis Date:** 2026-10-14

## Scope

The repository is four tracked source files, all installer scripts. There is no application code, no package manifest and no linter config checked in:

- `rea-install-macos.sh` (Bash 3.2 compatible, macOS)
- `rea-install-linux.sh` (Bash, apt/dnf/pacman)
- `rea-install-windows.ps1` (Windows PowerShell 5.1 / PowerShell 7)
- `README.md`, `LICENSE`, `.gitignore`, `.ignore`

The global project instructions in `/Users/ken/dev/CLAUDE.md` cover Python, Go and JS/TS only. For this repo, the conventions below are the ones the existing scripts actually follow. Keep new code consistent with them.

## Naming Patterns

**Files:**
- Installer scripts: `rea-install-<platform>.<ext>` (`rea-install-macos.sh`, `rea-install-linux.sh`, `rea-install-windows.ps1`). Keep the `rea-install-` prefix and the platform suffix for any new platform.
- Documentation: UPPERCASE for generated docs under `.planning/codebase/`, `README.md` for the user-facing doc.

**Bash functions:**
- `snake_case`, verb-first: `load_brew`, `load_nvm`, `node_supported`, `brew_install`, `install_jdk`, `install_jadx_jar`, `remove_profile_block`, `pkg_install`, `pkg_available`, `apt_update_once`, `make_venv`.
- Top-level command handlers are `do_install` and `do_uninstall`. Predicates return status (`node_supported`, `pkg_installed`, `pkg_set_removable`) and are not used for output.
- Helper prefixes group related functions: `pkg_*` (Linux package-manager abstraction), `brew_*` (macOS), `install_*` (installs a single tool), `fetch`/`unpack` (downloads).

**Bash variables:**
- Script constants and configuration: `UPPER_SNAKE_CASE`, e.g. `STATE_DIR`, `STATE_FILE`, `PACKAGE`, `JDK_FORMULA`, `JADX_URL`, `JADX_SHA256`, `PROFILE_BEGIN`, `GHIDRA`, `WABT_x64`, `WABT_arm64`.
  - Exception: pinned download specs use mixed case with an architecture suffix (`WABT_x64`, `RIZIN_x64`, `UV_arm64`, `WAKARU_x64`). Keep this pattern for per-arch pins.
- Mutable runtime state: `lower_snake_case` booleans stored as the strings `true`/`false`: `assume_yes`, `dry_run`, `with_ghidra`, `with_android`, `with_extras`, `with_linux_tools`. Test them with `[ "$dry_run" = true ]`, never with bare truthiness.
- Arrays and accumulators: `profile_exports` (macOS), `profile_lines` (Linux).
- Always declare function locals with `local`, e.g. `local kind=brew name="${!#}"`.

**PowerShell:**
- Functions use approved `Verb-Noun` PascalCase: `Invoke-Install`, `Invoke-Uninstall`, `Invoke-Step`, `Get-PinnedFile`, `Expand-PinnedArchive`, `Set-UserEnv`, `Test-NodeSupported`, `Test-WingetInstalled`, `Add-Record`, `Confirm-Step`, `Update-SessionPath`, `Install-Jdk`.
  - Existing exceptions: `Log` and `Warn` are not approved verbs. They exist as thin wrappers around `Write-Host` and `Write-Warning`. Do not add more non-standard names; prefer `Write-Host` directly for new code.
- Script parameters are PascalCase switches and params: `-NoGhidra`, `-WithAndroid`, `-WithExtras`, `-Yes`, `-DryRun`.
- Script-scope configuration is `$PascalCase`: `$StateDir`, `$StateFile`, `$ToolsDir`, `$Package`, `$JdkId`, `$Downloads`.
- Local variables are `$camelCase`: `$hostArch`, `$isArm64`, `$launcher`, `$candidate`.

**Command-line options:**
- Bash: long options in kebab-case with a matching short form only for `--yes|-y` and `--help|-h`: `--dry-run`, `--no-ghidra`, `--with-android`, `--with-extras`, `--with-linux-tools`.
- PowerShell: PascalCase switches that map one-to-one onto the Bash flags (`--with-android` -> `-WithAndroid`). Keep this mapping when adding a flag, and add the flag to all three scripts plus the README "Options" table.

## Code Style

**Bash formatting:**
- Indent with 2 spaces. No tabs.
- Shebang `#!/bin/bash` (not `/bin/sh`). Every script begins with `set -euo pipefail` right after the header comment.
- Use `[[ ... ]]` for string and regex tests (`[[ "$reply" =~ ^[Yy] ]]`). Use `[ ... ]` for simple POSIX-style tests and `(( ... ))` for integer arithmetic.
- Use `$(...)` for command substitution. Quote every expansion (`"$HOME"`, `"$STATE_FILE"`).
- Put one-line `case` arms and short guards on a single line: `[ "$1" = --cask ] && kind=cask`, `command -v node >/dev/null 2>&1 || return 1`.
- Use `printf` rather than `echo` for anything that prints variable data (`printf '%s\n' "$line"`).
- Long-line `curl` and `jq`-style pipelines may continue with a trailing `\`, indented 2 extra spaces.
- Section headers use a banner comment line of the form `# ---------------------------------------------------------------- <name>` to separate `environment`, `install`, `uninstall`, `main`. Maintain this structure: helpers above, `do_install`/`do_uninstall` in the middle, argument parsing and the `case "$cmd"` dispatch at the bottom.

**PowerShell formatting:**
- Indent with 4 spaces. Opening braces on the same line as the statement, `} else {` style.
- Begin with `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`, and `$ProgressPreference = 'SilentlyContinue'`. Keep all three.
- Use single-quoted strings for literals and double-quoted only for interpolation (`"==> $Message"`, `"$Package@latest"`).
- Use `@(...)` for array literals passed to native commands (`Invoke-Step winget @('install', '--id', $Id, ...)`).
- Use `[version]`, `-match`, and `-notin` for comparisons, not string-based checks.
- Use `[Environment]::GetEnvironmentVariable(...)` for persistent user/machine variables.

**Linting:**
- No linter configuration is tracked. The macOS and Linux scripts are checked with `shellcheck`, and the README documents `bash -n` and `shellcheck` under `/bin/bash` 3.2 for macOS.
- Where a `shellcheck` rule is intentionally violated, annotate the line inline with a reason, matching the existing pattern:
  ```bash
  # shellcheck disable=SC1090
  . "$f"
  ```
  ```bash
  # shellcheck disable=SC2016  # $JAVA_HOME and $@ expand when the launcher runs
  printf '#!/bin/sh\nexec "${JAVA_HOME:-%s}/bin/java" -jar "%s" "$@"\n' ...
  ```
- Do not add a blanket `shellcheck disable` at the top of a file.

## Import Organization

Not applicable. There are no imports or modules. External dependencies are invoked as commands:
- Bash: `brew`, `npm`, `curl`, `uv`, `dpkg-query`, `rpm`, `pacman`, `apt-get`, `dnf`, `shasum` or `sha256sum`.
- PowerShell: `winget`, `npm`, `tar`, `Invoke-WebRequest`, `Get-FileHash`.

When adding a new external command, check for it with `command -v` before use, using the same pattern as the existing code (`command -v node >/dev/null 2>&1`).

## Error Handling

**Fatal errors:**
- Bash: call `die "message"`, which prints `error: message` to stderr and exits 1. Example: `die "this script supports macOS only."`.
- PowerShell: `throw "message"`, usually with a specific cause (`throw "Checksum mismatch for $(Split-Path $d.Url -Leaf); refusing to use it."`). Do not use `Write-Error` for fatal paths.

**Non-fatal problems:**
- Bash: call `warn "message"`, which prints `warning: message` to stderr. Continue execution when the step is optional.
- PowerShell: call `Warn` (the wrapper for `Write-Warning`).

**External command failures:**
- Bash: rely on `set -e`, but wrap optional steps with `|| true` or an explicit fallback. Examples: `pkg_install adb || true`, `pkg_install tshark || true`. Where a fallback exists, follow it with a `warn` so the skip is visible (`warn "pwntools could not be installed; skipping it."`).
- PowerShell: `Invoke-Step` runs a native command and throws when `$LASTEXITCODE -ne 0`. Use `Invoke-Step` for any command whose failure should stop the install, and call the native command directly only when its exit code is intentionally checked (`winget list ... *> $null; $LASTEXITCODE -eq 0`).

**Integrity checks (mandatory for downloads):**
- Every non-package-manager download is verified against a pinned SHA-256 before use:
  - Bash: `printf '%s  %s\n' "$sha" "$path.part" | sha256sum -c -` (Linux) or `shasum -a 256 -c -` (macOS).
  - PowerShell: `(Get-FileHash -Algorithm SHA256 ...).Hash.ToLowerInvariant() -ne $d.Sha`.
- On mismatch, delete the `.part` file and stop. Never keep an unverified file.
- Download to `"$path.part"`, then `mv` to the final name only after verification. This keeps a failed download from being mistaken for a complete one on rerun.

**Dry run:**
- All side effects must go through the `run` helper (Bash) or `Invoke-Step` (PowerShell), which print the command and skip execution under `--dry-run`/`-DryRun`. Writes to the state file go through `record`/`Add-Record`, which also honor dry run.
- Do not call a mutating command directly (`brew install`, `npm install`, `rm -rf`) outside these wrappers, unless guarded by an explicit `[ "$dry_run" = true ] ||` check (as the final `rm -rf "$STATE_DIR"` in uninstall is). Known violations to fix: `rm -rf "$STATE_DIR/node"` in Linux `install_node` and `rmdir ~/.agents/skills ~/.agents` in Linux `do_uninstall` (`.planning/AUDIT.md` HARD-03, HARD-12).

**Idempotency and the ledger:**
- Before installing, check whether the tool is already present (`brew list --versions`, `pkg_installed`, `Test-WingetInstalled`, `command -v`). If present, log `"<name> already installed (left as-is)"` and do not record it.
- Record only what the script adds, in `~/.rea-installer/installed` (`STATE_FILE`). Entry formats are prefix-typed: `brew:NAME`, `cask:NAME`, `pkg:NAME DEP...`, `npm:PATH`, `profile:PATH`, `app:PATH`, `hopper:OWNER`, `winget:ID`, `env:NAME`. Add a new kind by adding a new prefix and a matching arm in `do_uninstall`.
- Uninstall reads the ledger in reverse order (`tail -r` on macOS, `tac` on Linux, `[array]::Reverse` on Windows) so dependencies are removed after their dependents.

**Silent-failure caution:**
- Several sites suppress errors with `2>/dev/null` and then fall back with `|| true` or `|| echo ""`, for example in `hopper_apps`, `pkg_owner`, `rmdir "$HOME/.agents/skills" ... || true`, and the `npm_bin` / `rea_bin` lookups. These are acceptable where absence is an expected state. Do not add new `|| true` on steps that are required for the install to be correct. Make them fail loudly instead.

## Logging

**Bash:**
- `log "message"` prints `==> message` to stdout. Use for step headers and progress.
- `warn "message"` prints `warning: message` to stderr. Use for recoverable issues.
- `die "message"` prints `error: message` to stderr and exits 1.
- `run cmd args...` prints the command as `  $ cmd args` (quoted with `printf %q`) before executing it. This is the only way the user sees what is about to change.

**PowerShell:**
- `Log "message"` prints `==> message` via `Write-Host`.
- `Warn "message"` prints via `Write-Warning`.
- `Invoke-Step` prints `  > File args` before executing.
- Use `Write-Host` for plain output; avoid `Write-Output` for user-facing text, because it pollutes return values. The existing code adds `| Out-Null` and comments such as `# keep tar output out of the return value` where a function returns a value.

**Rules:**
- Do not print secrets, tokens or full environment dumps.
- Do not add `echo`-based debug output to committed code.

## Comments

**When to comment:**
- Explain the reason for a non-obvious choice, especially version pins, platform quirks and reasons for avoiding a default. The existing comments do this well, for example:
  - `# Pinned by REA: docs/android-analysis.md` next to `JADX_URL`.
  - `# Homebrew's binutils is keg-only and macOS's objdump is LLVM's, so point REA at GNU's.`
  - `# --assumeno always exits non-zero, so read its plan rather than its status.`
- Put the rationale in the comment, not a description of what the next line does. The line already shows what it does.
- Reference the upstream source when a value is pinned (REA docs path, release URL, `SHASUMS256.txt`).

**Header comments:**
- Each script starts with a usage block, then the option list, then a paragraph describing the ledger. `usage()` prints this block by slicing the file with `sed -n '2,N p' "$0"`, so keep the header comment in the expected position and length (see Function Design).
- The Windows script uses a `<# ... #>` comment-based help block. Keep `.SYNOPSIS`-style text inside it; the `default` case of the main `switch` prints the first 15 lines.

**Inline TODOs:** none exist. Do not add a `TODO` without an issue reference.

## Function Design

**Size:**
- Keep helpers small and single-purpose. The longest functions are `do_install` (macOS ~95 lines, Linux ~160 lines) and `do_uninstall`. When adding a new tool, add a dedicated `install_<tool>` function and call it from `do_install`, rather than growing the body inline. The existing Linux `do_install` blocks are numbered (`# 1. Base tools`, `# 2. Node.js + npm`, ...) and new steps should follow that numbering.

**Parameters:**
- Bash: take positional parameters and read them with `local name="$1"`. For variadic commands, use `"$@"` and pass through `run`. Use `shift` before reading extra arguments (`make_venv` does this).
- PowerShell: use `[CmdletBinding()]`/`param()` only at script scope. Helper functions take typed positional parameters: `function Set-UserEnv([string]$Name, [string]$Value)`.

**Return values:**
- Bash: functions print their result on stdout for command substitution (`path="$(fetch "$1")"`, `hopper_apps`), and return status for predicates. Do not mix both in one function.
- PowerShell: functions return the last expression or use `return $value` explicitly. Suppress unwanted pipeline output with `| Out-Null` or `*> $null`.

**Usage text:**
- Both Bash scripts build `usage()` from the header comment with a hard-coded line range: `sed -n '2,11p'` (macOS) and `sed -n '2,15p'` (Linux). When you change the header, update the range, or better, make the range computed from the header end marker. Keep this in mind on any header edit.

## Module Design

**Script structure:**
- Each script is self-contained and runs top-to-bottom. There is no sourcing between the scripts, and no shared library file. Logic that is duplicated across the three scripts (logging, `record`, `confirm`, `run`, `setting`) is intentionally repeated so each script can be copied and run on its own. Do not introduce a shared module without a deliberate decision to change this.

**Main dispatch:**
- End each Bash script with a `case "$cmd" in install) ...; uninstall) ...; -h|--help|"") usage ;; *) die ... ;; esac` block, as the existing scripts do.
- The argument loop is a `while (($# > 0))` with a `case "$1"` that maps each flag to a `*_flag=true` variable and calls `die "unknown option: $1"` on unknowns.
- PowerShell uses `switch ($Command)` with a `default` that prints the help header.

**Exports and variables:**
- Bash: export a setting for `rea setup` with `setting NAME VALUE` (Linux), which both exports it for the current run and queues it for the shell profile. macOS uses `export NAME=...` directly plus `profile_exports+=(...)`.
- PowerShell: persistent environment settings go through `Set-UserEnv`. It skips when the value is already set, and warns and leaves a different existing value unchanged.

**Platform differences to keep in mind:**
- Shell profile: macOS writes `~/.zshrc` for zsh and `~/.bash_profile` otherwise. Linux writes `~/.zshrc` for zsh and `~/.bashrc` otherwise. Do not assume they match when changing profile handling.
- `sed -i` takes an empty-string argument on macOS (`sed -i ''`) and none on Linux (`sed -i`). Keep the two forms in their own scripts.
- `tail -r` (macOS) versus `tac` (Linux) for reverse ordering.

## Language and Style Notes

- Commit messages are short imperative sentences in sentence case, with no prefix or scope: `Add MIT license`, `Harden Linux installer from container testing`, `Support Windows on ARM64`. Follow this format.
- User-facing text uses sentence case and ends with a period, e.g. `"Done. Open a new terminal, restart your agent(s), then check health with: ..."`.
- Prompts use `[y/N]` with `N` as the default. The default must remain "no" for any destructive action.

---

*Convention analysis: 2026-10-14*
