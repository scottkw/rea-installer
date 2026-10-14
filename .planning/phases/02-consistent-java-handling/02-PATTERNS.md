# Phase 2: Consistent Java Handling - Pattern Map

**Mapped:** 2026-10-14
**Files analyzed:** 4 (all modified, none created)
**Analogs found:** 4 / 4 (all in-repo, tracked)

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `rea-install-linux.sh` | installer (predicate + install step) | request-response (env probe -> decide -> persist) | `node_supported` (:275-282), `setting` (:71-75), `install_jdk` (:318-336) | exact |
| `rea-install-macos.sh` | installer (predicate + install step + profile write) | same | `node_supported` (:82-89), step 7 profile block (:207-219), `install_jdk` (:123-129) | exact |
| `rea-install-windows.ps1` | installer (predicate + install step) | same | `Test-NodeSupported` (:76-81), `Set-UserEnv` (:100-112), `Install-Jdk` (:160-167) | exact |
| `test.sh` | test | batch (table tests + pwsh driver) | TEST-03 `node_supported` table (:110-119), pwsh driver (:264-314), `stub`/`sandbox` (:25-39) | exact |

## Pattern Assignments

### `rea-install-linux.sh` and `rea-install-macos.sh`: new `jdk_usable DIR`

**Analog:** `node_supported` (linux :275-282, macos :82-89, identical text). Place `jdk_usable` right after it.
```bash
# REA requires Node.js 22.x (>=22.19), 24.x (>=24.11), or 26+; SQLite analysis needs 24.15+.
node_supported() {
  command -v node >/dev/null 2>&1 || return 1
  local major minor
  IFS=. read -r major minor _ <<<"$(node -p 'process.versions.node' 2>/dev/null)"
  [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || return 1
  ((major == 22 && minor >= 19 || major == 24 && minor >= 15 || major >= 26))
}
```
Copy: rationale comment above, `|| return 1` guards, `local` vars, final arithmetic `((...))` as the status. Use the body from RESEARCH Code Example 1 (regex in a variable, `${BASH_REMATCH[3]:-0}`, Bash 3.2 safe). Callers only in `if`/`||`/`&&` (as in `if node_supported; then` at linux :377, macos :170).

**Post-install self-check analog** (linux :382, macos :176):
```bash
[ "$dry_run" = true ] || node_supported || die "downloaded Node.js is still unsupported."
```
Mirror as `[ "$dry_run" = true ] || jdk_usable "$STATE_DIR/jdk" || die "..."` (Pitfall 10, optional).

### `rea-install-linux.sh`: `install_jdk` (:318-336)

**Persistence analog:** `setting` (:71-75), unchanged, already called at :335.
```bash
setting() {
  export "$1=$2"
  profile_lines+=("export $1=\"$2\"")
}
```
**Rerun reset** (:361-365) already unsets `$STATE_DIR/*` values, so the new first guard `if [ "${JAVA_HOME:-}" = "$STATE_DIR/jdk" ]; then return; fi` can only match this run's value (Pitfall 1). Then replace `[ -n "${JAVA_HOME:-}" ]` at :320 with `jdk_usable "${JAVA_HOME:-}"`, and `warn` (D-04 wording) when non-empty but unusable. Callers :395, :404 unchanged.

### `rea-install-macos.sh`: `install_jdk` (:123-129) + step 7 (:207-219)

**Current `install_jdk`:** remove the `profile_exports+=` line (:128); body from RESEARCH Code Example 2 with new `jdk_home` helper.
**Step 7 analog** (to extract into `write_profile`, called from `do_install`):
```bash
  # 7. Shell profile: setup does not copy objdump/WABT settings into agent registrations.
  if ((${#profile_exports[@]} > 0)); then
    local profile
    profile="$(profile_file)"
    log "Adding REA settings to $profile"
    remove_profile_block "$profile"
    if [ "$dry_run" = true ]; then
      printf '    %s\n' "$PROFILE_BEGIN" "${profile_exports[@]}" "$PROFILE_END"
    else
      printf '%s\n' "$PROFILE_BEGIN" "${profile_exports[@]}" "$PROFILE_END" >>"$profile"
    fi
    record "profile:$profile"
  fi
```
Prepend the equality-checked append (`[ -n "${JAVA_HOME:-}" ]` first, then compare to `$(jdk_home)`, written as `if ... fi`, not a trailing `&&` list). Other `profile_exports+=` sites to copy quoting from: :203-204.
**Callers:** step 4 :185 (`install_jdk` in Ghidra `else`; add `brew_install "$JDK_FORMULA"` before `brew_install ghidra` per Pitfall 8 / A3, needs user confirmation), step 5 :192 `[ -n "${JAVA_HOME:-}" ] || install_jdk` becomes plain `install_jdk`.

