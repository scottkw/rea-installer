#!/bin/bash
# Regression checks for the three installers. Run locally: /bin/bash ./test.sh on macOS, ./test.sh in a Linux container.
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
stub_path="$STUBS:$PATH"
rc=0

# Writes an executable stub NAME on the sandbox PATH that runs BODY.
stub() { printf '#!/bin/sh\n%s\n' "$2" >"$STUBS/$1"; chmod +x "$STUBS/$1"; }
# Writes a stub JDK: DIR/bin/java runs BODY; bin/java.exe is a copy for the pwsh driver.
mkjdk() {
  mkdir -p "$1/bin"; printf '#!/bin/sh\n%s\n' "$2" >"$1/bin/java"; chmod +x "$1/bin/java"
  cp "$1/bin/java" "$1/bin/java.exe"
}

# Runs CODE in a subshell with SCRIPT's functions loaded, under the temp HOME and stub PATH.
# Call it as a plain statement and read $rc after: inside `if` or `||` bash turns set -e off for the whole subshell.
# HOME is exported before sourcing because STATE_DIR, TOOLS_DIR and NPM_PREFIX are computed at source time.
sandbox() {
  (
    export HOME="$work/home" PATH="$stub_path" SHELL=/bin/bash
    unset ZDOTDIR
    # shellcheck source=/dev/null
    . "$1"
    eval "$2"
  ) >"$work/out" 2>&1
  rc=$?
}

fresh_home() { rm -rf "${work:?}/home"; mkdir -p "$work/home"; }

# Succeeds when TOOL is usable. Otherwise SKIPs CHECK, or FAILs it when CI=true so an unattended run never passes by skipping.
# Docker and shellcheck may be missing on a Mac; the Linux container run covers shellcheck.
need() {
  local tool="$1" check="$2" present=true
  case "$tool" in
    docker) docker info >/dev/null 2>&1 || present=false ;; # a stopped Docker Desktop counts as missing
    *) command -v "$tool" >/dev/null 2>&1 || present=false ;;
  esac
  [ "$present" = true ] && return 0
  case "$(uname -s):$tool" in
    Darwin:docker | Darwin:shellcheck) skip "$check ($tool not on this Mac)" ;;
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

# ---------------------------------------------------------------- JAVA-02 Linux install_jdk
# Every sandbox sets JAVA_HOME itself: the host may export its own.
fresh_home
mkjdk "$work/jdks/17" "echo 'openjdk version \"17.0.2\" 2022-01-18' >&2"
mkjdk "$work/jdks/21.0.5" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
# Prints JAVA_HOME and each queued profile line; the [@]+ form because Bash 3.2 errors on an empty array under set -u.
# shellcheck disable=SC2016  # expanded inside the sandbox
jdk_report='printf "JAVA_HOME=%s\n" "$JAVA_HOME"; for l in ${profile_lines[@]+"${profile_lines[@]}"}; do printf "line: %s\n" "$l"; done'
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$LINUX" 'dry_run=true; export JAVA_HOME="$work/jdks/17"; install_jdk; install_jdk; '"$jdk_report"
if [ "$rc" -eq 0 ] && [ "$(grep -c 'which is not JDK 21 or newer' "$work/out")" = 1 ] &&
  [ "$(grep -c 'Would download Temurin 21' "$work/out")" = 1 ] && [ "$(grep -c '^line: export JAVA_HOME=' "$work/out")" = 1 ] &&
  grep -qxF "JAVA_HOME=$work/home/.rea-installer/jdk" "$work/out"; then
  ok "JAVA-02 Linux install_jdk replaces a JDK 17 JAVA_HOME with its own"
else
  bad "JAVA-02 Linux install_jdk replaces a JDK 17 JAVA_HOME with its own"; show
fi
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$LINUX" 'dry_run=true; export JAVA_HOME="$work/jdks/21.0.5"; install_jdk; '"$jdk_report"
if [ "$rc" -eq 0 ] && grep -qF "Using JDK at $work/jdks/21.0.5" "$work/out" && grep -qxF "JAVA_HOME=$work/jdks/21.0.5" "$work/out" &&
  ! grep -q 'Would download Temurin 21' "$work/out" && ! grep -q '^line: export JAVA_HOME=' "$work/out"; then
  ok "JAVA-02 Linux install_jdk reuses a JDK 21 JAVA_HOME"
else
  bad "JAVA-02 Linux install_jdk reuses a JDK 21 JAVA_HOME"; show
fi
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$LINUX" 'dry_run=true; unset JAVA_HOME; install_jdk; printf "JAVA_HOME=%s\n" "$JAVA_HOME"'
if [ "$rc" -eq 0 ] && grep -qxF "JAVA_HOME=$work/home/.rea-installer/jdk" "$work/out" &&
  [ "$(grep -c 'Would download Temurin 21' "$work/out")" = 1 ] && ! grep -q 'not JDK 21' "$work/out"; then
  ok "JAVA-02 Linux install_jdk with no JAVA_HOME installs its own without a warning"
else
  bad "JAVA-02 Linux install_jdk with no JAVA_HOME installs its own without a warning"; show
fi

# jdk_usable on every java -version shape real JDKs print (stderr only), in both bash scripts.
mkjdk "$work/jdks/8" "echo 'openjdk version \"1.8.0_402\"' >&2"
mkjdk "$work/jdks/21" "echo 'openjdk version \"21\" 2023-09-19' >&2"
mkjdk "$work/jdks/25-ea" "echo 'openjdk version \"25-ea\" 2025-09-16' >&2"
mkjdk "$work/jdks/picked-up" "echo 'Picked up JAVA_TOOL_OPTIONS: -Dfile.encoding=UTF-8' >&2; echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
mkjdk "$work/jdks/garbage" 'echo hello >&2'
mkjdk "$work/jdks/exit1" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2; exit 1"
for script in "$LINUX" "$MACOS"; do
  name="$(basename "$script")"
  for row in 8:1 17:1 21:0 21.0.5:0 25-ea:0 picked-up:0 garbage:1 exit1:1 missing:1 empty:1; do
    label="${row%%:*}" dir="$work/jdks/${row%%:*}"
    [ "$label" = empty ] && dir=""
    sandbox "$script" "jdk_usable \"$dir\""
    if [ "$rc" = "${row#*:}" ]; then ok "JAVA-02 jdk_usable $label ($name)"; else bad "JAVA-02 jdk_usable $label ($name)"; show; fi
  done
done

# A broken ~/.rea-installer/jdk is replaced on rerun (WR-09). fetch and unpack reuse the pre-seeded tools folder,
# so nothing is downloaded. The node stub prints "link sha release" as install_jdk reads it. It drains stdin
# first: exiting unread makes the curl stub die of SIGPIPE, and pipefail then stops install_jdk silently.
stub curl 'echo "[]"'
stub node 'cat >/dev/null; echo https://example.invalid/OpenJDK21U-jdk.tar.gz 00 jdk-21.0.5+11'
fresh_home
mkjdk "$work/home/.rea-installer/jdk" "echo 'openjdk version \"21.0.5\"' >&2; exit 1"
sandbox "$LINUX" 'dry_run=true; unset JAVA_HOME; install_jdk'
if [ "$rc" -eq 0 ] && grep -qF 'does not run; downloading it again.' "$work/out" &&
  grep -qF "rm -rf $work/home/.rea-installer/jdk" "$work/out" && [ "$(grep -c 'Would download Temurin 21' "$work/out")" = 1 ] &&
  [ -e "$work/home/.rea-installer/jdk/bin/java" ]; then
  ok "JAVA-02 Linux install_jdk plans to replace a broken ~/.rea-installer/jdk"
