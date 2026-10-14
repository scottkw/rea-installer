#!/bin/bash
# Install or uninstall REA (https://github.com/morluto/rea) and its dependencies on Linux
# (apt, dnf or pacman distributions; x64 or arm64).
#
#   ./rea-install-linux.sh install   [--no-ghidra] [--with-android] [--with-extras] [--with-linux-tools] [--yes] [--dry-run]
#   ./rea-install-linux.sh uninstall [--yes] [--dry-run]
#
#   --with-android      JADX headless jar, Apktool, adb (APK decompilation, resources, devices)
#   --with-extras       Rizin, GNU binutils (objdump), WABT (offline native and WASM analysis)
#   --with-linux-tools  TShark/capinfos, sigrok-cli, GDB, pwntools, mitmproxy, Wakaru (Linux-only REA features)
#
# System packages go through your package manager (sudo); everything else lives in ~/.rea-installer.
# Everything this script adds is recorded in ~/.rea-installer/installed, so uninstall removes
# only what it installed and leaves pre-existing tools alone.
set -euo pipefail

STATE_DIR="$HOME/.rea-installer"
STATE_FILE="$STATE_DIR/installed"
TOOLS_DIR="$STATE_DIR/tools"
NPM_PREFIX="$HOME/.local"   # same prefix as REA's own Linux installer; no root needed
PACKAGE="rea-agents"
PROFILE_BEGIN="# >>> rea-installer >>>"
PROFILE_END="# <<< rea-installer <<<"
HOPPER_LAUNCHER="/opt/hopper/bin/Hopper"

# Pinned downloads: "url sha256". JADX and Wakaru are pinned by REA's docs; the rest by their GitHub release digests.
GHIDRA="https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db"
JADX="https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar 6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75"
APKTOOL="https://github.com/iBotPeaches/Apktool/releases/download/v3.0.3/apktool_3.0.3.jar dbf930b076c6b9be08d57c449cacefc3bdd6b71ebd59b3066fc0e1f5b14f9423"
WABT_x64="https://github.com/WebAssembly/wabt/releases/download/1.0.42/wabt-1.0.42-linux-x64.tar.gz 84895407a6bbb80e918f33b16b2fb2206021c150b6bc9ff6f761263a745ab131"
WABT_arm64="https://github.com/WebAssembly/wabt/releases/download/1.0.42/wabt-1.0.42-linux-arm64.tar.gz a7632c1cc66f70886441842ecf5a2ffa91a98c79e026059458451234ad013ea8"
RIZIN_x64="https://github.com/rizinorg/rizin/releases/download/v0.9.1/rizin-v0.9.1-static-x86_64.tar.xz 9102249a9f0b6319c5334a2e5cf8d9cc3f2035e1d3def027c41f6a90f647e8cf"
UV_x64="https://github.com/astral-sh/uv/releases/download/0.12.21/uv-x86_64-unknown-linux-gnu.tar.gz 23f02075b652bb1df64178cfae41b5caf160822e720e2663568f3f5d63bc52c0"
UV_arm64="https://github.com/astral-sh/uv/releases/download/0.12.21/uv-aarch64-unknown-linux-gnu.tar.gz 030b69227b40af8c1981b7301793dc66e71ed3c796ea8688209dd268bd91ec51"
WAKARU_x64="https://github.com/pionxzh/wakaru/releases/download/v1.14.0/wakaru-linux-x64.tar.gz db0e620034723195ab426e94d00d55dbd8fd0106a928ada2563f1103196d09fa"

assume_yes=false
dry_run=false
with_ghidra=true
with_android=false
with_extras=false
with_linux_tools=false
profile_lines=()
pm=""
apt_updated=false

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

run() {
  printf '  $'; printf ' %q' "$@"; printf '\n'
  [ "$dry_run" = true ] || "$@"
}

record() {
  [ "$dry_run" = true ] && return
  mkdir -p "$STATE_DIR"
  grep -qxF "$1" "$STATE_FILE" 2>/dev/null || printf '%s\n' "$1" >>"$STATE_FILE"
}

confirm() {
  [ "$assume_yes" = true ] && return 0
  local reply
  read -r -p "$1 [y/N] " reply </dev/tty
  [[ "$reply" =~ ^[Yy] ]]
}

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

