# Phase 3: macOS Unattended Install and README Sync - Pattern Map

**Mapped:** 2026-10-14
**Files analyzed:** 4 (all modified, none created)
**Analogs found:** 4 / 4 (line numbers verified against HEAD 520efbb)

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `rea-install-macos.sh` (TTY_PATH, have_tty, confirm, install_homebrew, step 9 fn, uninstall call sites) | installer script | request-response (tty prompt) + side-effect via `run` | `rea-install-linux.sh:539-546` (step 9 no-tty branch); macOS `install_jdk`/`install_ghidra` (169, 204) for `install_*` shape | exact |
| `rea-install-linux.sh` (TTY_PATH, have_tty, confirm, step 9 probe swap, Hopper call site) | installer script | request-response | its own step 9 (539-546); macOS copy of the same helpers | exact |
| `test.sh` (new `# ---- MAC-01/02 macOS unattended install` section before line 575) | test | sourced-function sandbox | FAIL-03 block (`test.sh:187-199`), JAVA-02 no-brew dry run (`test.sh:562-573`) | exact |
| `README.md` (Status ~25-33, Options `--yes` ~130/133, Uninstalling ~135-153, Engineered ~154-184, Testing 185-205, Known limitations 207-222) | docs | n/a | existing Testing table and Known limitations bullets | exact (in-file) |

## Pattern Assignments

### `rea-install-macos.sh`

**Constants block** (lines 14-31). Add `TTY_PATH="/dev/tty"` after `PROFILE_END` (line 23), unconditional assignment (never `${VAR:-/dev/tty}`). Header lines 2-11 are sliced by `usage()` (line 55, `sed -n '2,11p'`); do not touch them.
```bash
PROFILE_BEGIN="# >>> rea-installer >>>"
PROFILE_END="# <<< rea-installer <<<"
```

**Helpers to keep / reuse** (lines 33-53):
```bash
log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

run() {
  printf '  $'; printf ' %q' "$@"; printf '\n'
  [ "$dry_run" = true ] || "$@"
}
...
confirm() {
  [ "$assume_yes" = true ] && return 0
  local reply
  read -r -p "$1 [y/N] " reply </dev/tty
  [[ "$reply" =~ ^[Yy] ]]
}
```
Replace `confirm` (48-53) with the RESEARCH.md prototype (have_tty probe, `warn "no terminal available; leaving $2 in place."; return 1`, `read ... <"$TTY_PATH"`). Put `have_tty() { (: <"$TTY_PATH") 2>/dev/null; }` directly above it. Body must be byte-identical to the Linux copy.

**Probe source to copy** (`rea-install-linux.sh:539-546`, the D-01 analog):
```bash
  log "Running rea setup"
  if [ "$assume_yes" = true ]; then
    run "$rea_bin" setup --yes --all-detected
  elif (: </dev/tty) 2>/dev/null; then
    run "$rea_bin" setup </dev/tty
  else
    warn "no terminal available; run '$rea_bin setup' yourself."
  fi
```

**Current macOS step 2 to extract** (lines 277-283) into `install_homebrew`, placed with the other `install_*` helpers (after `install_ghidra` at 204, before `write_profile` at 222). `do_install` keeps `load_brew || install_homebrew` under the `# 2. Homebrew` comment:
```bash
  # 2. Homebrew
  if ! load_brew; then
    log "Installing Homebrew"
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    record "homebrew"
    [ "$dry_run" = true ] || load_brew || die "Homebrew installed but brew was not found."
  fi
```
Fix: fetch into a local with a plain assignment `|| die`; `if [ "$assume_yes" = true ]` two-branch `run` (`have_tty && run sudo -v || die "$hint"`, then `run env NONINTERACTIVE=1 /bin/bash -c "$script" || die "$hint"`), else `run /bin/bash -c "$script" || die "$hint"`; `record "homebrew"` only after success. No optional-prefix array (Bash 3.2 + `set -u`). Full prototype: 03-RESEARCH.md "Code Examples".