### `rea-install-windows.ps1`: new `Test-JdkUsable`, rewrite `Install-Jdk` (:160-167)

**Predicate analog:** `Test-NodeSupported` (:76-81):
```powershell
# REA requires Node.js 22.x (>=22.19), 24.x (>=24.11), or 26+; SQLite analysis needs 24.15+.
function Test-NodeSupported {
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) { return $false }
    $v = [version]((node -p 'process.versions.node') -replace '[^0-9.].*$', '')
    return ($v.Major -eq 22 -and $v.Minor -ge 19) -or ($v.Major -eq 24 -and $v.Minor -ge 15) -or $v.Major -ge 26
}
```
Copy: comment-first, early `return $false`, single bool `return`. Body from RESEARCH Code Example 3 (function-local `$ErrorActionPreference = 'Continue'`, `-match` on joined output, `$LASTEXITCODE`). Put it right after `Test-NodeSupported`.

**Persistence analog:** `Set-UserEnv` (:100-112), do NOT modify. It returns before `Set-Item env:` when a user value exists, so `Install-Jdk` must set `$env:JAVA_HOME = $dir` itself before calling `Set-UserEnv 'JAVA_HOME' $dir` (Pitfall 4). Call-site style to copy: `Set-UserEnv 'GHIDRA_INSTALL_DIR' (...)` at :197.
**Throw style:** `throw 'Node.js LTS installed but is still unsupported or not on PATH.'` (:186), with the derived folder in the message (D-08). Keep the `'<Temurin JAVA_HOME>'` dry-run placeholder (:165) and add an early return when `$env:JAVA_HOME` already equals it (Pitfall 1). Always call `Update-SessionPath` before `Get-Command java` (Install-Winget skips it when already installed).

### `test.sh`

**Table-test analog:** TEST-03 (:110-119):
```bash
for script in "$LINUX" "$MACOS"; do
  name="$(basename "$script")"
  for row in 22.18.0:1 22.19.0:0 24.14.0:1 24.15.0:0 26.0.0:0; do
    stub node "echo ${row%%:*}"
    sandbox "$script" 'node_supported'
    if [ "$rc" = "${row#*:}" ]; then ok "TEST-03 node_supported ${row%%:*} ($name)"; else bad "TEST-03 node_supported ${row%%:*} ($name)"; fi
  done
done
rm -f "$STUBS/node"
```
Copy the `row=NAME:rc` table, `sandbox` as plain statement then read `$rc`, `ok`/`bad` reporting. Stub JDKs are a new tiny helper modeled on `stub` (:25): `printf '#!/bin/sh\n%s\n' "$body" > "$work/jdks/$name/bin/java"; chmod +x` (stderr output `>&2`; also write `java.exe` for pwsh). Rows: 8 17 21 21.0.5 25-ea missing garbage picked-up.
**Sandbox helper** (:30-39): runs in a subshell with `HOME=$work/home`, `PATH=$stub_path`; `$work` is visible inside the eval string. Use `fresh_home` (:41) between macOS profile writes. macOS two-write check is Darwin-only (BSD `sed -i ''`); never call `load_brew`/`do_install` (Pitfall 9); stub `brew` whose `--prefix` prints a path under `$HOME`.
**pwsh driver analog** (:264-314): heredoc `w.ps1` dot-sources the script, redirects `$StateDir`/`$StateFile` into `$Work`, prints via `Report([bool], [string])`; bash loop turns `PASS:`/`FAIL:` lines into `ok`/`bad`. Add after dot-source: `function Update-SessionPath {}` (Pitfall 11). Add JDK cases with 5.1-only syntax; clean up added stubs in the trailing `rm -f "$STUBS/..."` line.

## Shared Patterns

- **Logging/errors:** `log "Using JDK at $JAVA_HOME"` (existing wording), `warn` / `Warn` with D-04 sentence, `die` / `throw` for fatal. Never print captured `java -version` output (may contain JAVA_TOOL_OPTIONS secrets).
- **Dry run:** session-env changes (`export`, `$env:`) are fine; disk changes only via `run`/`record`/`Set-UserEnv`/`setting`.
- **No shared code:** predicate text duplicated in linux and macos bash (identical, Bash 3.2 safe) and ported to PowerShell.
- **No new ledger kinds:** profile block (`profile:`) and `env:JAVA_HOME` already handled by uninstall.

## No Analog Found

None. `jdk_home` (macOS) and the stub-JDK helper in `test.sh` are new but trivially derived from `brew --prefix` usage (macos :127, :203) and `stub` (test.sh :25).

## Metadata

**Analog search scope:** the four in-scope files (all git-tracked).
**Pattern extraction date:** 2026-10-14