# Exports a setting for this run (so rea setup sees it) and queues it for the shell profile.
setting() {
  export "$1=$2"
  profile_lines+=("export $1=\"$2\"")
}

# Exports VAR as the absolute path of an installed command.
tool_setting() {
  local path
  path="$(command -v "$2" || true)"
  [ -z "$path" ] && [ "$dry_run" = true ] && path="/usr/bin/$2"
  if [ -n "$path" ]; then setting "$1" "$path"; else warn "$2 not found; REA will not offer it."; fi
}

arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo x64 ;;
    aarch64|arm64) echo arm64 ;;
    *) uname -m ;;
  esac
}

# ---------------------------------------------------------------- system packages

sudo_cmd() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

detect_pm() {
  local p
  for p in apt-get dnf pacman; do
    command -v "$p" >/dev/null 2>&1 && { pm="$p"; return 0; }
  done
  die "no supported package manager found (apt, dnf or pacman)."
}

# Arch forbids partial upgrades (pacman -Sy without -u), so ask for a full sync instead of doing one.
check_pacman_synced() {
  [ "$pm" = pacman ] || return 0
  compgen -G '/var/lib/pacman/sync/*.db' >/dev/null || die "pacman's package database is empty; run 'sudo pacman -Syu' first."
}

# Maps a tool to this distribution's package name.
pkg_name() {
  case "$pm:$1" in
    apt-get:ps) echo procps ;;
    *:ps) echo procps-ng ;;
    apt-get:adb) echo adb ;;
    *:adb) echo android-tools ;;
    apt-get:tshark) echo tshark ;;
    *:tshark) echo wireshark-cli ;;
    *) echo "$1" ;;
  esac
}

pkg_installed() {
  case "$pm" in
    apt-get) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed' ;;
    dnf) rpm -q "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Qi "$1" >/dev/null 2>&1 ;;
  esac
}

apt_update_once() {
  [ "$apt_updated" = true ] && return
  run sudo_cmd apt-get update -qq
  apt_updated=true
}

pkg_available() {
  [ "$dry_run" = true ] && return 0
  case "$pm" in
    apt-get) apt_update_once; apt-cache show "$1" >/dev/null 2>&1 ;;
    dnf) dnf -q info "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
  esac
}

# Names of all installed packages, sorted.
pkg_list() {
  case "$pm" in
    apt-get) dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' | awk '$1 == "ii" {print $2}' | sort -u ;;
    dnf) rpm -qa --qf '%{NAME}\n' | sort -u ;;
    pacman) pacman -Qq | sort -u ;;
  esac
}

# Installs a tool's package unless present; returns 1 (with a warning) when the distribution does not ship it.
# Records the package plus every dependency it pulled in, so uninstall can remove exactly that set.
pkg_install() {
  local name before added
  name="$(pkg_name "$1")"
  if pkg_installed "$name"; then
    log "$name already installed (left as-is)"
    return
  fi
  if ! pkg_available "$name"; then
    warn "$name is not available from $pm."
    return 1
  fi
  before="$(pkg_list)"
  case "$pm" in
    apt-get)
      # noninteractive: tshark otherwise stops to ask about non-root capture.
      run sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$name" || return 1
      ;;
    dnf) run sudo_cmd dnf install -y -q "$name" || return 1 ;;
    pacman) run sudo_cmd pacman -S --needed --noconfirm "$name" || return 1 ;;
  esac
  added="$(comm -13 <(printf '%s\n' "$before") <(pkg_list) | grep -vxF "$name" | tr '\n' ' ')"
  record "pkg:$name ${added% }"
}

# Succeeds when removing exactly these packages would take nothing else with them,
# i.e. nothing installed since still depends on them.
pkg_set_removable() {
  case "$pm" in
    apt-get)
      [ -z "$(comm -23 <(apt-get -s purge "$@" 2>/dev/null | awk '/^(Purg|Remv)/{print $2}' | sort -u) \
                       <(printf '%s\n' "$@" | sort -u))" ]
      ;;
    dnf)
      # --assumeno always exits non-zero, so read its plan rather than its status.
      local plan
      plan="$(sudo_cmd dnf remove --assumeno "$@" 2>&1 || true)"
      grep -q '^Removing:' <<<"$plan" && ! grep -qi 'dependent packages' <<<"$plan"
      ;;
    pacman) pacman -Rs --print "$@" >/dev/null 2>&1 ;;
  esac
}