else
  bad "JAVA-02 Linux install_jdk plans to replace a broken ~/.rea-installer/jdk"; show
fi
fresh_home
mkjdk "$work/home/.rea-installer/jdk" "echo 'openjdk version \"21.0.5\"' >&2; exit 1"
mkjdk "$work/home/.rea-installer/tools/jdk-21.0.5+11" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
cp "$work/jdks/17/bin/java" "$work/java17.ref"
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$LINUX" 'export JAVA_HOME="$work/jdks/17"; install_jdk; printf "JAVA_HOME=%s\n" "$JAVA_HOME"'
if [ "$rc" -eq 0 ] && grep -qxF "JAVA_HOME=$work/home/.rea-installer/jdk" "$work/out" &&
  "$work/home/.rea-installer/jdk/bin/java" -version 2>/dev/null && cmp -s "$work/jdks/17/bin/java" "$work/java17.ref"; then
  ok "JAVA-02 Linux install_jdk replaces a broken ~/.rea-installer/jdk on rerun"
else
  bad "JAVA-02 Linux install_jdk replaces a broken ~/.rea-installer/jdk on rerun"; show
fi
# Adoptium's release_name can differ from the archive's top folder, which puts bin/java one level deeper (WR-04).
fresh_home
mkjdk "$work/home/.rea-installer/tools/jdk-21.0.5+11/nested" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$LINUX" 'unset JAVA_HOME; install_jdk; printf "JAVA_HOME=%s\n" "$JAVA_HOME"'
if [ "$rc" -eq 0 ] && grep -qxF "JAVA_HOME=$work/home/.rea-installer/jdk" "$work/out" &&
  [ -x "$work/home/.rea-installer/jdk/bin/java" ] && [ ! -e "$work/home/.rea-installer/tools/jdk-21.0.5+11" ]; then
  ok "JAVA-02 Linux install_jdk uses a Temurin archive whose bin/java is one level deeper"
else
  bad "JAVA-02 Linux install_jdk uses a Temurin archive whose bin/java is one level deeper"; show
fi
# Any other layout never becomes the trusted JDK, and the message asks for a report: a rerun repeats the same download.
fresh_home
mkdir -p "$work/home/.rea-installer/tools/jdk-21.0.5+11/nested"
touch "$work/home/.rea-installer/tools/jdk-21.0.5+11/nested/README"
sandbox "$LINUX" 'unset JAVA_HOME; install_jdk; echo continued'
if [ "$rc" -ne 0 ] && grep -qF 'has no bin/java' "$work/out" && grep -qF 'report this' "$work/out" && ! grep -qx continued "$work/out" &&
  [ ! -e "$work/home/.rea-installer/jdk" ] && [ ! -e "$work/home/.rea-installer/tools/jdk-21.0.5+11" ]; then
  ok "JAVA-02 Linux install_jdk stops on a Temurin archive without bin/java"
else
  bad "JAVA-02 Linux install_jdk stops on a Temurin archive without bin/java"; show
fi
fresh_home
mkjdk "$work/home/.rea-installer/tools/jdk-21.0.5+11" "echo 'Error: Could not create the Java Virtual Machine.' >&2; exit 1"
sandbox "$LINUX" 'unset JAVA_HOME; install_jdk; echo continued'
if [ "$rc" -ne 0 ] && grep -qF 'does not run' "$work/out" && grep -qF 'Could not create the Java Virtual Machine' "$work/out" &&
  ! grep -qx continued "$work/out"; then
  ok "JAVA-02 Linux install_jdk shows java -version output when its JDK does not run"
else
  bad "JAVA-02 Linux install_jdk shows java -version output when its JDK does not run"; show
fi
# java -version output is shown without Picked up lines, which can hold proxy passwords (02-01 T-02-02).
fresh_home
mkjdk "$work/home/.rea-installer/tools/jdk-21.0.5+11" "echo 'Picked up JAVA_TOOL_OPTIONS: -Xmx1g' >&2; echo 'Picked up _JAVA_OPTIONS: -Xmx1g' >&2; echo 'NOTE: Picked up JDK_JAVA_OPTIONS: -Dhttp.proxyPassword=hunter2' >&2; echo 'Error: Could not create the Java Virtual Machine.' >&2; exit 1"
sandbox "$LINUX" 'unset JAVA_HOME; install_jdk; echo continued'
if [ "$rc" -ne 0 ] && grep -qF 'does not run' "$work/out" && grep -qF 'Could not create the Java Virtual Machine' "$work/out" &&
  ! grep -qF 'Picked up' "$work/out" && ! grep -qF hunter2 "$work/out" && ! grep -qx continued "$work/out"; then
  ok "JAVA-02 Linux install_jdk hides Picked up lines when its JDK does not run"
else
  bad "JAVA-02 Linux install_jdk hides Picked up lines when its JDK does not run"; show
fi
# An empty release would make unpack target $TOOLS_DIR itself (IN-05). Last in this section: it replaces the node stub.
stub node 'cat >/dev/null; echo https://example.invalid/OpenJDK21U-jdk.tar.gz 00'
fresh_home
mkdir -p "$work/home/.rea-installer/tools"
touch "$work/home/.rea-installer/tools/keep"
sandbox "$LINUX" 'unset JAVA_HOME; install_jdk; echo continued'
if [ "$rc" -ne 0 ] && grep -qF 'could not read the Temurin 21 release' "$work/out" && ! grep -qx continued "$work/out" &&
  [ -e "$work/home/.rea-installer/tools/keep" ]; then
  ok "JAVA-02 Linux install_jdk stops on an empty Temurin release and keeps the tools folder"
else
  bad "JAVA-02 Linux install_jdk stops on an empty Temurin release and keeps the tools folder"; show
fi
rm -f "$STUBS/curl" "$STUBS/node"

