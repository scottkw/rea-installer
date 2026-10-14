# Phase 1: Loud Failures, Safe Dry Run, and Regression Tests - Pattern Map

**Mapped:** 2026-10-14
**Files analyzed:** 6 (3 modified, 3 new)
**Analogs found:** 3 / 6 (the three new files have no in-repo analog)

All analog paths below are git-tracked (`git ls-files` confirmed). Line numbers are from HEAD `d5ac182`.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `rea-install-linux.sh` (modify) | installer script | file-I/O + batch | itself: `fetch` (.part pattern), pwntools `warn` fallback | exact (self) |
| `rea-install-macos.sh` (modify) | installer script | batch | `rea-install-linux.sh` (guard + `|| warn` edits mirrored) | exact (sibling) |
| `rea-install-windows.ps1` (modify) | installer script | file-I/O | itself: `Get-PinnedFile` (.part pattern) | exact (self) |
| `test.sh` (new) | test | batch | none in repo; borrow helper style from `rea-install-linux.sh:47-68` | no analog |
| `.github/workflows/test.yml` (new) | config (CI) | event-driven | none (no `.github/` exists) | no analog |
| `.planning/phases/01-.../01-RED.log` (new) | evidence artifact | n/a | none (captured output of `./test.sh`) | n/a |

## Pattern Assignments

### `rea-install-linux.sh` (installer, file-I/O + batch)

**Helper set to use for every change** (lines 47-68):
```bash
log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

run() {
  printf '  $'; printf ' %q' "$@"; printf '\n'
  [ "$dry_run" = true ] || "$@"
}

record() {
  [ "$dry_run" = true ] && return
  ...
}
```

**Staging model to copy for D-06 — `fetch` .part-then-mv** (lines 218-236):
```bash
    run curl -fsSL --proto '=https' --retry 3 -o "$path.part" "$url" >&2
    if [ "$dry_run" = false ]; then
      if ! printf '%s  %s\n' "$sha" "$path.part" | sha256sum -c - >/dev/null 2>&1; then
        rm -f "$path.part"
        die "checksum mismatch for $(basename "$url"); refusing to use it."
      fi
      mv "$path.part" "$path"
    fi
```

**Target to replace — current `unpack`** (lines 238-249). Replace with RESEARCH Code Example 3 (staging `$TOOLS_DIR/.staging-$2`, `archive="$(fetch "$1")" || exit 1`, `|| { run rm -rf "$staging" >&2; die "could not unpack ..."; }`, all mutations via `run ... >&2` because stdout is the return value):
```bash
unpack() {
  local target="$TOOLS_DIR/$2" archive
  if [ ! -d "$target" ]; then
    archive="$(fetch "$1")"
    case "$archive" in
      *.zip) run unzip -q "$archive" -d "$TOOLS_DIR" >&2 ;;
      *) run tar -xzf "$archive" -C "$TOOLS_DIR" >&2 ;;
    esac
    [ "$dry_run" = true ] || rm -f "$archive"
  fi
  printf '%s\n' "$target"
}
```
Callers outside `unpack` that extract straight into the final dir (Pitfall 7): Rizin lines 408-413 (`run mkdir -p "$rizin_dir"; run tar -xJf ...`), Wakaru lines 441-446. Route through `unpack` or leave as-is per planner decision.

**FAIL-02 — `pkg_install` install lines** (lines 170-177): append `|| return 1` to each `run sudo_cmd ...` arm so `record "pkg:$name ..."` (line 179) is never reached on failure:
```bash
    apt-get)
      run sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$name"
      ;;
    dnf) run sudo_cmd dnf install -y -q "$name" ;;
    pacman) run sudo_cmd pacman -S --needed --noconfirm "$name" ;;
```
Note `pkg_install` already uses `warn ...; return 1` for the unavailable case (lines 165-168) — same style.