**Current macOS step 9 to replace** (lines 330-341). Extract the if/else into a small function taking REA_BIN (e.g. `register_agents`), keep the Hopper before/after lines in `do_install`:
```bash
  # 9. Agent registration (+ optional Hopper install, which setup asks about)
  local hopper_before app
  hopper_before="$(hopper_apps)"
  log "Running rea setup"
  if [ "$assume_yes" = true ]; then
    run "$rea_bin" setup --yes --all-detected
  else
    run "$rea_bin" setup </dev/tty
  fi
  while IFS= read -r app; do
    [ -n "$app" ] && ! grep -qxF "$app" <<<"$hopper_before" && record "app:$app"
  done <<<"$(hopper_apps)"
```

**Install-helper shape analog** (`install_*` with log + guarded die), e.g. line 183:
```bash
  [ "$dry_run" = true ] || jdk_usable "$ours" || die "Homebrew $JDK_FORMULA at $ours does not run."
```

**Uninstall call sites to pass ITEM** (378, 408, 411):
```bash
        if [ -e "$line" ] && confirm "Remove $line (installed by rea setup)?"; then          # -> ... "$line"
  if grep -qxF homebrew <<<"$state" && confirm "Remove Homebrew (installed by this script)?"; then   # -> ... "Homebrew"
  if grep -qxF clt <<<"$state" && confirm "Remove Xcode Command Line Tools (installed by this script)?"; then  # -> ... "the Xcode Command Line Tools"
```
Every call must pass `$2` (set -u makes a missing `$2` fatal even inside `if`). Verify with `grep -n 'confirm "' rea-install-*.sh`.

**Step 1 CLT (269-275): no change (D-03).**

---

### `rea-install-linux.sh`

- Constants: add `TTY_PATH="/dev/tty"` after `HOPPER_LAUNCHER` (line 24). Header 2-15 untouched (`usage` line 69).
- `confirm` at lines 62-67 is identical to macOS 48-53; replace with the same `have_tty` + new `confirm` bodies.
- Step 9 (542-543): change `(: </dev/tty) 2>/dev/null` -> `have_tty` and `</dev/tty` -> `<"$TTY_PATH"`. Stays inline.
- Hopper call site (594): `confirm "Remove Hopper package $line (installed by rea setup)?" "Hopper package $line"`.

---

### `test.sh` (new section before `# ---------------------------------------------------------------- DRY-01/02 fresh container`, line 575)

**Harness pieces** (lines 13-15, 25, 35-45):
```bash
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }
stub() { printf '#!/bin/sh\n%s\n' "$2" >"$STUBS/$1"; chmod +x "$STUBS/$1"; }
# Call sandbox as a plain statement and read $rc after
sandbox() {
  (
    export HOME="$work/home" PATH="$stub_path" SHELL=/bin/bash
    unset ZDOTDIR
    . "$1"
    eval "$2"
  ) >"$work/out" 2>&1
  rc=$?
}
```

**Check shape analog** (FAIL-03, lines 187-199): stub, `fresh_home`, `sandbox` with inline `# shellcheck disable=SC2016  # expanded inside the sandbox`, then a single `if ... grep -qF ...; then ok "..."; else bad "..."; show; fi`, asserting the ledger has no record:
```bash
fresh_home
# shellcheck disable=SC2016  # expanded by the stub
stub brew 'case "$1" in list) exit 1 ;; install) echo "Error: no such formula" >&2; exit 1 ;; esac'
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'brew_install rea-test-formula || echo "brew_install returned $?"'
if grep -q 'brew_install returned 1' "$work/out" && grep -qF 'brew install rea-test-formula failed.' "$work/out" &&
  ! grep -q '^brew:' "$work/home/.rea-installer/installed" 2>/dev/null; then
  ok "FAIL-03 failed brew install is reported and not recorded"
else
  bad "FAIL-03 failed brew install is reported and not recorded"; show
fi
```