# ---------------------------------------------------------------- JAVA-02/03/04 macOS install_jdk and profile
# Stub brew: --prefix points under the temp HOME, list says installed so brew_install never installs.
# Never call load_brew or do_install here: the real brew would come first on PATH.
# shellcheck disable=SC2016  # expanded by the stub
stub brew 'case "$1" in --prefix) echo "$HOME/brew/opt/$2" ;; list) exit 0 ;; *) exit 1 ;; esac'
# Ghidra already on PATH: install_ghidra takes its "already available" branch, as on a rerun.
stub ghidraRun 'exit 0'
ours="$work/home/brew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
# The second write runs remove_profile_block, which uses BSD sed -i ''.
if [ "$(uname -s)" = Darwin ]; then
  fresh_home
  mkjdk "$ours" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
  # Both runs queue an export, as --with-extras does: without one, write_profile leaves the old block alone.
  sandbox "$MACOS" 'unset JAVA_HOME; install_jdk; profile_exports+=("export REA_TEST=1"); write_profile'
  rc1=$rc
  first_warned=false
  grep -q 'not JDK 21' "$work/out" && first_warned=true
  # The second run's shell never sourced the block: JAVA_HOME is unset, as in the same terminal as run 1.
  sandbox "$MACOS" 'unset JAVA_HOME; install_ghidra; profile_exports+=("export REA_TEST=1"); write_profile'
  if [ "$rc1" -eq 0 ] && [ "$rc" -eq 0 ] && [ "$first_warned" = false ] && ! grep -q 'not JDK 21' "$work/out" &&
    [ "$(grep -cx '# >>> rea-installer >>>' "$work/home/.bash_profile")" = 1 ] &&
    [ "$(grep -c '^export JAVA_HOME=' "$work/home/.bash_profile")" = 1 ] &&
    grep -qxF "export JAVA_HOME=\"$ours\"" "$work/home/.bash_profile"; then
    ok "JAVA-04 macOS rerun keeps one profile block exporting its own JAVA_HOME"
  else
    bad "JAVA-04 macOS rerun keeps one profile block exporting its own JAVA_HOME"; show; sed 's/^/    /' "$work/home/.bash_profile" 2>/dev/null
  fi
else
  skip "JAVA-04 macOS rerun keeps one profile block exporting its own JAVA_HOME (macOS only)"
fi
# No existing block below, so no sed -i: these run on every OS. REA_TEST=1 makes sure a block is written at all.
# A rerun after a failed run: the ledger owns openjdk@21 but no block was written yet.
fresh_home
mkjdk "$ours" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
mkdir -p "$work/home/.rea-installer"
printf 'brew:openjdk@21\n' >"$work/home/.rea-installer/installed"
sandbox "$MACOS" 'unset JAVA_HOME; install_ghidra; write_profile'
if [ "$rc" -eq 0 ] && [ "$(grep -cxF "export JAVA_HOME=\"$ours\"" "$work/home/.bash_profile" 2>/dev/null)" = 1 ]; then
  ok "JAVA-04 macOS rerun with JAVA_HOME unset restores its own JAVA_HOME from the ledger"
else
  bad "JAVA-04 macOS rerun with JAVA_HOME unset restores its own JAVA_HOME from the ledger"; show
fi
# Same ledger, but a usable user JDK: owning openjdk@21 must not override it (JAVA-03).
fresh_home
mkdir -p "$work/home/.rea-installer"
printf 'brew:openjdk@21\n' >"$work/home/.rea-installer/installed"
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'export JAVA_HOME="$work/jdks/21.0.5"; install_ghidra; profile_exports+=("export REA_TEST=1"); write_profile'
if [ "$rc" -eq 0 ] && grep -qF "Using JDK at $work/jdks/21.0.5" "$work/out" && ! grep -qF 'does not run' "$work/out" &&
  grep -qx 'export REA_TEST=1' "$work/home/.bash_profile" && ! grep -q '^export JAVA_HOME=' "$work/home/.bash_profile"; then
  ok "JAVA-03 macOS rerun reuses a JDK 21 JAVA_HOME even when it owns openjdk@21"
else
  bad "JAVA-03 macOS rerun reuses a JDK 21 JAVA_HOME even when it owns openjdk@21"; show
fi
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'export JAVA_HOME="$work/jdks/21.0.5"; install_jdk; profile_exports+=("export REA_TEST=1"); write_profile; printf "JAVA_HOME=%s\n" "$JAVA_HOME"'
if [ "$rc" -eq 0 ] && grep -qF "Using JDK at $work/jdks/21.0.5" "$work/out" && grep -qxF "JAVA_HOME=$work/jdks/21.0.5" "$work/out" &&
  grep -qx 'export REA_TEST=1' "$work/home/.bash_profile" && ! grep -q '^export JAVA_HOME=' "$work/home/.bash_profile"; then
  ok "JAVA-03 macOS reused JDK 21 JAVA_HOME is not written to the profile"
else
  bad "JAVA-03 macOS reused JDK 21 JAVA_HOME is not written to the profile"; show
fi
# install_ghidra and install_jdk never run on this rerun, as with --no-ghidra --with-extras (WR-03).
n="JAVA-04 macOS --no-ghidra rerun writes its own JAVA_HOME whether or not the shell has it set"
all_ok=true got=""
# shellcheck disable=SC2016  # expanded inside the sandbox
for mode in 'export JAVA_HOME="$ours"' 'unset JAVA_HOME'; do
  fresh_home
  mkjdk "$ours" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
  mkdir -p "$work/home/.rea-installer"
  printf 'brew:openjdk@21\n' >"$work/home/.rea-installer/installed"
  sandbox "$MACOS" "$mode; profile_exports+=(\"export REA_TEST=1\"); write_profile"
  line="$(grep '^export JAVA_HOME=' "$work/home/.bash_profile" 2>/dev/null)"
  got="$got [$mode: rc=$rc $line]"
  if [ "$rc" -ne 0 ] || [ "$line" != "export JAVA_HOME=\"$ours\"" ]; then all_ok=false; show; fi
done
if [ "$all_ok" = true ]; then ok "$n"; else bad "$n"; printf '    %s\n' "$got"; fi
# The old block is the only proof of ownership here; rewriting it uses BSD sed -i ''.
n="JAVA-04 macOS --no-ghidra rerun keeps its own JAVA_HOME owned only through the old block"
if [ "$(uname -s)" = Darwin ]; then
  fresh_home
  mkjdk "$ours" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
  printf '%s\n' '# >>> rea-installer >>>' "export JAVA_HOME=\"$ours\"" '# <<< rea-installer <<<' >"$work/home/.bash_profile"
  sandbox "$MACOS" 'unset JAVA_HOME; profile_exports+=("export REA_TEST=1"); write_profile'
  if [ "$rc" -eq 0 ] && [ "$(grep -cx '# >>> rea-installer >>>' "$work/home/.bash_profile")" = 1 ] &&
    [ "$(grep -c '^export JAVA_HOME=' "$work/home/.bash_profile")" = 1 ] &&
    grep -qxF "export JAVA_HOME=\"$ours\"" "$work/home/.bash_profile"; then
    ok "$n"
  else
    bad "$n"; show; sed 's/^/    /' "$work/home/.bash_profile" 2>/dev/null
  fi
else
  skip "$n (macOS only)"
fi
# WR-01: a set JAVA_HOME is never replaced without the D-04 warning.
n="JAVA-02 macOS --no-ghidra rerun warns before replacing a JDK 17 JAVA_HOME with its own"
fresh_home
mkjdk "$ours" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
mkdir -p "$work/home/.rea-installer"
printf 'brew:openjdk@21\n' >"$work/home/.rea-installer/installed"
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'export JAVA_HOME="$work/jdks/17"; write_profile; printf "JAVA_HOME=%s\n" "$JAVA_HOME"'
if [ "$rc" -eq 0 ] && [ "$(grep -c 'which is not JDK 21 or newer' "$work/out")" = 1 ] && grep -qxF "JAVA_HOME=$ours" "$work/out" &&
  [ "$(grep -cxF "export JAVA_HOME=\"$ours\"" "$work/home/.bash_profile" 2>/dev/null)" = 1 ]; then
  ok "$n"
