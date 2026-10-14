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

# ---------------------------------------------------------------- TEST-01 syntax
for script in "$LINUX" "$MACOS"; do
  name="$(basename "$script")"
  # "$BASH" so the macOS job checks under Bash 3.2.
  if "$BASH" -n "$script" 2>"$work/out"; then ok "TEST-01 bash -n $name"; else bad "TEST-01 bash -n $name"; sed 's/^/    /' "$work/out"; fi
done

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
