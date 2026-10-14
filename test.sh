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
stub_path="$STUBS:$PATH"
rc=0

# Writes an executable stub NAME on the sandbox PATH that runs BODY.
stub() { printf '#!/bin/sh\n%s\n' "$2" >"$STUBS/$1"; chmod +x "$STUBS/$1"; }
# Writes a stub JDK: DIR/bin/java runs BODY.
mkjdk() { mkdir -p "$1/bin"; printf '#!/bin/sh\n%s\n' "$2" >"$1/bin/java"; chmod +x "$1/bin/java"; }

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

# ---------------------------------------------------------------- JAVA-02 Linux install_jdk
# Every sandbox sets JAVA_HOME itself: the GitHub ubuntu runner exports its own.
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

# ---------------------------------------------------------------- JAVA-02/03/04 macOS install_jdk and profile
# Stub brew: --prefix points under the temp HOME, list says installed so brew_install never installs.
# Never call load_brew or do_install here: the real brew would come first on PATH.
# shellcheck disable=SC2016  # expanded by the stub
stub brew 'case "$1" in --prefix) echo "$HOME/brew/opt/$2" ;; list) exit 0 ;; *) exit 1 ;; esac'
ours="$work/home/brew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
# The second write runs remove_profile_block, which uses BSD sed -i ''.
if [ "$(uname -s)" = Darwin ]; then
  fresh_home
  mkjdk "$ours" "echo 'openjdk version \"21.0.5\" 2024-10-15' >&2"
  sandbox "$MACOS" 'unset JAVA_HOME; install_jdk; write_profile'
  rc1=$rc
  first_warned=false
  grep -q 'not JDK 21' "$work/out" && first_warned=true
  # shellcheck disable=SC2016  # expanded inside the sandbox
  sandbox "$MACOS" 'export JAVA_HOME="$(jdk_home)"; write_profile'
  if [ "$rc1" -eq 0 ] && [ "$rc" -eq 0 ] && [ "$first_warned" = false ] &&
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
fresh_home
# shellcheck disable=SC2016  # expanded inside the sandbox
sandbox "$MACOS" 'export JAVA_HOME="$work/jdks/21.0.5"; install_jdk; profile_exports+=("export REA_TEST=1"); write_profile; printf "JAVA_HOME=%s\n" "$JAVA_HOME"'
if [ "$rc" -eq 0 ] && grep -qF "Using JDK at $work/jdks/21.0.5" "$work/out" && grep -qxF "JAVA_HOME=$work/jdks/21.0.5" "$work/out" &&
  grep -qx 'export REA_TEST=1' "$work/home/.bash_profile" && ! grep -q '^export JAVA_HOME=' "$work/home/.bash_profile"; then
  ok "JAVA-03 macOS reused JDK 21 JAVA_HOME is not written to the profile"
else
  bad "JAVA-03 macOS reused JDK 21 JAVA_HOME is not written to the profile"; show
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
rm -f "$STUBS/brew"

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
  cat >"$work/w.ps1" <<'EOF'
param([string]$Script, [string]$Work)
. $Script *> $null
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
EOF
  # Temp HOME so pwsh's caches and the script's default folders never touch the real one.
  PATH="$stub_path" HOME="$work/pwsh-home" pwsh -NoProfile -File "$work/w.ps1" -Script "$WIN" -Work "$work/win" >"$work/out" 2>&1
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
  rm -f "$STUBS/rea" "$STUBS/npm"
fi

printf '%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