else
  bad "$n"; show
fi
# WR-03: an owned JDK that does not run is left out the same way from any shell.
n="JAVA-04 macOS --no-ghidra rerun leaves out an owned JDK that does not run, with a warning"
all_ok=true
# shellcheck disable=SC2016  # expanded inside the sandbox
for mode in 'export JAVA_HOME="$ours"' 'unset JAVA_HOME'; do
  fresh_home
  mkdir -p "$work/home/.rea-installer"
  printf 'brew:openjdk@21\n' >"$work/home/.rea-installer/installed"
  sandbox "$MACOS" "$mode; profile_exports+=(\"export REA_TEST=1\"); write_profile"
  if [ "$rc" -ne 0 ] || ! grep -qF 'does not run' "$work/out" || ! grep -qF 'Reinstall openjdk@21 with Homebrew' "$work/out" ||
    ! grep -qx 'export REA_TEST=1' "$work/home/.bash_profile" 2>/dev/null || grep -q '^export JAVA_HOME=' "$work/home/.bash_profile"; then
    all_ok=false; printf '    mode: %s\n' "$mode"; show
  fi
done
if [ "$all_ok" = true ]; then ok "$n"; else bad "$n"; fi
# Gap 2, WR-01: nothing else queued is the default plain rerun, and the dead JAVA_HOME must still leave the block and the session.
n="JAVA-04 macOS --no-ghidra rerun removes a dead owned JAVA_HOME when nothing else is queued"
if [ "$(uname -s)" = Darwin ]; then
  all_ok=true
  # shellcheck disable=SC2016  # expanded inside the sandbox
  for mode in 'export JAVA_HOME="$ours"' 'unset JAVA_HOME'; do
    fresh_home
    printf '%s\n' '# user line' '# >>> rea-installer >>>' "export JAVA_HOME=\"$ours\"" '# <<< rea-installer <<<' >"$work/home/.bash_profile"
    sandbox "$MACOS" "$mode; write_profile; printf 'JAVA_HOME=%s\n' \"\${JAVA_HOME:-}\""
    if [ "$rc" -ne 0 ] || ! grep -qF 'does not run' "$work/out" || ! grep -qx 'JAVA_HOME=' "$work/out" ||
      grep -q '^export JAVA_HOME=' "$work/home/.bash_profile" || grep -qx '# >>> rea-installer >>>' "$work/home/.bash_profile" ||
      ! grep -qx '# user line' "$work/home/.bash_profile"; then
      all_ok=false; printf '    mode: %s\n' "$mode"; show; sed 's/^/    /' "$work/home/.bash_profile" 2>/dev/null
    fi
  done
  if [ "$all_ok" = true ]; then ok "$n"; else bad "$n"; fi
else
  skip "$n (macOS only)"
fi
fresh_home
mkjdk "$ours" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'export JAVA_HOME="$work/jdks/17"; install_jdk; install_jdk; printf "JAVA_HOME=%s\n" "$JAVA_HOME"'
if [ "$rc" -eq 0 ] && [ "$(grep -c 'which is not JDK 21 or newer' "$work/out")" = 1 ] && grep -qxF "JAVA_HOME=$ours" "$work/out"; then
  ok "JAVA-02 macOS install_jdk replaces a JDK 17 JAVA_HOME with openjdk@21"
else
  bad "JAVA-02 macOS install_jdk replaces a JDK 17 JAVA_HOME with openjdk@21"; show
fi
# A failing brew --prefix must stop a real run, never yield a path that starts with /libexec (WR-07).
stub brew 'exit 1'
fresh_home
sandbox "$MACOS" 'unset JAVA_HOME; install_jdk; echo continued'
if [ "$rc" -ne 0 ] && grep -qF 'brew --prefix failed' "$work/out" && ! grep -qx continued "$work/out" &&
  ! grep -qE '(^|[ "=])/libexec/' "$work/out"; then
  ok "JAVA-02 macOS install_jdk stops when brew cannot locate openjdk@21"
else
  bad "JAVA-02 macOS install_jdk stops when brew cannot locate openjdk@21"; show
fi
# A user with Ghidra and no owned JDK never needs brew --prefix, whatever their JAVA_HOME (IN-03).
n="JAVA-03 macOS install_ghidra with Ghidra present and no owned JDK does not need brew --prefix"
all_ok=true
for mode in 'unset JAVA_HOME' "export JAVA_HOME=\"$work/jdks/17\"" "export JAVA_HOME=\"$work/jdks/21.0.5\""; do
  fresh_home
  sandbox "$MACOS" "$mode; install_ghidra; profile_exports+=(\"export REA_TEST=1\"); write_profile; echo continued"
  if [ "$rc" -ne 0 ] || ! grep -qF 'Ghidra already available' "$work/out" || ! grep -qx continued "$work/out" ||
    grep -qF 'brew --prefix failed' "$work/out" || grep -q '^export JAVA_HOME=' "$work/home/.bash_profile" 2>/dev/null; then
    all_ok=false; printf '    mode: %s\n' "$mode"; show
  fi
done
if [ "$all_ok" = true ]; then ok "$n"; else bad "$n"; fi
# A user's own JAVA_HOME line is not proof of ownership and must not need brew --prefix (IN-01).
n="JAVA-03 macOS jdk_owned ignores a user JAVA_HOME line outside its profile block"
fresh_home
# shellcheck disable=SC2016  # a literal user profile line
printf '%s\n' 'export JAVA_HOME="$(/usr/libexec/java_home -v 21)"' >"$work/home/.bash_profile"
sandbox "$MACOS" 'unset JAVA_HOME; install_ghidra; profile_exports+=("export REA_TEST=1"); write_profile; echo continued'
# shellcheck disable=SC2016  # a literal user profile line
if [ "$rc" -eq 0 ] && grep -qF 'Ghidra already available' "$work/out" && grep -qx continued "$work/out" &&
  ! grep -qF 'brew --prefix failed' "$work/out" &&
  grep -qxF 'export JAVA_HOME="$(/usr/libexec/java_home -v 21)"' "$work/home/.bash_profile" &&
  [ "$(grep -c '^export JAVA_HOME=' "$work/home/.bash_profile")" = 1 ]; then
  ok "$n"
else
  bad "$n"; show; sed 's/^/    /' "$work/home/.bash_profile" 2>/dev/null
fi
rm -f "$STUBS/brew" "$STUBS/ghidraRun"
# A dry run on a Mac without Homebrew plans the default prefix. The PATH leaves out any real brew.
case "$(uname -m)" in arm64) p=/opt/homebrew ;; *) p=/usr/local ;; esac
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'PATH="$STUBS:/usr/bin:/bin"; dry_run=true; unset JAVA_HOME; install_jdk; printf "JAVA_HOME=%s\n" "$JAVA_HOME"'
if [ "$rc" -eq 0 ] && grep -qF 'brew not found; the dry-run plan assumes' "$work/out" &&
  grep -qxF "JAVA_HOME=$p/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" "$work/out"; then
  ok "JAVA-02 macOS dry run without brew plans the default Homebrew JDK path"
