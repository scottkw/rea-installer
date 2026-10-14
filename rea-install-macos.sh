#!/bin/bash
# Install or uninstall REA (https://github.com/morluto/rea) and its dependencies on macOS.
#
#   ./rea-install-macos.sh install   [--no-ghidra] [--with-android] [--with-extras] [--yes] [--dry-run]
#   ./rea-install-macos.sh uninstall [--yes] [--dry-run]
#
#   --with-android  JADX headless jar, Apktool, adb (APK decompilation, resources, devices)
#   --with-extras   Rizin, GNU binutils (objdump), WABT (offline native and WASM analysis)
#
# Everything this script adds is recorded in ~/.rea-installer/installed, so uninstall removes
# only what it installed and leaves pre-existing tools (Node, JDKs, Homebrew) alone.
set -euo pipefail

STATE_DIR="$HOME/.rea-installer"
STATE_FILE="$STATE_DIR/installed"
PACKAGE="rea-agents"
JDK_FORMULA="openjdk@21"
# Pinned by REA: docs/android-analysis.md
JADX_URL="https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar"
JADX_SHA256="6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75"
JADX_JAR="$STATE_DIR/jadx-headless-mcp-0.7.1-all.jar"
PROFILE_BEGIN="# >>> rea-installer >>>"
PROFILE_END="# <<< rea-installer <<<"

assume_yes=false
dry_run=false
with_ghidra=true
with_android=false
with_extras=false
profile_exports=()

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

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; }

# ---------------------------------------------------------------- environment

load_brew() {
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$b" ] && { eval "$("$b" shellenv)"; return 0; }
  done
  return 1
}

# nvm-managed Node is a shell function in interactive shells, not on PATH here.
load_nvm() {
  command -v node >/dev/null 2>&1 && return 0
  local f
  for f in "${NVM_DIR:-$HOME/.nvm}/nvm.sh" /opt/homebrew/opt/nvm/nvm.sh /usr/local/opt/nvm/nvm.sh; do
    if [ -s "$f" ]; then
      set +u
      export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
      # shellcheck disable=SC1090
      . "$f"
      set -u
      return 0
    fi
  done
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
    *) printf '%s/.bash_profile' "$HOME" ;;
  esac
}

# Usage: brew_install [--cask] NAME
brew_install() {
  local kind=brew name="${!#}"
  [ "$1" = --cask ] && kind=cask
  if brew list --versions "$@" >/dev/null 2>&1; then
    log "$name already installed (left as-is)"
  else
    # Explicit line because brew's own stderr can be empty (e.g. a killed process).
    run brew install "$@" || { warn "brew install $name failed."; return 1; }
    record "$kind:$name"
  fi
}

hopper_apps() {
  ls -d /Applications/Hopper*.app "$HOME"/Applications/Hopper*.app 2>/dev/null || true
}

remove_profile_block() {
  local file="$1"
  [ -f "$file" ] && grep -qxF "$PROFILE_BEGIN" "$file" || return 0
  run sed -i '' "/^$PROFILE_BEGIN\$/,/^$PROFILE_END\$/d" "$file"
}

# ---------------------------------------------------------------- install

# The opt path stays valid across brew upgrade, and brew --prefix prints it even before the formula is installed.
# Callers capture this with $(...), so they must use a plain assignment: only that lets set -e stop the run on die.
jdk_home() {
  local prefix="" have_brew=false
  command -v brew >/dev/null 2>&1 && have_brew=true
  if [ "$have_brew" = true ]; then
    prefix="$(brew --prefix "$JDK_FORMULA")" || prefix=""
  fi
  if [ -z "$prefix" ]; then
    # A dry run on a Mac without Homebrew only plans step 2's install, so assume where it would put the formula.
    if [ "$dry_run" = true ] && [ "$have_brew" = false ]; then
      if [ "$(uname -m)" = arm64 ]; then prefix="/opt/homebrew/opt/$JDK_FORMULA"; else prefix="/usr/local/opt/$JDK_FORMULA"; fi
      warn "brew not found; the dry-run plan assumes Homebrew's default prefix $prefix."
    else
      die "could not locate Homebrew's $JDK_FORMULA (brew --prefix failed)."
    fi
  fi
  printf '%s/libexec/openjdk.jdk/Contents/Home' "$prefix"
}