pkg_remove() {
  case "$pm" in
    apt-get) run sudo_cmd apt-get purge -y -qq "$@" ;;
    dnf) run sudo_cmd dnf remove -y -q "$@" ;;
    pacman) run sudo_cmd pacman -Rs --noconfirm "$@" ;;
  esac
}

pkg_owner() {
  case "$pm" in
    apt-get) dpkg -S "$1" 2>/dev/null | head -1 | cut -d: -f1 ;;
    dnf) rpm -qf --qf '%{NAME}\n' "$1" 2>/dev/null ;;
    pacman) pacman -Qqo "$1" 2>/dev/null ;;
  esac
}

# ---------------------------------------------------------------- downloads

# Usage: fetch "url sha256" -> prints the verified local path. Refuses a file whose checksum differs.
fetch() {
  local url sha path
  read -r url sha <<<"$1"
  path="$TOOLS_DIR/$(basename "$url")"
  if [ ! -f "$path" ]; then
    log "Downloading $(basename "$url")" >&2
    run mkdir -p "$TOOLS_DIR" >&2
    run curl -fsSL --proto '=https' --retry 3 -o "$path.part" "$url" >&2
    if [ "$dry_run" = false ]; then
      if ! printf '%s  %s\n' "$sha" "$path.part" | sha256sum -c - >/dev/null 2>&1; then
        rm -f "$path.part"
        die "checksum mismatch for $(basename "$url"); refusing to use it."
      fi
      mv "$path.part" "$path"
    fi
  fi
  printf '%s\n' "$path"
}

# Usage: unpack "url sha256" DIR -> extracts into $TOOLS_DIR/DIR (unless it exists) and prints that path.
# DIR is the archive's top-level folder, or the folder its files go into when it has none (Rizin, Wakaru).
# Extracts into a staging folder and renames it only on success, so a failed or interrupted extract never
# leaves a DIR that a rerun would trust. Always called inside $(...), where set -e is off: check each step.
unpack() {
  local target="$TOOLS_DIR/$2" staging="$TOOLS_DIR/.staging-$2" archive src
  if [ ! -d "$target" ]; then
    archive="$(fetch "$1")" || exit 1
    run rm -rf "$staging" >&2
    run mkdir -p "$staging" >&2 || die "could not create $staging."
    case "$archive" in
      *.zip) run unzip -q "$archive" -d "$staging" >&2 ;;
      *) run tar -xf "$archive" -C "$staging" >&2 ;;
    esac || { run rm -rf "$staging" >&2; die "could not unpack $(basename "$archive")."; }
    src="$staging"
    [ -d "$staging/$2" ] && src="$staging/$2"
    run mv "$src" "$target" >&2 || { run rm -rf "$staging" >&2; die "could not move $2 into place."; }
    run rm -rf "$staging" "$archive" >&2
  fi
  printf '%s\n' "$target"
}

# ---------------------------------------------------------------- environment

# nvm-managed Node is a shell function in interactive shells, not on PATH here.
load_nvm() {
  command -v node >/dev/null 2>&1 && return 0
  local f="${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  if [ -s "$f" ]; then
    set +u
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    # shellcheck disable=SC1090
    . "$f"
    set -u
  fi
}

# REA requires Node.js 22.x (>=22.19), 24.x (>=24.11), or 26+; SQLite analysis needs 24.15+.
node_supported() {
  command -v node >/dev/null 2>&1 || return 1
  local major minor
  IFS=. read -r major minor _ <<<"$(node -p 'process.versions.node' 2>/dev/null)"
  [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || return 1
  ((major == 22 && minor >= 19 || major == 24 && minor >= 15 || major >= 26))
}

# Ghidra 12 and REA need JDK 21+. Reads `java -version` (stderr); a JAVA_TOOL_OPTIONS "Picked up" line may come first.
jdk_usable() {
  local out major re='version "([0-9]+)(\.([0-9]+))?'
  [ -n "$1" ] && [ -x "$1/bin/java" ] || return 1
  out="$("$1/bin/java" -version 2>&1)" || return 1
  [[ "$out" =~ $re ]] || return 1
  major="${BASH_REMATCH[1]}"
  [ "$major" = 1 ] && major="${BASH_REMATCH[3]:-0}" # "1.8.0_402" -> 8
  ((major >= 21))
}

profile_file() {
  case "$(basename "${SHELL:-}")" in
    zsh) printf '%s/.zshrc' "${ZDOTDIR:-$HOME}" ;;
    *) printf '%s/.bashrc' "$HOME" ;;
  esac
}