else
  bad "JAVA-02 macOS dry run without brew plans the default Homebrew JDK path"; show
fi

# ---------------------------------------------------------------- MAC-01/02 unattended install (no terminal, --yes)
# Every check sets TTY_PATH after sourcing: "$work/no-tty" does not exist (no terminal), "$work/tty-yes" opens and reads y
# (a stand-in terminal), so results match from a terminal or an agent. Never call do_install, do_uninstall or load_brew here.
printf 'y\n' >"$work/tty-yes"
n="MAC-01 macOS rea setup without a terminal warns and continues"
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'TTY_PATH="$work/no-tty"; dry_run=true; assume_yes=false; register_agents /x/rea; echo continued'
if [ "$rc" -eq 0 ] && grep -qxF "warning: no terminal available; run '/x/rea setup' yourself." "$work/out" &&
  grep -qxF continued "$work/out" && ! grep -q '^  \$ /x/rea' "$work/out"; then ok "$n"; else bad "$n"; show; fi
n="MAC-01 macOS rea setup with a terminal runs it interactively"
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'TTY_PATH="$work/tty-yes"; dry_run=true; assume_yes=false; register_agents /x/rea'
if [ "$rc" -eq 0 ] && grep -qxF '  $ /x/rea setup' "$work/out" && ! grep -qF 'no terminal available' "$work/out"; then ok "$n"; else bad "$n"; show; fi
n="MAC-01 macOS rea setup under --yes registers every detected agent"
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'TTY_PATH="$work/no-tty"; dry_run=true; assume_yes=true; register_agents /x/rea'
if [ "$rc" -eq 0 ] && grep -qxF '  $ /x/rea setup --yes --all-detected' "$work/out"; then ok "$n"; else bad "$n"; show; fi
# Asserting the warning, not just a "no", is what makes these fail on the old confirm, which already returned 1 at its call sites.
for script in "$MACOS" "$LINUX"; do
  name="$(basename "$script")"
  n="MAC-01 confirm without a terminal answers no and warns ($name)"
  fresh_home
  # shellcheck disable=SC2016  # expanded inside the sandbox
  sandbox "$script" 'TTY_PATH="$work/no-tty"; assume_yes=false
    if confirm "Remove Homebrew (installed by this script)?" Homebrew; then echo yes; else echo no; fi'
  if [ "$rc" -eq 0 ] && grep -qxF no "$work/out" && grep -qxF 'warning: no terminal available; leaving Homebrew in place.' "$work/out" &&
    ! grep -qE 'Device not configured|No such device|/dev/tty' "$work/out"; then ok "$n"; else bad "$n"; show; fi
  n="MAC-01 confirm with a terminal reads the answer ($name)"
  fresh_home
  # shellcheck disable=SC2016  # expanded inside the sandbox
  sandbox "$script" 'TTY_PATH="$work/tty-yes"; assume_yes=false
    if confirm "Remove Homebrew (installed by this script)?" Homebrew; then echo yes; else echo no; fi'
  if grep -qxF yes "$work/out" && ! grep -qF 'no terminal available' "$work/out"; then ok "$n"; else bad "$n"; show; fi
  n="MAC-01 confirm under --yes answers yes without a terminal ($name)"
  fresh_home
  # shellcheck disable=SC2016  # expanded inside the sandbox
  sandbox "$script" 'TTY_PATH="$work/no-tty"; assume_yes=true
    if confirm "Remove Homebrew (installed by this script)?" Homebrew; then echo yes; else echo no; fi'
  if grep -qxF yes "$work/out" && ! grep -qF 'no terminal available' "$work/out"; then ok "$n"; else bad "$n"; show; fi
  n="MAC-01 an inherited TTY_PATH cannot pre-answer prompts ($name)"
  fresh_home
  export TTY_PATH="$work/tty-yes"
  # shellcheck disable=SC2016  # expanded inside the sandbox
  sandbox "$script" 'printf "TTY_PATH=%s\n" "$TTY_PATH"'
  unset TTY_PATH
  if grep -qxF 'TTY_PATH=/dev/tty' "$work/out"; then ok "$n"; else bad "$n"; show; fi
done
n="MAC-01 Linux rea setup without a terminal warns and continues"
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$LINUX" 'TTY_PATH="$work/no-tty"; dry_run=true; assume_yes=false; register_agents /x/rea; echo continued'
if [ "$rc" -eq 0 ] && grep -qxF "warning: no terminal available; run '/x/rea setup' yourself." "$work/out" &&
  grep -qxF continued "$work/out" && ! grep -q '^  \$ /x/rea' "$work/out"; then ok "$n"; else bad "$n"; show; fi
# The PATH leaves out any real brew; curl is stubbed so Homebrew's real installer is never fetched.
stub curl 'echo "echo brew-installer"'
n="MAC-02 macOS --yes installs Homebrew with NONINTERACTIVE=1 after sudo -v"
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'PATH="$STUBS:/usr/bin:/bin"; TTY_PATH="$work/tty-yes"; dry_run=true; assume_yes=true; install_homebrew; echo continued'
s="$(grep -nxF '  $ sudo -v' "$work/out" | cut -d: -f1)"
e="$(grep -n '^  \$ env NONINTERACTIVE=1 /bin/bash -c ' "$work/out" | head -1 | cut -d: -f1)"
if [ "$rc" -eq 0 ] && [ -n "$s" ] && [ -n "$e" ] && [ "$s" -lt "$e" ] && grep -qxF continued "$work/out"; then ok "$n"; else bad "$n"; show; fi
n="MAC-02 macOS --yes clears the sudo ticket after Homebrew's installer"
k="$(grep -nxF '  $ sudo -k' "$work/out" | cut -d: -f1)"
if [ "$rc" -eq 0 ] && [ -n "$e" ] && [ -n "$k" ] && [ "$e" -lt "$k" ]; then ok "$n"; else bad "$n"; show; fi
n="MAC-02 macOS --yes without a terminal skips sudo -v"
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'PATH="$STUBS:/usr/bin:/bin"; TTY_PATH="$work/no-tty"; dry_run=true; assume_yes=true; install_homebrew; echo continued'
if [ "$rc" -eq 0 ] && grep -q '^  \$ env NONINTERACTIVE=1 /bin/bash -c ' "$work/out" && ! grep -qxF '  $ sudo -v' "$work/out" &&
  ! grep -qxF '  $ sudo -k' "$work/out" && grep -qxF continued "$work/out"; then ok "$n"; else bad "$n"; show; fi
n="MAC-02 macOS Homebrew without --yes is not forced non-interactive"
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'PATH="$STUBS:/usr/bin:/bin"; TTY_PATH="$work/tty-yes"; dry_run=true; assume_yes=false; install_homebrew; echo continued'
if [ "$rc" -eq 0 ] && grep -q '^  \$ /bin/bash -c ' "$work/out" && ! grep -qF NONINTERACTIVE "$work/out" &&
  ! grep -qxF '  $ sudo -v' "$work/out" && grep -qxF continued "$work/out"; then ok "$n"; else bad "$n"; show; fi