# Ownership comes from what the script installed, not the caller's environment, so a rerun from a shell that never sourced the block keeps our JAVA_HOME (JAVA-04).
jdk_owned() {
  grep -qxF "brew:$JDK_FORMULA" "$STATE_FILE" 2>/dev/null || grep -qxF "export JAVA_HOME=\"$1\"" "$(profile_file)" 2>/dev/null
}

install_jdk() {
  local ours
  ours="$(jdk_home)"
  if [ "${JAVA_HOME:-}" != "$ours" ]; then
    if jdk_usable "${JAVA_HOME:-}"; then
      log "Using JDK at $JAVA_HOME"
      return
    fi
    [ -z "${JAVA_HOME:-}" ] || warn "JAVA_HOME points at $JAVA_HOME, which is not JDK 21 or newer; installing the script's own JDK 21."
  fi
  brew_install "$JDK_FORMULA"
  # REA validates the JDK via JAVA_HOME; setup copies it into agent registrations.
  export JAVA_HOME="$ours"
  [ "$dry_run" = true ] || jdk_usable "$ours" || die "Homebrew $JDK_FORMULA at $ours does not run."
}

install_jadx_jar() {
  if [ -f "$JADX_JAR" ]; then
    log "JADX jar already present"
  else
    log "Downloading jadx-headless-mcp 0.7.1"
    run mkdir -p "$STATE_DIR"
    run curl -fsSL --proto '=https' -o "$JADX_JAR.part" "$JADX_URL"
    if [ "$dry_run" = false ]; then
      if ! printf '%s  %s\n' "$JADX_SHA256" "$JADX_JAR.part" | shasum -a 256 -c - >/dev/null; then
        rm -f "$JADX_JAR.part"
        die "JADX jar checksum mismatch; refusing to use it."
      fi
      mv "$JADX_JAR.part" "$JADX_JAR"
    fi
  fi
  export REA_JADX_MCP_JAR="$JADX_JAR"
}

install_ghidra() {
  local ours
  ours="$(jdk_home)"
  if command -v ghidraRun >/dev/null 2>&1 || [ -n "${GHIDRA_INSTALL_DIR:-}" ]; then
    log "Ghidra already available (left as-is)"
    if jdk_owned "$ours"; then
      install_jdk
    fi
  else
    install_jdk
    # ghidra depends on openjdk@21; installing it ourselves records it, so uninstall removes it.
    if [ "${JAVA_HOME:-}" != "$ours" ]; then
      brew_install "$JDK_FORMULA"
    fi
    brew_install ghidra
  fi
}

write_profile() {
  # Only the script's own JDK goes in the block: a reused user JAVA_HOME is never written (JAVA-03), and a rerun that skips install_jdk keeps ours (JAVA-04).
  if [ -n "${JAVA_HOME:-}" ]; then
    local ours
    ours="$(jdk_home)"
    if [ "$JAVA_HOME" = "$ours" ]; then
      profile_exports+=("export JAVA_HOME=\"$JAVA_HOME\"")
    fi
  fi
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
}

