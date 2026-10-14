#!/bin/bash
# Regression checks for the three installers. Runs locally and in CI: ./test.sh
# Prints one PASS/FAIL/SKIP line per check and exits 1 if any check failed.
# No errexit on purpose: every check runs even after an earlier one fails.
set -u

root="$(cd "$(dirname "$0")" && pwd)"
LINUX="$root/rea-install-linux.sh"
MACOS="$root/rea-install-macos.sh"
WIN="$root/rea-install-windows.ps1"

pass=0 fail=0 skip=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }
skip() { printf 'SKIP: %s\n' "$1"; skip=$((skip + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "${work:?}"' EXIT
STUBS="$work/stubs"
mkdir -p "$STUBS"
rc=0

# Writes an executable stub NAME on the sandbox PATH that runs BODY.
stub() { printf '#!/bin/sh\n%s\n' "$2" >"$STUBS/$1"; chmod +x "$STUBS/$1"; }

# Runs CODE in a subshell with SCRIPT's functions loaded, under the temp HOME and stub PATH.
# Call it as a plain statement and read $rc after: inside `if` or `||` bash turns set -e off for the whole subshell.
# HOME is exported before sourcing because STATE_DIR, TOOLS_DIR and NPM_PREFIX are computed at source time.
sandbox() {
  (
    export HOME="$work/home" PATH="$STUBS:$PATH" SHELL=/bin/bash
    unset ZDOTDIR
    # shellcheck source=/dev/null
    . "$1"
    eval "$2"
  ) >"$work/out" 2>&1
  rc=$?
}

fresh_home() { rm -rf "${work:?}/home"; mkdir -p "$work/home"; }

# Succeeds when TOOL is usable. Otherwise SKIPs CHECK, or FAILs it in CI so CI never passes by skipping.
# Docker and shellcheck are absent on the macos-latest runner by design; the ubuntu job covers them.
need() {
  local tool="$1" check="$2" present=true
  case "$tool" in
    docker) docker info >/dev/null 2>&1 || present=false ;; # a stopped Docker Desktop counts as missing
    *) command -v "$tool" >/dev/null 2>&1 || present=false ;;
  esac
  [ "$present" = true ] && return 0
  case "$(uname -s):$tool" in
    Darwin:docker | Darwin:shellcheck) skip "$check ($tool not on this runner)" ;;
    *) if [ "${CI:-}" = true ]; then bad "$check ($tool not found)"; else skip "$check ($tool not found)"; fi ;;
  esac
  return 1
}

# ---------------------------------------------------------------- TEST-01 syntax
for script in "$LINUX" "$MACOS"; do
  name="$(basename "$script")"
  # "$BASH" so the macOS job checks under Bash 3.2.
  if "$BASH" -n "$script" 2>"$work/out"; then ok "TEST-01 bash -n $name"; else bad "TEST-01 bash -n $name"; sed 's/^/    /' "$work/out"; fi
done

# ---------------------------------------------------------------- TEST-01 lint and parse
for script in "$LINUX" "$MACOS" "$root/test.sh"; do
  name="$(basename "$script")"
  need shellcheck "TEST-01 shellcheck $name" || continue
  if shellcheck "$script" >"$work/out" 2>&1; then ok "TEST-01 shellcheck $name"; else bad "TEST-01 shellcheck $name"; sed 's/^/    /' "$work/out"; fi
done

if need pwsh "TEST-01 pwsh parse $(basename "$WIN")"; then
  cat >"$work/parse.ps1" <<'EOF'
param([string]$Path)
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Host $_ }; exit 1 }
EOF
  # Temp HOME so pwsh's own caches never land in the real one.
  if HOME="$work/pwsh-home" pwsh -NoProfile -File "$work/parse.ps1" -Path "$WIN" >"$work/out" 2>&1; then
    ok "TEST-01 pwsh parse $(basename "$WIN")"
  else
    bad "TEST-01 pwsh parse $(basename "$WIN")"; sed 's/^/    /' "$work/out"
  fi
fi

# ---------------------------------------------------------------- TEST-02 profile round trip
# Each script's sed -i form only works on its own OS (GNU vs BSD), so each half runs on its OS.
for pair in "$LINUX:Linux" "$MACOS:Darwin"; do
  script="${pair%:*}" os="${pair##*:}"
  name="$(basename "$script")"
  if [ "$(uname -s)" != "$os" ]; then
    if [ "$os" = Linux ]; then skip "TEST-02 profile round trip ($name) (Linux only)"; else skip "TEST-02 profile round trip ($name) (macOS only)"; fi
    continue
  fi
  fresh_home
  # Ends with a newline: a profile without one is a known, deferred bug (the BEGIN marker joins the last line).
  printf '%s\n' 'export EDITOR=vi' 'alias ll="ls -l"' '' 'export PATH=/opt/bin:/usr/bin' >"$work/home/.bashrc"
  cp "$work/home/.bashrc" "$work/profile.ref"
  # shellcheck disable=SC2016  # expanded inside the sandbox, with the script's own markers
  sandbox "$script" 'printf "%s\n" "$PROFILE_BEGIN" "export REA_TEST=1" "$PROFILE_END" >>"$HOME/.bashrc"; remove_profile_block "$HOME/.bashrc"'
  if [ "$rc" -eq 0 ] && cmp -s "$work/home/.bashrc" "$work/profile.ref"; then
    ok "TEST-02 profile round trip ($name)"
  else
    bad "TEST-02 profile round trip ($name)"; sed 's/^/    /' "$work/out"
  fi
done

# ---------------------------------------------------------------- TEST-03 node_supported
for script in "$LINUX" "$MACOS"; do
  name="$(basename "$script")"
  for row in 22.18.0:1 22.19.0:0 24.14.0:1 24.15.0:0 26.0.0:0; do
    stub node "echo ${row%%:*}"
    sandbox "$script" 'node_supported'
    if [ "$rc" = "${row#*:}" ]; then ok "TEST-03 node_supported ${row%%:*} ($name)"; else bad "TEST-03 node_supported ${row%%:*} ($name)"; fi
  done
done
rm -f "$STUBS/node"

# ---------------------------------------------------------------- source guard
for script in "$LINUX" "$MACOS"; do
  name="$(basename "$script")"
  # Piped run must still reach main. Only the unknown-command branch is asserted:
  # usage() reads "$0", which is the bash binary when piped (deferred bug).
  "$BASH" -s -- bogus <"$script" >"$work/out" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'unknown command: bogus' "$work/out"; then
    ok "GUARD piped into bash runs main ($name)"
  else
    bad "GUARD piped into bash runs main ($name)"
  fi
  sandbox "$script" 'echo loaded'
  if [ "$rc" -eq 0 ] && [ "$(cat "$work/out")" = loaded ]; then ok "GUARD sourced skips main ($name)"; else bad "GUARD sourced skips main ($name)"; fi
done

printf '%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