shellenv="eval \"\$($p/bin/brew shellenv)\""
n="MAC-02 macOS profile block puts a recorded Homebrew on PATH"
fresh_home
mkdir -p "$work/home/.rea-installer"
printf 'homebrew\n' >"$work/home/.rea-installer/installed"
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'PATH="$STUBS:/usr/bin:/bin"; dry_run=false; write_profile'
block="$(sed -n '/^# >>> rea-installer >>>$/,/^# <<< rea-installer <<<$/p' "$work/home/.bash_profile" 2>/dev/null)"
if [ "$rc" -eq 0 ] && grep -qxF "$shellenv" <<<"$block" &&
  grep -qxF "profile:$work/home/.bash_profile" "$work/home/.rea-installer/installed"; then
  ok "$n"
else
  bad "$n"; show; sed 's/^/    /' "$work/home/.bash_profile" 2>/dev/null
fi
n="MAC-02 macOS profile block has no shellenv line when Homebrew was not installed by the script"
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'PATH="$STUBS:/usr/bin:/bin"; dry_run=false; profile_exports+=("export REA_TEST=1"); write_profile'
if [ "$rc" -eq 0 ] && grep -qxF 'export REA_TEST=1' "$work/home/.bash_profile" 2>/dev/null &&
  ! grep -qF shellenv "$work/home/.bash_profile"; then ok "$n"; else bad "$n"; show; sed 's/^/    /' "$work/home/.bash_profile" 2>/dev/null; fi
n="MAC-02 macOS dry run that installs Homebrew plans the shellenv line and writes nothing"
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'PATH="$STUBS:/usr/bin:/bin"; dry_run=true; assume_yes=false; install_homebrew; write_profile'
if [ "$rc" -eq 0 ] && grep -qxF "    $shellenv" "$work/out" && [ ! -e "$work/home/.bash_profile" ] &&
  [ ! -e "$work/home/.rea-installer/installed" ]; then ok "$n"; else bad "$n"; show; fi
# Real runs: curl's stub script only exits, so neither Homebrew's installer nor sudo runs, and TTY_PATH points at a
# missing path so sudo -v is never planned outside a dry run (the sudo stub from FAIL-02 is still on PATH).
stub curl 'echo "exit 1"'
n="MAC-02 macOS failed Homebrew install stops with a sudo hint and records nothing"
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'PATH="$STUBS:/usr/bin:/bin"; TTY_PATH="$work/no-tty"; dry_run=false; assume_yes=true; install_homebrew; echo continued'
if [ "$rc" -ne 0 ] && grep -qxF "error: Homebrew install failed; it needs sudo. Run 'sudo -v' and rerun, or install Homebrew first." "$work/out" &&
  ! grep -qxF continued "$work/out" && ! grep -qx homebrew "$work/home/.rea-installer/installed" 2>/dev/null; then ok "$n"; else bad "$n"; show; fi
n="MAC-02 macOS --yes clears the sudo ticket when Homebrew's installer fails"
fresh_home
# A sandbox function, so the shared sudo stub on PATH stays as later checks expect.
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'PATH="$STUBS:/usr/bin:/bin"; TTY_PATH="$work/tty-yes"; dry_run=false; assume_yes=true
  sudo() { printf "sudo-called %s\n" "$*"; }; install_homebrew; echo continued'
if [ "$rc" -ne 0 ] && grep -qxF 'sudo-called -k' "$work/out" &&
  grep -qxF "error: Homebrew install failed; it needs sudo. Run 'sudo -v' and rerun, or install Homebrew first." "$work/out" &&
  ! grep -qxF continued "$work/out" && ! grep -qx homebrew "$work/home/.rea-installer/installed" 2>/dev/null; then ok "$n"; else bad "$n"; show; fi
stub curl 'exit 22'
n="MAC-02 macOS failed Homebrew download stops and records nothing"
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'PATH="$STUBS:/usr/bin:/bin"; TTY_PATH="$work/no-tty"; dry_run=false; assume_yes=false; install_homebrew; echo continued'
if [ "$rc" -ne 0 ] && grep -qxF 'error: could not download the Homebrew installer.' "$work/out" && ! grep -q '^  \$ /bin/bash -c' "$work/out" &&
  ! grep -qxF continued "$work/out" && ! grep -qx homebrew "$work/home/.rea-installer/installed" 2>/dev/null; then ok "$n"; else bad "$n"; show; fi
rm -f "$STUBS/curl"

# ---------------------------------------------------------------- DRY-01/02 fresh container
# A fresh ubuntu:24.04 has no curl or Node; --network none proves the dry run downloads nothing.
# Seeded ~/.rea-installer/node and empty ~/.agents/skills must survive. Two runs, so each gets its own line.
# The docker CLI keeps the real HOME: it reads ~/.docker for its context.
if need docker "DRY-01 Linux install --dry-run --with-android in fresh ubuntu:24.04"; then
  # shellcheck disable=SC2016  # runs inside the container
  docker run --rm --network none --platform linux/amd64 -v "$root:/src:ro" ubuntu:24.04 bash -c '
    mkdir -p ~/.rea-installer/node ~/.agents/skills
    before="$(find ~ | sort)"
    bash /src/rea-install-linux.sh install --dry-run --with-android >/tmp/i.log 2>&1 || { tail -5 /tmp/i.log; exit 1; }
    grep -q "npm install --global" /tmp/i.log || { echo "no install plan printed"; exit 1; }
    [ "$(grep -c "Would download Temurin 21" /tmp/i.log)" = 1 ] || { echo "JAVA-02: JDK planned more than once"; exit 1; }
    ! grep -q "not JDK 21 or newer" /tmp/i.log || { echo "JAVA-02: false JAVA_HOME warning"; exit 1; }
    [ "$(find ~ | sort)" = "$before" ] || { echo "dry run changed the home folder"; exit 1; }
  ' >"$work/out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then ok "DRY-01 Linux install --dry-run --with-android in fresh ubuntu:24.04"; else bad "DRY-01 Linux install --dry-run --with-android in fresh ubuntu:24.04"; show; fi
fi
if need docker "DRY-02 Linux uninstall --dry-run changes nothing"; then
  # shellcheck disable=SC2016  # runs inside the container
  docker run --rm --network none --platform linux/amd64 -v "$root:/src:ro" ubuntu:24.04 bash -c '
    mkdir -p ~/.rea-installer/node ~/.agents/skills
    before="$(find ~ | sort)"
    bash /src/rea-install-linux.sh uninstall --dry-run >/tmp/u.log 2>&1 || { tail -5 /tmp/u.log; exit 1; }
    [ "$(find ~ | sort)" = "$before" ] || { echo "dry run changed the home folder"; exit 1; }
    [ -d ~/.agents/skills ] || { echo "~/.agents/skills was removed"; exit 1; }
  ' >"$work/out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then ok "DRY-02 Linux uninstall --dry-run changes nothing"; else bad "DRY-02 Linux uninstall --dry-run changes nothing"; show; fi