do_install() {
  [ "$(uname -s)" = Darwin ] || die "this script supports macOS only."

  # 1. Xcode Command Line Tools (Homebrew, and REA's macOS process-capture helper via swiftc)
  if ! xcode-select -p >/dev/null 2>&1; then
    log "Installing Xcode Command Line Tools"
    run xcode-select --install
    record "clt"
    [ "$dry_run" = true ] || die "finish the Command Line Tools installer dialog, then rerun this script."
  fi

  # 2. Homebrew
  if ! load_brew; then
    log "Installing Homebrew"
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    record "homebrew"
    [ "$dry_run" = true ] || load_brew || die "Homebrew installed but brew was not found."
  fi

  # 3. Node.js + npm
  load_nvm
  if node_supported; then
    log "Using Node.js $(node --version) at $(command -v node)"
  else
    command -v node >/dev/null 2>&1 && warn "Node.js $(node --version) is unsupported; installing Homebrew node."
    brew_install node
    PATH="$(brew --prefix)/bin:$PATH"
    [ "$dry_run" = true ] || node_supported || die "Homebrew node $(node --version) is still unsupported."
  fi
  command -v npm >/dev/null 2>&1 || [ "$dry_run" = true ] || die "npm not found next to node."

  # 4. Ghidra (free native-analysis engine) + its JDK
  if [ "$with_ghidra" = true ]; then
    install_ghidra
  fi

  # 5. Android: JADX needs a full JDK; Apktool and adb are found on PATH.
  if [ "$with_android" = true ]; then
    install_jdk
    install_jadx_jar
    brew_install apktool
    brew_install --cask android-platform-tools
  fi

  # 6. Offline tools. Homebrew's binutils is keg-only and macOS's objdump is LLVM's, so point REA at GNU's.
  if [ "$with_extras" = true ]; then
    brew_install rizin
    brew_install binutils
    brew_install wabt
    profile_exports+=("export REA_OBJDUMP_COMMAND=\"$(brew --prefix binutils)/bin/objdump\"")
    profile_exports+=("export REA_WABT_BIN_DIRECTORY=\"$(brew --prefix wabt)/bin\"")
  fi

  # 7. Shell profile: setup does not copy objdump/WABT settings into agent registrations.
  write_profile

  # 8. REA CLI
  log "Installing $PACKAGE"
  run npm install --global "$PACKAGE@latest"
  local rea_bin
  rea_bin="$(npm prefix --global)/bin/rea"
  record "npm:$(command -v npm)"
  [ "$dry_run" = true ] || [ -x "$rea_bin" ] || die "npm finished but $rea_bin is missing."

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

  log "Done. Open a new terminal, restart your agent(s), then check health with: $rea_bin doctor"
}

# ---------------------------------------------------------------- uninstall

do_uninstall() {
  load_brew || true
  load_nvm
  local state line
  state="$(cat "$STATE_FILE" 2>/dev/null || true)"

  # 1. Agent registrations, skills and ~/.rea cache/state (needs the CLI, so first).
  local npm_bin rea_bin=""
  npm_bin="$(sed -n 's/^npm://p' <<<"$state" | tail -1)"
  [ -x "$npm_bin" ] || npm_bin="$(command -v npm || true)"
  [ -n "$npm_bin" ] && rea_bin="$("$npm_bin" prefix --global)/bin/rea"
  [ -x "$rea_bin" ] || rea_bin="$(command -v rea || true)"
  if [ -n "$rea_bin" ]; then
    log "Removing REA agent registrations, skills and data"
    run "$rea_bin" uninstall --purge-data || warn "rea uninstall failed; remove agent registrations by hand."
  else
    warn "rea CLI not found; skipping agent deregistration."
  fi

  # 2. REA CLI
  if [ -n "$npm_bin" ] && "$npm_bin" ls --global "$PACKAGE" >/dev/null 2>&1; then
    log "Removing $PACKAGE"
    run "$npm_bin" uninstall --global "$PACKAGE"
  fi

  # 3. Everything else we recorded, newest first (ghidra before its JDK, node last).
  while IFS= read -r line; do
    case "$line" in
      app:*)
        line="${line#app:}"
        if [ -e "$line" ] && confirm "Remove $line (installed by rea setup)?"; then
          run rm -rf "$line"
        fi
        ;;
      profile:*)
        log "Removing REA settings from ${line#profile:}"
        remove_profile_block "${line#profile:}"
        ;;
      cask:*)
        line="${line#cask:}"
        if brew list --cask --versions "$line" >/dev/null 2>&1; then
          log "Removing $line"
          run brew uninstall --cask "$line"
        fi
        ;;
      brew:*)
        line="${line#brew:}"
        if brew list --versions "$line" >/dev/null 2>&1; then
          if brew uses --installed "$line" | grep -q .; then
            warn "$line is now needed by other formulae; leaving it installed."
          else
            log "Removing $line"
            run brew uninstall "$line"
          fi
        fi
        ;;
    esac
  done < <(tail -r <<<"$state")

  # 4. Homebrew and Command Line Tools, only if we installed them.
  if grep -qxF homebrew <<<"$state" && confirm "Remove Homebrew (installed by this script)?"; then
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
  fi
  if grep -qxF clt <<<"$state" && confirm "Remove Xcode Command Line Tools (installed by this script)?"; then
    run sudo rm -rf /Library/Developer/CommandLineTools
  fi

  # Also removes the downloaded JADX jar.
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