**Required vs optional callers (D-08):** required already correct at lines 352-356 (`pkg_install curl || die "curl is required."`). Optional to change from `|| true` → `|| warn "<tool> could not be installed; skipping it."`: lines 400 (adb), 419 (binutils), 428 (tshark), 429 (sigrok-cli), 430 (gdb). Message model is the pwntools fallback (lines 435-439):
```bash
      if make_venv pwntools pwntools==4.15.0 pyelftools==0.33 unicorn==2.1.2; then
        setting REA_PWNTOOLS_PYTHON "$STATE_DIR/venvs/pwntools/bin/python"
      else
        warn "pwntools could not be installed; skipping it."
      fi
```

**DRY-01/02 edit sites:**
- `install_node` lines 292-302: line 294 `sums="$(curl ...)"` runs under dry run; line 297 bare `rm -rf "$STATE_DIR/node"` → `run rm -rf`. Add dry-run early return (RESEARCH Code Example 4).
- `install_jdk` lines 305-318: `curl | node -e` at 312-313 runs under dry run; add `[ "$dry_run" = true ]` → `log "Would download ..."` branch.
- `make_venv` lines 328/330: `uv_dir="$(unpack ...)"` → add `|| return 1`.
- line 487 `elif [ -r /dev/tty ]; then` → `elif (: </dev/tty) 2>/dev/null; then`.
- line 563 `rmdir "$HOME/.agents/skills" "$HOME/.agents" 2>/dev/null || true` → prefix `[ "$dry_run" = true ] ||`. Model is line 566: `[ "$dry_run" = true ] || rm -rf "$STATE_DIR"`.

**UNIN-01** (lines 515-520):
```bash
  if [ -n "$rea_bin" ]; then
    log "Removing REA agent registrations, skills and data"
    run "$rea_bin" uninstall --purge-data
  else
    warn "rea CLI not found; skipping agent deregistration."
```
→ `run "$rea_bin" uninstall --purge-data || warn "rea uninstall failed; remove agent registrations by hand."`

**Source guard (D-01)** — insert after the main banner (line 570), before `cmd="${1:-}"` (line 572). Do not touch the header (usage `sed -n '2,15p'` at line 69):
```bash
# ---------------------------------------------------------------- main

# Sourced (by test.sh): stop here so only the functions are defined. Run or piped into bash: fall through to main.
(return 0 2>/dev/null) && return 0
cmd="${1:-}"
```

---

### `rea-install-macos.sh` (installer, batch)

**Analog:** the Linux edits above; mirror only these (no Linux-only dry-run edits; tty probe is Phase 3 MAC-01).

**FAIL-03 — `brew_install`** (lines 98-108): add `|| return 1` after `run brew install "$@"`:
```bash
brew_install() {
  local kind=brew name="${!#}"
  [ "$1" = --cask ] && kind=cask
  if brew list --versions "$@" >/dev/null 2>&1; then
    log "$name already installed (left as-is)"
  else
    run brew install "$@"
    record "$kind:$name"
  fi
}
```
**UNIN-01** line 260: `run "$rea_bin" uninstall --purge-data` → same `|| warn` as Linux.
**Source guard:** same line after banner at line 318, before `cmd="${1:-}"` at line 320. Bash 3.2 safe. Header/usage range `2,11p` untouched.

---

### `rea-install-windows.ps1` (installer, file-I/O)