fi

# ---------------------------------------------------------------- Windows (pwsh)
# The driver dot-sources the script (no command, so it only defines functions), points its folders into
# $work, and prints PASS:/FAIL: lines. Stubs first on PATH, so Get-Command rea finds the stub, never a real rea.
# Driver uses PowerShell 5.1 constructs only: the pwsh 7 parser would accept 7-only syntax.
if need pwsh "Windows checks (pwsh)"; then
  mkdir -p "$work/win/tools"
  tar -czf "$work/win/tools/foo-1.0.tar.gz" -C "$work/src" foo-1.0
  stub rea 'exit 3'
  # shellcheck disable=SC2016  # expanded by the stub
  stub npm 'case "$1" in prefix) echo /nonexistent-npm-prefix ;; *) exit 1 ;; esac'
  # shellcheck disable=SC2016  # expanded by the stub
  stub winget 'case "$1" in list) exit 1 ;; *) exit 0 ;; esac'
  mkjdk "$work/temurin" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
  cat >"$work/w.ps1" <<'EOF'
param([string]$Script, [string]$Work, [string]$Jdks, [string]$Temurin)
. $Script *> $null
# On Unix pwsh the Machine and User Path read as empty, so the real one would set PATH to ';'.
# The stub records the call so the dry-run check can see it.
function Update-SessionPath { $script:PathRefreshed = $true }
$PathRefreshed = $false
# Unix pwsh has no User scope: a test sets $env:REA_TEST_USER_<NAME> to play the user's saved value.
function Get-UserEnv([string]$Name) { return [Environment]::GetEnvironmentVariable("REA_TEST_USER_$Name") }
$ToolsDir = Join-Path $Work 'tools'
$StateDir = Join-Path $Work 'state'
$StateFile = Join-Path $StateDir 'installed'
$Downloads['fake'] = @{ Url = 'https://example.invalid/foo-1.0.tar.gz'; Sha = '00' }
function Report([bool]$Passed, [string]$Name) { if ($Passed) { "PASS: $Name" } else { "FAIL: $Name" } }

$env:STUB_TAR = 'fail'
$threw = $false
try { Expand-PinnedArchive 'fake' 'foo-1.0' | Out-Null } catch { $threw = $true; Write-Host "caught: $_" }
Report ($threw -and -not (Test-Path (Join-Path $ToolsDir 'foo-1.0'))) 'FAIL-01 Windows failed extract leaves no folder'

$env:STUB_TAR = 'ok'
$extracted = $false
try { $t = Expand-PinnedArchive 'fake' 'foo-1.0'; $extracted = Test-Path (Join-Path $t 'bin/tool') } catch { Write-Host "caught: $_" }
Report $extracted 'FAIL-01 Windows rerun extracts again'

New-Item -ItemType Directory -Force $StateDir | Out-Null
Set-Content -Path $StateFile -Value 'env:REA_TEST_FAKE_VAR'
$threw = $false
try { Invoke-Uninstall *> $null } catch { $threw = $true; Write-Host "caught: $_" }
Report ((-not $threw) -and -not (Test-Path $StateDir)) 'UNIN-01 Windows uninstall survives a failing rea'

# Same rows as the bash jdk_usable table.
$rows = @('8:False', '17:False', '21:True', '21.0.5:True', '25-ea:True', 'picked-up:True', 'garbage:False',
          'exit1:False', 'missing:False', 'empty:False')
foreach ($row in $rows) {
    $label, $want = $row -split ':', 2
    $dir = if ($label -eq 'empty') { '' } else { Join-Path $Jdks $label }
    Report ((Test-JdkUsable $dir) -eq [bool]::Parse($want)) "JAVA-02 Windows Test-JdkUsable $label"
}
Report ($ErrorActionPreference -eq 'Stop') 'JAVA-02 Windows Test-JdkUsable keeps ErrorActionPreference'

$env:JAVA_HOME = Join-Path $Jdks '21.0.5'
try { Install-Jdk } catch { Write-Host "caught: $_" }
Report (($env:JAVA_HOME -eq (Join-Path $Jdks '21.0.5')) -and -not (Test-Path $StateFile)) 'JAVA-02 Windows Install-Jdk reuses a JDK 21 JAVA_HOME'

$PathRefreshed = $false
$DryRun = $true
$env:JAVA_HOME = Join-Path $Jdks '17'
$second = @('not run')
# The second call must print nothing: no false warning, no second winget plan.
try { Install-Jdk; $second = @(Install-Jdk *>&1) } catch { Write-Host "caught: $_" }
Report (($env:JAVA_HOME -eq (Join-Path $Jdks '17')) -and ($second.Count -eq 0) -and -not (Test-Path $StateFile)) 'JAVA-01 Windows Install-Jdk -DryRun leaves JAVA_HOME unchanged and records nothing'
Report (-not $PathRefreshed) 'JAVA-01 Windows Install-Jdk -DryRun leaves the session PATH alone'
# The script is dot-sourced, so its script-scope $JdkPlanned lives here and must be reset for later cases.
$DryRun = $false
$JdkPlanned = $false

Remove-Item env:REA_TEST_DRY_VAR -ErrorAction SilentlyContinue
$DryRun = $true
Set-UserEnv 'REA_TEST_DRY_VAR' 'x' *> $null
$DryRun = $false
Report (-not (Test-Path env:REA_TEST_DRY_VAR)) 'JAVA-01 Windows Set-UserEnv -DryRun leaves the session unchanged'

$savedPath = $env:PATH
$env:JAVA_HOME = ''
$env:PATH = (Join-Path (Join-Path $Jdks '17') 'bin') + [IO.Path]::PathSeparator + $env:PATH
$msg = ''
try { Install-Jdk } catch { $msg = "$_" }
Report ($msg.Contains((Join-Path $Jdks '17'))) 'JAVA-01 Windows Install-Jdk throws when the java on PATH is not JDK 21+'
$env:PATH = $savedPath

$env:JAVA_HOME = ''
# Only the stub folder: pwsh 7 puts its own folder first on PATH, so the first entry is not it.
$env:PATH = Split-Path (Get-Command winget -CommandType Application).Source
$msg = ''
try { Install-Jdk } catch { $msg = "$_" }
Report ($msg.Contains('java is not on PATH')) 'JAVA-01 Windows Install-Jdk throws when no java is on PATH'
$env:PATH = $savedPath

# Set-UserEnv runs for real: on Unix pwsh the User-scope write is a silent no-op, and Add-Record writes to $StateFile.
# The wrong-java and no-java cases already recorded the winget line before they threw, so only a fresh ledger can show this call records it.
Remove-Item -Force $StateFile -ErrorAction SilentlyContinue
$savedPath = $env:PATH
$env:JAVA_HOME = Join-Path $Jdks '17'
$env:PATH = (Join-Path $Temurin 'bin') + [IO.Path]::PathSeparator + $env:PATH
try { Install-Jdk } catch { Write-Host "caught: $_" }
$ledger = @()
if (Test-Path $StateFile) { $ledger = @(Get-Content $StateFile) }
Report (($env:JAVA_HOME -eq $Temurin) -and ($ledger -contains 'env:JAVA_HOME') -and
        ($ledger -contains 'winget:EclipseAdoptium.Temurin.21.JDK')) 'JAVA-01 Windows Install-Jdk sets JAVA_HOME from the java on PATH and records it'
