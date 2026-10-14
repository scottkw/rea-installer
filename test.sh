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

# Prints the last sandbox or container output indented, so a FAIL line shows its reason.
show() { sed 's/^/    /' "$work/out"; }

# Shared with the Windows checks: STUB_TAR=fail leaves a partial foo-1.0 in the -C folder and fails; otherwise real tar.
# shellcheck disable=SC2016  # expanded by the stub
stub tar 'if [ "${STUB_TAR:-}" = fail ]; then
  while [ $# -gt 0 ]; do [ "$1" = -C ] && d="$2"; shift; done
  mkdir -p "$d/foo-1.0"; : >"$d/foo-1.0/partial"; exit 1
fi
exec /usr/bin/tar "$@"'
# A small archive with a top-level foo-1.0 folder, built with test.sh's own tar.
mkdir -p "$work/src/foo-1.0/bin"
printf 'real\n' >"$work/src/foo-1.0/bin/tool"

# ---------------------------------------------------------------- FAIL-01 Linux extract
fresh_home
mkdir -p "$work/home/.rea-installer/tools"
# fetch skips the download when the archive is already in TOOLS_DIR.
tar -czf "$work/home/.rea-installer/tools/foo-1.0.tar.gz" -C "$work/src" foo-1.0
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$LINUX" 'export STUB_TAR=fail; d="$(unpack "https://example.invalid/foo-1.0.tar.gz 00" foo-1.0)"; echo "continued with $d"'
if [ "$rc" -ne 0 ] && [ ! -e "$work/home/.rea-installer/tools/foo-1.0" ]; then
  ok "FAIL-01 Linux failed unpack stops and leaves no tool folder"
else
  bad "FAIL-01 Linux failed unpack stops and leaves no tool folder"; show
fi
# Same HOME: the fixed unpack keeps the verified archive after a failure, so the rerun reuses it.
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$LINUX" 'd="$(unpack "https://example.invalid/foo-1.0.tar.gz 00" foo-1.0)"; [ -f "$d/bin/tool" ]'
if [ "$rc" -eq 0 ]; then ok "FAIL-01 Linux rerun extracts again"; else bad "FAIL-01 Linux rerun extracts again"; show; fi

# ---------------------------------------------------------------- FAIL-02 package install
fresh_home
# shellcheck disable=SC2016  # expanded by the stub; real sudo would reset PATH and skip the stubs
stub sudo 'exec "$@"'
stub apt-get 'exit 100'
stub apt-cache 'exit 0'
stub dpkg-query 'case "$*" in *Status-Abbrev*) echo "ii  base-files" ;; *) exit 1 ;; esac'
sandbox "$LINUX" 'pm=apt-get; pkg_install curl || die "curl is required."; echo continued'
if [ "$rc" -ne 0 ] && grep -q 'curl is required' "$work/out" && ! grep -q '^pkg:curl' "$work/home/.rea-installer/installed" 2>/dev/null; then
  ok "FAIL-02 failed package install stops and is not recorded"
else
  bad "FAIL-02 failed package install stops and is not recorded"; show
fi

# ---------------------------------------------------------------- FAIL-03 brew install
fresh_home
# shellcheck disable=SC2016  # expanded by the stub
stub brew 'case "$1" in list) exit 1 ;; install) echo "Error: no such formula" >&2; exit 1 ;; esac'
# The || is deliberate: real callers already stop through errexit, so only a direct call can go red.
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'brew_install rea-test-formula || echo "brew_install returned $?"'
if grep -q 'brew_install returned 1' "$work/out" && grep -qF 'brew install rea-test-formula failed.' "$work/out" &&
  ! grep -q '^brew:' "$work/home/.rea-installer/installed" 2>/dev/null; then
  ok "FAIL-03 failed brew install is reported and not recorded"
else
  bad "FAIL-03 failed brew install is reported and not recorded"; show
fi

# ---------------------------------------------------------------- UNIN-01 bash uninstall
# Each script's sed -i and tac/tail -r only work on its own OS. The ledger pins npm to the stub, and holds
# only npm: and profile: lines: on a dev Mac load_brew puts the real brew before the stubs.
unin_home() {
  fresh_home
  mkdir -p "$work/home/.agents/skills" "$work/home/.rea-installer" "$(dirname "$1")"
  printf '#!/bin/sh\nexit 3\n' >"$1"; chmod +x "$1"
  printf 'keep me\n# >>> rea-installer >>>\nexport X=1\n# <<< rea-installer <<<\n' >"$2"
  printf 'npm:%s\nprofile:%s\n' "$STUBS/npm" "$2" >"$work/home/.rea-installer/installed"
}
unin_check() {
  if [ "$rc" -eq 0 ] && grep -q 'rea uninstall failed' "$work/out" && printf 'keep me\n' | cmp -s - "$2" &&
    [ ! -e "$work/home/.rea-installer" ]; then
    ok "$1"
  else
    bad "$1"; show
  fi
}
if [ "$(uname -s)" = Linux ]; then
  stub npm 'exit 1'
  unin_home "$work/home/.local/bin/rea" "$work/home/.bashrc"
  sandbox "$LINUX" 'do_uninstall'
  unin_check "UNIN-01 Linux uninstall survives a failing rea" "$work/home/.bashrc"
else
  skip "UNIN-01 Linux uninstall survives a failing rea (Linux only)"
fi
if [ "$(uname -s)" = Darwin ]; then
  # The macOS script finds rea under "$(npm prefix --global)/bin".
  # shellcheck disable=SC2016  # expanded by the stub
  stub npm 'case "$1" in prefix) echo "$HOME/npm-global" ;; *) exit 1 ;; esac'
  unin_home "$work/home/npm-global/bin/rea" "$work/home/.bash_profile"
  sandbox "$MACOS" 'do_uninstall'
  unin_check "UNIN-01 macOS uninstall survives a failing rea" "$work/home/.bash_profile"
else
  skip "UNIN-01 macOS uninstall survives a failing rea (macOS only)"
fi
# Later checks must not see these; sudo and tar stay.
rm -f "$STUBS/apt-get" "$STUBS/apt-cache" "$STUBS/dpkg-query" "$STUBS/brew" "$STUBS/npm" "$STUBS/node"

printf '%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