remove_profile_block() {
  local file="$1"
  [ -f "$file" ] && grep -qxF "$PROFILE_BEGIN" "$file" || return 0
  run sed -i "/^$PROFILE_BEGIN\$/,/^$PROFILE_END\$/d" "$file"
}

# ---------------------------------------------------------------- install

# Node.js 24 LTS from nodejs.org into ~/.rea-installer/node, verified against its SHASUMS256.txt.
install_node() {
  local base="https://nodejs.org/dist/latest-v24.x" sums line sha file
  # A dry run cannot fetch the checksum list: step 1 only printed the curl install.
  if [ "$dry_run" = true ]; then
    log "Would download Node.js 24 from $base into $STATE_DIR/node"
    PATH="$STATE_DIR/node/bin:$PATH"
    return
  fi
  sums="$(curl -fsSL --proto '=https' "$base/SHASUMS256.txt")"
  line="$(grep -E " node-v[0-9.]+-linux-$(arch)\.tar\.gz\$" <<<"$sums")" || die "no Node.js 24 build for $(arch)."
  read -r sha file <<<"$line"
  run rm -rf "$STATE_DIR/node"
  local dir
  dir="$(unpack "$base/$file $sha" "${file%.tar.gz}")"
  run mv "$dir" "$STATE_DIR/node"
  PATH="$STATE_DIR/node/bin:$PATH"
}

# Temurin 21 JDK from Adoptium into ~/.rea-installer/jdk, verified against the checksum Adoptium publishes.
install_jdk() {
  # do_install unsets inherited $STATE_DIR values, so this only matches the JDK set up earlier in this run (Ghidra, then Android).
  if [ "${JAVA_HOME:-}" = "$STATE_DIR/jdk" ]; then
    return
  fi
  if jdk_usable "${JAVA_HOME:-}"; then
    log "Using JDK at $JAVA_HOME"
    return
  fi
  [ -z "${JAVA_HOME:-}" ] || warn "JAVA_HOME points at $JAVA_HOME, which is not JDK 21 or newer; installing the script's own JDK 21."
  local fetch_jdk=false
  if [ ! -d "$STATE_DIR/jdk" ]; then
    fetch_jdk=true
  elif ! jdk_usable "$STATE_DIR/jdk"; then
    # Only the script's own folder is replaced, so a rerun recovers from a broken earlier download.
    warn "the JDK at $STATE_DIR/jdk does not run; downloading it again."
    run rm -rf "$STATE_DIR/jdk"
    fetch_jdk=true
  fi
  if [ "$fetch_jdk" = true ] && [ "$dry_run" = true ]; then
    log "Would download Temurin 21 into $STATE_DIR/jdk"
  elif [ "$fetch_jdk" = true ]; then
    local meta
    meta="$(curl -fsSL --proto '=https' "https://api.adoptium.net/v3/assets/latest/21/hotspot?architecture=$(arch | sed s/arm64/aarch64/)&image_type=jdk&os=linux&vendor=eclipse" |
      node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>{const a=JSON.parse(s)[0];console.log(a.binary.package.link,a.binary.package.checksum,a.release_name)})')"
    local link sha release dir
    read -r link sha release <<<"$meta"
    # An empty release would make dir $TOOLS_DIR itself, which the bin/java check below would then remove.
    [ -n "$release" ] || die "could not read the Temurin 21 release from Adoptium."
    dir="$(unpack "$link $sha" "$release")"
    # A layout unpack did not expect (bin/java one level deeper) must not become the trusted JDK.
    if [ ! -x "$dir/bin/java" ]; then
      run rm -rf "$dir"
      die "the Temurin archive has no bin/java under $dir; rerun to download it again."
    fi
    run mv "$dir" "$STATE_DIR/jdk"
  fi
  [ "$dry_run" = true ] || jdk_usable "$STATE_DIR/jdk" || die "the downloaded JDK at $STATE_DIR/jdk does not run."
  setting JAVA_HOME "$STATE_DIR/jdk"
}