$env:PATH = $savedPath

# CR-01: a Temurin upgrade removed the folder the script saved earlier; the ledger says the script owns JAVA_HOME.
$savedPath = $env:PATH
New-Item -ItemType Directory -Force $StateDir | Out-Null
Set-Content -Path $StateFile -Value 'env:JAVA_HOME'
$stale = Join-Path $Work 'gone/jdk-21.0.4.7-hotspot'
$env:REA_TEST_USER_JAVA_HOME = $stale
$env:JAVA_HOME = $stale
$env:PATH = (Join-Path $Temurin 'bin') + [IO.Path]::PathSeparator + $env:PATH
$out = @()
try { $out = @(Install-Jdk *>&1 | ForEach-Object { "$_" }) } catch { Write-Host "caught: $_" }
Report (($env:JAVA_HOME -eq $Temurin) -and
        @($out | Where-Object { $_.Contains('setx JAVA_HOME') -and $_.Contains($Temurin) }).Count -gt 0 -and
        @($out | Where-Object { $_.Contains('leaving it as-is') }).Count -eq 0 -and
        @($out | Where-Object { $_.Contains('has no java.exe') }).Count -gt 0 -and
        @($out | Where-Object { $_.Contains('by this script') }).Count -eq 0) 'JAVA-01 Windows Install-Jdk replaces a stale user JAVA_HOME it set earlier'
$out | ForEach-Object { Write-Host $_ }
$env:PATH = $savedPath
Remove-Item env:REA_TEST_USER_JAVA_HOME -ErrorAction SilentlyContinue

# D-05: a user JAVA_HOME the script never set is left as-is; only the session gets Temurin.
$savedPath = $env:PATH
Remove-Item -Force $StateFile -ErrorAction SilentlyContinue
$env:REA_TEST_USER_JAVA_HOME = Join-Path $Work 'other/jdk-21'
$env:JAVA_HOME = Join-Path $Jdks '17'
$env:PATH = (Join-Path $Temurin 'bin') + [IO.Path]::PathSeparator + $env:PATH
$out = @()
try { $out = @(Install-Jdk *>&1 | ForEach-Object { "$_" }) } catch { Write-Host "caught: $_" }
$ledger = @()
if (Test-Path $StateFile) { $ledger = @(Get-Content $StateFile) }
Report (($env:JAVA_HOME -eq $Temurin) -and
        @($out | Where-Object { $_.Contains('leaving it as-is') }).Count -gt 0 -and
        @($out | Where-Object { $_.Contains('setx JAVA_HOME') }).Count -eq 0 -and
        -not ($ledger -contains 'env:JAVA_HOME')) 'JAVA-01 Windows Install-Jdk leaves a user JAVA_HOME it did not set'
$out | ForEach-Object { Write-Host $_ }
$env:PATH = $savedPath
Remove-Item env:REA_TEST_USER_JAVA_HOME -ErrorAction SilentlyContinue

# The ledger says the script set JAVA_HOME, but the user has since pointed it at a folder that exists, so it is kept (WR-01, D-05).
$savedPath = $env:PATH
New-Item -ItemType Directory -Force $StateDir | Out-Null
Set-Content -Path $StateFile -Value 'env:JAVA_HOME'
$env:REA_TEST_USER_JAVA_HOME = Join-Path $Jdks '17'
$env:JAVA_HOME = Join-Path $Work 'gone/jdk-21.0.4.7-hotspot'
$env:PATH = (Join-Path $Temurin 'bin') + [IO.Path]::PathSeparator + $env:PATH
$out = @()
try { $out = @(Install-Jdk *>&1 | ForEach-Object { "$_" }) } catch { Write-Host "caught: $_" }
Report (($env:JAVA_HOME -eq $Temurin) -and
        @($out | Where-Object { $_.Contains('leaving it as-is') }).Count -gt 0 -and
        @($out | Where-Object { $_.Contains('setx JAVA_HOME') }).Count -eq 0) 'JAVA-01 Windows Install-Jdk keeps an existing user JAVA_HOME even when it set one earlier'
$out | ForEach-Object { Write-Host $_ }
$env:PATH = $savedPath
Remove-Item env:REA_TEST_USER_JAVA_HOME -ErrorAction SilentlyContinue

# The MSI can leave the old folder behind without java.exe, which still counts as dead (WR-02).
$savedPath = $env:PATH
New-Item -ItemType Directory -Force $StateDir | Out-Null
Set-Content -Path $StateFile -Value 'env:JAVA_HOME'
$leftover = Join-Path $Work 'leftover/jdk-21.0.4.7-hotspot'
New-Item -ItemType Directory -Force (Join-Path $leftover 'lib') | Out-Null
$env:REA_TEST_USER_JAVA_HOME = $leftover
$env:JAVA_HOME = $leftover
$env:PATH = (Join-Path $Temurin 'bin') + [IO.Path]::PathSeparator + $env:PATH
$out = @()
try { $out = @(Install-Jdk *>&1 | ForEach-Object { "$_" }) } catch { Write-Host "caught: $_" }
Report (($env:JAVA_HOME -eq $Temurin) -and
        @($out | Where-Object { $_.Contains('setx JAVA_HOME') -and $_.Contains($Temurin) }).Count -gt 0 -and
        @($out | Where-Object { $_.Contains('has no java.exe') }).Count -gt 0 -and
        @($out | Where-Object { $_.Contains('leaving it as-is') }).Count -eq 0) 'JAVA-01 Windows Install-Jdk replaces a saved JAVA_HOME it set whose folder has no java.exe'
$out | ForEach-Object { Write-Host $_ }
$env:PATH = $savedPath
Remove-Item env:REA_TEST_USER_JAVA_HOME -ErrorAction SilentlyContinue
EOF
  # Temp HOME so pwsh's caches and the script's default folders never touch the real one.
  PATH="$stub_path" HOME="$work/pwsh-home" pwsh -NoProfile -File "$work/w.ps1" -Script "$WIN" -Work "$work/win" \
    -Jdks "$work/jdks" -Temurin "$work/temurin" >"$work/out" 2>&1
  results=false
  while IFS= read -r line; do
    case "$line" in
      "PASS: "*) ok "${line#PASS: }"; results=true ;;
      "FAIL: "*) bad "${line#FAIL: }"; results=true ;;
    esac
  done <"$work/out"
  if [ "$results" = false ]; then
    bad "Windows checks (pwsh driver produced no results)"; show
  elif grep -q '^FAIL: ' "$work/out"; then
    grep -v '^PASS: \|^FAIL: ' "$work/out" | sed 's/^/    /'
  fi
  rm -f "$STUBS/rea" "$STUBS/npm" "$STUBS/winget"
fi

printf '%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