**Staging model — `Get-PinnedFile` .part pattern** (lines 115-131):
```powershell
    if ($DryRun) { return $path }
    New-Item -ItemType Directory -Force $ToolsDir | Out-Null
    Invoke-WebRequest -Uri $d.Url -OutFile "$path.part" -UseBasicParsing
    if ((Get-FileHash -Algorithm SHA256 "$path.part").Hash.ToLowerInvariant() -ne $d.Sha) {
        Remove-Item -Force "$path.part"
        throw "Checksum mismatch for $(Split-Path $d.Url -Leaf); refusing to use it."
    }
    Move-Item -Force "$path.part" $path
```
**Target — `Expand-PinnedArchive`** (lines 133-140); replace with RESEARCH Code Example 6 (`.staging-$Folder`, `try/catch` + `Remove-Item` + `throw`):
```powershell
function Expand-PinnedArchive([string]$Key, [string]$Folder) {
    $target = Join-Path $ToolsDir $Folder
    if (Test-Path $target) { return $target }
    $archive = Get-PinnedFile $Key
    Invoke-Step tar @('-xf', $archive, '-C', $ToolsDir) | Out-Null  # keep tar output out of the return value
    if (-not $DryRun) { Remove-Item -Force $archive }
    return $target
}
```
**Throw source** — `Invoke-Step` (lines 51-56) throws on non-zero exit, which is what `catch` relies on:
```powershell
    if ($LASTEXITCODE -ne 0) { throw "$File $($ArgList -join ' ') failed with exit code $LASTEXITCODE" }
```
**UNIN-01** line 236: wrap `Invoke-Step $rea @('uninstall', '--purge-data')` in `try { ... } catch { Warn "rea uninstall failed; remove agent registrations by hand. ($_)" }`. PS 5.1-safe constructs only (Pitfall 11).

---

### `test.sh` (test, batch) — NO IN-REPO ANALOG

No test file exists in the repo. Use RESEARCH.md Code Examples 1, 2, 5, 7 and Patterns 2-3 (`sandbox`, `stub`, `need`, `ok/bad/skip`). Borrow only the style conventions from the installers:
- shebang `#!/bin/bash`, 2-space indent, `printf` for variable data (`rea-install-linux.sh:47-49` helper one-liners are the format model for `ok`/`bad`/`skip`).
- Use `set -u` only, not `set -euo pipefail` (D-11; RESEARCH anti-pattern).
- Inline shellcheck disables with reason, e.g. `# shellcheck disable=SC2016  # expanded by the stub`.
- Must be Bash 3.2 compatible (macOS CI job); commit mode 100755.

### `.github/workflows/test.yml` (CI config, event-driven) — NO IN-REPO ANALOG

No `.github/` directory exists. Use RESEARCH Code Example 8: `on: [push, pull_request]`, jobs `ubuntu-latest` (`./test.sh`) and `macos-latest` (`/bin/bash ./test.sh`), `actions/checkout@v7.0.1`. All logic stays in `test.sh`.

### `01-RED.log` — captured output of `./test.sh` against pre-fix scripts (D-05); no pattern needed.

## Shared Patterns

### Side effects through the wrapper
**Source:** `rea-install-linux.sh:51-54` (`run`), `rea-install-windows.ps1:51-56` (`Invoke-Step`)
**Apply to:** every new mkdir/mv/rm/tar in `unpack`, `install_node`, `Expand-PinnedArchive`. Inside functions whose stdout is a return value (`unpack`, `fetch`), redirect `run ... >&2`. Direct mutations need `[ "$dry_run" = true ] ||` (model: `rea-install-linux.sh:566`).

### Errexit is off in `$(...)`, `f || x`, and `if f`
**Apply to:** `unpack`, `pkg_install`, `brew_install`, `make_venv`, and every `test.sh` sandbox call. Use explicit `|| return 1` / `|| die` / `|| exit 1`; in `test.sh` run `sandbox` as a plain statement then `rc=$?`.

### Failure messages
`die "X is required."` for required (linux:352-356); `warn "<tool> could not be installed; skipping it."` for optional (linux:438); PowerShell `throw "..."` for fatal, `Warn` for recoverable. Sentence case, ending with a period.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `test.sh` | test | batch | Repo has no tests or test framework; use RESEARCH Code Examples 1-2, 5, 7 |
| `.github/workflows/test.yml` | CI config | event-driven | No CI config exists; use RESEARCH Code Example 8 |
| `01-RED.log` | artifact | n/a | Captured output, not code |

## Metadata

**Analog search scope:** repo root (`git ls-files`: 3 installer scripts, README, .planning)
**Files scanned:** 3 scripts
**Pattern extraction date:** 2026-10-14