# Creates ~/.rea-installer/venvs/NAME with uv's own Python 3.12 and installs the given pinned packages.
# A private interpreter avoids the distribution's Python: Unicorn 2.1.2 has no wheels past 3.13, mitmproxy needs 3.12+.
make_venv() {
  local name="$1" uv_dir
  shift
  if [ "$(arch)" = arm64 ]; then
    uv_dir="$(unpack "$UV_arm64" uv-aarch64-unknown-linux-gnu)" || return 1
  else
    uv_dir="$(unpack "$UV_x64" uv-x86_64-unknown-linux-gnu)" || return 1
  fi
  export UV_PYTHON_INSTALL_DIR="$STATE_DIR/python" UV_CACHE_DIR="$STATE_DIR/uv-cache"
  if [ ! -x "$STATE_DIR/venvs/$name/bin/python" ]; then
    run "$uv_dir/uv" venv -q --python 3.12 "$STATE_DIR/venvs/$name" || return 1
  fi
  run "$uv_dir/uv" pip install -q --python "$STATE_DIR/venvs/$name/bin/python" "$@"
}

do_install() {
  [ "$(uname -s)" = Linux ] || die "this script supports Linux only."
  case "$(arch)" in x64|arm64) ;; *) die "unsupported architecture $(uname -m)." ;; esac
  detect_pm
  check_pacman_synced

  # Settings that point into $STATE_DIR came from our own profile block; drop them so this run rewrites it whole.
  local v
  for v in $(compgen -e); do
    [ "$v" != PATH ] && [[ "${!v}" == "$STATE_DIR"/* ]] && unset "$v"
  done

  # 1. Base tools: REA's process supervisor needs procps ps and util-linux prlimit; downloads need curl, unzip, xz.
  pkg_install curl || die "curl is required."
  pkg_install ps || die "procps is required."
  pkg_install unzip || die "unzip is required."
  command -v xz >/dev/null 2>&1 || pkg_install "$( [ "$pm" = apt-get ] && echo xz-utils || echo xz )" || die "xz is required."
  [ -x /usr/bin/prlimit ] || pkg_install util-linux || die "util-linux (prlimit) is required."

  # 2. Node.js + npm (reusing one this script downloaded earlier)
  [ -x "$STATE_DIR/node/bin/node" ] && PATH="$STATE_DIR/node/bin:$PATH"
  load_nvm
  if node_supported; then
    log "Using Node.js $(node --version) at $(command -v node)"
  else
    command -v node >/dev/null 2>&1 && warn "Node.js $(node --version) is unsupported; installing Node.js 24 into $STATE_DIR."
    install_node
    [ "$dry_run" = true ] || node_supported || die "downloaded Node.js is still unsupported."
  fi
  case "$(command -v node || echo "$STATE_DIR/node/bin/node")" in
    "$STATE_DIR"/*) profile_lines+=("export PATH=\"$STATE_DIR/node/bin:\$PATH\"") ;;
  esac

  # 3. Ghidra (free native-analysis engine) + its JDK. Release archives ship no arm64 Linux decompiler.
  if [ "$with_ghidra" = true ]; then
    if command -v ghidraRun >/dev/null 2>&1 || [ -n "${GHIDRA_INSTALL_DIR:-}" ]; then
      log "Ghidra already available (left as-is)"
    elif [ "$(arch)" != x64 ]; then
      warn "Ghidra's release has no arm64 Linux decompiler; skipping. See REA docs/installation.md#ghidra."
    else
      install_jdk
      local ghidra_dir
      ghidra_dir="$(unpack "$GHIDRA" ghidra_12.1.4_PUBLIC)"
      setting GHIDRA_INSTALL_DIR "$ghidra_dir"
    fi
  fi

  # 4. Android: JADX needs a full JDK; adb is found on PATH; Apktool runs through a small launcher.
  if [ "$with_android" = true ]; then
    install_jdk
    local jadx_jar jar launcher="$TOOLS_DIR/apktool"
    jadx_jar="$(fetch "$JADX")"
    setting REA_JADX_MCP_JAR "$jadx_jar"
    jar="$(fetch "$APKTOOL")"
    log "Writing $launcher"
    if [ "$dry_run" = false ]; then
      # shellcheck disable=SC2016  # $JAVA_HOME and $@ expand when the launcher runs
      printf '#!/bin/sh\nexec "${JAVA_HOME:-%s}/bin/java" -jar "%s" "$@"\n' "$JAVA_HOME" "$jar" >"$launcher"
      chmod +x "$launcher"
    fi
    setting REA_APKTOOL_COMMAND "$launcher"
    pkg_install adb || warn "adb could not be installed; skipping it."
  fi

  # 5. Offline tools: Rizin and objdump are found on PATH; REA only offers WASM tools when this is set.
  if [ "$with_extras" = true ]; then
    if ! pkg_install rizin; then
      if [ "$(arch)" = x64 ]; then
        local rizin_dir
        rizin_dir="$(unpack "$RIZIN_x64" rizin-0.9.1)"
        setting REA_RIZIN_COMMAND "$rizin_dir/bin/rizin"
      else
        warn "no rizin build for this distribution and architecture; skipping it."
      fi
    fi
    pkg_install binutils || warn "binutils could not be installed; skipping it."
    local wabt="$WABT_x64" wabt_dir
    [ "$(arch)" = arm64 ] && wabt="$WABT_arm64"
    wabt_dir="$(unpack "$wabt" wabt-1.0.42)"
    setting REA_WABT_BIN_DIRECTORY "$wabt_dir/bin"
  fi

  # 6. Linux-only tools. REA's MCP server only offers these when given absolute paths.
  if [ "$with_linux_tools" = true ]; then
    pkg_install tshark || warn "tshark could not be installed; skipping it."
    pkg_install sigrok-cli || warn "sigrok-cli could not be installed; skipping it."
    pkg_install gdb || warn "gdb could not be installed; skipping it."
    tool_setting REA_TSHARK_COMMAND tshark
    tool_setting REA_CAPINFOS_COMMAND capinfos
    tool_setting REA_SIGROK_COMMAND sigrok-cli
    if [ "$(arch)" = x64 ]; then
      if make_venv pwntools pwntools==4.15.0 pyelftools==0.33 unicorn==2.1.2; then
        setting REA_PWNTOOLS_PYTHON "$STATE_DIR/venvs/pwntools/bin/python"
      else
        warn "pwntools could not be installed; skipping it."
      fi
      local wakaru_dir
      wakaru_dir="$(unpack "$WAKARU_x64" wakaru-1.14.0)"
      setting REA_WAKARU_COMMAND "$wakaru_dir/wakaru"
    else
      warn "skipping pwntools and Wakaru (REA supports them on Linux x64 only)."
    fi
    if make_venv mitmproxy mitmproxy==12.2.3; then
      setting REA_MITMDUMP_COMMAND "$STATE_DIR/venvs/mitmproxy/bin/mitmdump"
    else
      warn "mitmproxy could not be installed; skipping it."
    fi
  fi

  # 7. REA CLI
  log "Installing $PACKAGE"
  run npm install --global --prefix "$NPM_PREFIX" "$PACKAGE@latest"
  local rea_bin="$NPM_PREFIX/bin/rea"
  record "npm:$(command -v npm)"
  [ "$dry_run" = true ] || [ -x "$rea_bin" ] || die "npm finished but $rea_bin is missing."
  # Always written: on a rerun PATH may already contain it only because the old block put it there.
  profile_lines+=("export PATH=\"$NPM_PREFIX/bin:\$PATH\"")

  # 8. Shell profile, so terminals and agents started from them see the settings.
  if ((${#profile_lines[@]} > 0)); then
    local profile
    profile="$(profile_file)"
    log "Adding REA settings to $profile"
    remove_profile_block "$profile"
    if [ "$dry_run" = true ]; then
      printf '    %s\n' "$PROFILE_BEGIN" "${profile_lines[@]}" "$PROFILE_END"
    else
      printf '%s\n' "$PROFILE_BEGIN" "${profile_lines[@]}" "$PROFILE_END" >>"$profile"
    fi
    record "profile:$profile"
  fi

  # 9. Agent registration (+ optional Hopper install, which setup asks about and installs with sudo)
  local had_hopper=false
  [ -x "$HOPPER_LAUNCHER" ] && had_hopper=true
  log "Running rea setup"
  if [ "$assume_yes" = true ]; then
    run "$rea_bin" setup --yes --all-detected
  elif (: </dev/tty) 2>/dev/null; then
    run "$rea_bin" setup </dev/tty
  else
    warn "no terminal available; run '$rea_bin setup' yourself."
  fi
  if [ "$had_hopper" = false ] && [ -x "$HOPPER_LAUNCHER" ]; then
    local owner
    owner="$(pkg_owner "$HOPPER_LAUNCHER")"
    [ -n "$owner" ] && record "hopper:$owner"
  fi

  log "Done. Open a new terminal, restart your agent(s), then check health with: $rea_bin doctor"
}

# ---------------------------------------------------------------- uninstall

do_uninstall() {
  detect_pm
  load_nvm
  local state line
  state="$(cat "$STATE_FILE" 2>/dev/null || true)"
  [ -x "$STATE_DIR/node/bin/node" ] && PATH="$STATE_DIR/node/bin:$PATH"

  # 1. Agent registrations, skills and ~/.rea cache/state (needs the CLI, so first).
  local npm_bin rea_bin="$NPM_PREFIX/bin/rea"
  npm_bin="$(sed -n 's/^npm://p' <<<"$state" | tail -1)"
  [ -x "$npm_bin" ] || npm_bin="$(command -v npm || true)"
  [ -x "$rea_bin" ] || rea_bin="$(command -v rea || true)"
  if [ -n "$rea_bin" ]; then
    log "Removing REA agent registrations, skills and data"
    run "$rea_bin" uninstall --purge-data || warn "rea uninstall failed; remove agent registrations by hand."
  else
    warn "rea CLI not found; skipping agent deregistration."
  fi

  # 2. REA CLI
  if [ -n "$npm_bin" ] && "$npm_bin" ls --global --prefix "$NPM_PREFIX" "$PACKAGE" >/dev/null 2>&1; then
    log "Removing $PACKAGE"
    run "$npm_bin" uninstall --global --prefix "$NPM_PREFIX" "$PACKAGE"
  fi

  # 3. Everything else we recorded, newest first.
  local installed_now
  installed_now="$(pkg_list)"
  while IFS= read -r line; do
    case "$line" in
      profile:*)
        log "Removing REA settings from ${line#profile:}"
        remove_profile_block "${line#profile:}"
        ;;
      hopper:*)
        line="${line#hopper:}"
        if pkg_installed "$line" && confirm "Remove Hopper package $line (installed by rea setup)?"; then
          pkg_remove "$line"
        fi
        ;;
      pkg:*)
        # "pkg:NAME DEP..." -- apt leaves dependencies behind, so remove the recorded set with it.
        # dnf and pacman -Rs drop unused dependencies themselves (and dnf keeps ones protected packages need).
        local pkg_set name="${line#pkg:}"
        name="${name%% *}"
        if [ "$pm" = apt-get ]; then read -r -a pkg_set <<<"${line#pkg:}"; else pkg_set=("$name"); fi
        mapfile -t pkg_set < <(comm -12 <(printf '%s\n' "${pkg_set[@]}" | sort -u) <(printf '%s\n' "$installed_now"))
        ((${#pkg_set[@]} > 0)) || continue
        if pkg_set_removable "${pkg_set[@]}"; then
          log "Removing $name"
          pkg_remove "${pkg_set[@]}" || warn "removing $name failed; continuing."
          installed_now="$(pkg_list)"
        else
          warn "$name or its dependencies are now needed by other packages; leaving them installed."
        fi
        ;;
    esac
  done < <(tac <<<"$state")

  # REA's uninstall empties its shared skill folder but leaves it.
  [ "$dry_run" = true ] || rmdir "$HOME/.agents/skills" "$HOME/.agents" 2>/dev/null || true

  # Also removes the downloaded Node.js, JDK, Ghidra, jars, WABT, Wakaru and Python venvs.
  [ "$dry_run" = true ] || rm -rf "$STATE_DIR"
  log "REA uninstalled."
}

# ---------------------------------------------------------------- main

# Sourced (by test.sh): stop here so only the functions are defined. Run or piped into bash: fall through to main.
(return 0 2>/dev/null) && return 0
cmd="${1:-}"
[ $# -gt 0 ] && shift
while (($# > 0)); do
  case "$1" in
    --yes|-y) assume_yes=true ;;
    --dry-run) dry_run=true ;;
    --no-ghidra) with_ghidra=false ;;
    --with-android) with_android=true ;;
    --with-extras) with_extras=true ;;
    --with-linux-tools) with_linux_tools=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

case "$cmd" in
  install) do_install ;;
  uninstall) do_uninstall ;;
  -h|--help|"") usage ;;
  *) die "unknown command: $cmd (use install or uninstall)" ;;
esac