**No-brew dry-run analog** (lines 562-573): restrict PATH inside the sandbox so a real brew can't be found:
```bash
sandbox "$MACOS" 'PATH="$STUBS:/usr/bin:/bin"; dry_run=true; unset JAVA_HOME; install_jdk; printf "JAVA_HOME=%s\n" "$JAVA_HOME"'
if [ "$rc" -eq 0 ] && grep -qF '...' "$work/out" && ...; then ok "..."; else bad "..."; show; fi
```

New-check rules (from RESEARCH Pitfalls 1-4):
- Every check sets `TTY_PATH` explicitly after sourcing: `$work/missing` (no terminal) or a file containing `y` (terminal answering yes).
- confirm checks: assert `leaving Homebrew in place.` present AND `Device not configured`/`No such device` absent; run for both `$MACOS` and `$LINUX`. Call `confirm` directly, never `do_uninstall` with `homebrew`/`clt` lines.
- `install_homebrew` checks: stub `curl` (echo harmless script) every time; dry runs for `sudo -v` / `NONINTERACTIVE` assertions (`grep -qx '  \$ sudo -v'`, `grep -qF 'env NONINTERACTIVE=1 /bin/bash -c'`, order check sudo before env); the D-06 real-run check also stubs `env` as `exit 1`, then `rm -f "$STUBS/env" "$STUBS/curl"` right after (pattern: line 562 `rm -f "$STUBS/brew" "$STUBS/ghidraRun"`). `sudo` stub (line 176 `exec "$@"`) persists, so never run `sudo -v` outside dry run.
- Never call `load_brew` or `do_install` (test.sh:375 warning).
- Checks need no `sed -i`/`tail -r`, so no OS skip.

---

### `README.md`

Analog is the file itself. Current anchors (verified): `## Status` 25, `## Options` 122, `## Uninstalling` 135, `## How the scripts were engineered` 154, `## Testing` 185 (table 187-191, Linux steps, callout 201-205), `## Known limitations` 207-222.

**Testing table row format** (line 189):
```markdown
| macOS | macOS 27 (Apple silicon) | `bash -n` and `shellcheck` under the system `/bin/bash` 3.2. Dry runs of install and uninstall. ... |
```
**Callout format** (201-205): `> **Not yet run on a real machine:**` with `> - ...;` bullets; add the unattended macOS install bullet.
**Known limitations bullet format** (209-222): `- **Bold label:** sentence-case prose ending with a period.` Use Finding 6 corrected wordings (WR-01 does not fail; WR-05 is Linux and macOS; no-tty Homebrew needs Homebrew installed first or passwordless sudo).
New `### Running the tests` subsection after the callout (before line 207); commands `/bin/bash ./test.sh` and `docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" -w /src ubuntu:24.04 bash ./test.sh`; SKIP rule mirrors `need()` (test.sh:47-62): missing tool SKIPs, docker-not-running counts as missing, `CI=true` turns SKIP into FAIL. No GitHub Actions.

## Shared Patterns

### Side effects through `run`
**Source:** `rea-install-macos.sh:37-40` (Linux 51-54). Apply to `sudo -v` and the Homebrew installer. Env assignments need `env VAR=val`, since `run` execs `"$@"`.

### Failure messages
`die "..."` / `warn "..."` (macOS 34-35). Sentence case, ending period, lowercase start in the existing style ("no terminal available; ...").

### Identical helper copies
`have_tty` and `confirm` bodies must match byte for byte across both bash scripts (no shared module). Verify with `diff <(sed -n '/^have_tty/,/^}/p' rea-install-macos.sh) <(sed -n '/^have_tty/,/^}/p' rea-install-linux.sh)` style checks.

### Inline shellcheck annotations only
`# shellcheck disable=SCxxxx  # reason` on the line, as test.sh 189/192.

## No Analog Found

None. `sudo -v` + `env NONINTERACTIVE=1` has no in-repo precedent; use the RESEARCH.md prototype.

## Metadata

**Analog search scope:** rea-install-macos.sh, rea-install-linux.sh, test.sh, README.md
**Pattern extraction date:** 2026-10-14
