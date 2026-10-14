# rea-installer

One-command install — and clean uninstall — of [REA (Reverse Engineer Anything)](https://github.com/morluto/rea) and the tools it uses, on macOS, Windows and Linux.

REA is an MCP server and CLI that lets AI coding agents (Claude Code, Codex, Cursor, Gemini CLI and others) inspect native binaries, JavaScript/Electron apps, .NET assemblies, Android APKs, WebAssembly, network captures and more. Its own setup (`npx rea-agents setup`) registers it with your agents, but it deliberately installs nothing else: Node.js, Ghidra, a JDK, JADX, Apktool, adb, Rizin, objdump, WABT and the Linux-only capture tools are all "caller-supplied". REA's docs list them across a couple of dozen pages, each with its own version pin and environment variable.

These scripts collect all of that into one command per platform, and record everything they add so `uninstall` can take it back out without touching anything you already had.

> **This is an unofficial, community project.** It is not affiliated with or endorsed by the REA authors. It installs REA from its official npm package, [`rea-agents`](https://www.npmjs.com/package/rea-agents). For REA itself, see [morluto/rea](https://github.com/morluto/rea) and [rea.tools](https://rea.tools/).

## Contents

- [Quick start](#quick-start)
- [The three scripts](#the-three-scripts)
- [What gets installed](#what-gets-installed)
- [Options](#options)
- [Uninstalling](#uninstalling)
- [How the scripts were engineered](#how-the-scripts-were-engineered)
- [Testing](#testing)
- [Known limitations](#known-limitations)
- [Attribution](#attribution)

## Quick start

**macOS**

```bash
./rea-install-macos.sh install                 # REA + Ghidra
./rea-install-macos.sh install --with-android --with-extras
./rea-install-macos.sh uninstall
```

**Windows** (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File .\rea-install-windows.ps1 install
powershell -ExecutionPolicy Bypass -File .\rea-install-windows.ps1 install -WithAndroid -WithExtras
powershell -ExecutionPolicy Bypass -File .\rea-install-windows.ps1 uninstall
```

**Linux** (apt, dnf or pacman distributions)

```bash
./rea-install-linux.sh install
./rea-install-linux.sh install --with-android --with-extras --with-linux-tools
./rea-install-linux.sh uninstall
```

Every script accepts `--dry-run` (`-DryRun` on Windows), which prints each command without running it, and `--help`. After installing, open a new terminal, restart your agents, and check REA's health with `rea doctor`.

## The three scripts

| Script | Platform | Language | Package source |
|---|---|---|---|
| [`rea-install-macos.sh`](rea-install-macos.sh) | macOS (Apple silicon and Intel) | Bash 3.2 (the macOS default) | Homebrew |
| [`rea-install-windows.ps1`](rea-install-windows.ps1) | Windows 10+ x64 | Windows PowerShell 5.1 / PowerShell 7 | winget, plus pinned GitHub downloads |
| [`rea-install-linux.sh`](rea-install-linux.sh) | Linux x64 and arm64 (apt, dnf, pacman) | Bash | Distribution packages, plus pinned downloads into your home directory |

All three do the same job in the same order:

1. Install the base requirements: a package manager on macOS, and a supported Node.js on every platform.
2. Install Ghidra 12.1.4 and a JDK 21 (default), then any optional tool groups you asked for.
3. Install the REA CLI (`npm install --global rea-agents@latest`).
4. Run `rea setup`. It registers REA with the agents it detects, installs REA's skill, and on macOS and Linux offers to install Hopper.
5. Record every change in `~/.rea-installer/installed`.

## What gets installed

REA needs Node.js 22.19+, 24.11+ or 26+. The scripts require 24.15+ on the 24.x line, because REA's SQLite analysis needs it. Everything else depends on what you want to analyse. ✓ means installed by default. **flag** means installed only when you pass that option. — means REA doesn't support it on that platform.

| Component | Used by REA for | macOS | Windows | Linux |
|---|---|---|---|---|
| Node.js + npm | Running REA | Homebrew `node` if needed | winget `OpenJS.NodeJS.LTS` if needed | nodejs.org 24.x tarball if needed |
| REA (`rea-agents`) | Everything | ✓ npm | ✓ npm | ✓ npm (`~/.local` prefix) |
| Ghidra 12.1.4 | Native binary analysis | ✓ Homebrew `ghidra` | ✓ GitHub release | ✓ GitHub release (x64 only) |
| JDK 21 | Ghidra, JADX | ✓ Homebrew `openjdk@21` | ✓ winget Temurin 21 | ✓ Adoptium Temurin 21 |
| Hopper | Native binary analysis (commercial) | offered by `rea setup` | — | offered by `rea setup` |
| Xcode Command Line Tools | Homebrew; REA's macOS process capture | ✓ if missing | — | — |
| procps `ps`, util-linux `prlimit`, curl, unzip, xz | REA's Linux process supervision, downloads | — | — | ✓ if missing |
| JADX headless 0.7.1 jar | Android APK decompilation | `--with-android` | `-WithAndroid` | `--with-android` |
| Apktool 3.0.3 | Android resources and manifests | `--with-android` | `-WithAndroid` | `--with-android` |
| adb (platform-tools) | Android devices and emulators | `--with-android` | `-WithAndroid` | `--with-android` |
| Rizin | Offline native analysis | `--with-extras` | `-WithExtras` | `--with-extras` (distro package, or the official static build on x64) |
| GNU objdump | Offline native analysis | `--with-extras` (binutils) | `-WithExtras` (WinLibs) | `--with-extras` (binutils) |
| WABT 1.0.42 | WebAssembly inspection | `--with-extras` | `-WithExtras` | `--with-extras` |
| TShark + capinfos | Packet captures | — | — | `--with-linux-tools` |
| sigrok-cli | Logic-analyser recordings | — | — | `--with-linux-tools` |
| GDB | Debugger sessions | — | — | `--with-linux-tools` |
| pwntools 4.15.0 (+ pyelftools 0.33, Unicorn 2.1.2) | ELF layout, recorded crashes | — | — | `--with-linux-tools` (x64, isolated venv) |
| mitmproxy 12.2.3 | Native mitmproxy captures | — | — | `--with-linux-tools` (isolated venv, Python 3.12+) |
| Wakaru 1.14.0 | JavaScript bundle recovery | — | — | `--with-linux-tools` (x64) |

A Chrome-family browser, which REA uses for website analysis, is left for you to install. Neither is anything commercial: IDA, JEB, and Hopper on Windows.

### Settings REA reads

Several tools are found only through environment variables, so the scripts set them:

- **macOS and Linux:** a marked block in your shell profile (`~/.zshrc`, or `~/.bashrc` on Linux bash):

  ```bash
  # >>> rea-installer >>>
  export JAVA_HOME="..."
  export REA_WABT_BIN_DIRECTORY="..."
  # <<< rea-installer <<<
  ```

- **Windows:** user environment variables, so agents started from the Start menu see them too.

## Options

| macOS / Linux | Windows | Effect |
|---|---|---|
| `--no-ghidra` | `-NoGhidra` | Skip Ghidra (and its JDK, unless Android needs it) |
| `--with-android` | `-WithAndroid` | JADX jar, Apktool, adb |
| `--with-extras` | `-WithExtras` | Rizin, GNU objdump, WABT |
| `--with-linux-tools` | — | Linux only: TShark/capinfos, sigrok-cli, GDB, pwntools, mitmproxy, Wakaru |
| `--yes` | `-Yes` | Non-interactive. Runs `rea setup --yes --all-detected`, which registers REA with **every** agent it detects, and accepts uninstall prompts. |
| `--dry-run` | `-DryRun` | Print the plan without changing anything |

Without `--yes`, `rea setup` runs interactively: you choose which agents to register, review its plan, and approve it.

## Uninstalling

```bash
./rea-install-macos.sh uninstall
```

Uninstall reads `~/.rea-installer/installed` and reverses it, newest first:

1. Runs `rea uninstall --purge-data`, REA's own command. It removes REA's agent registrations, its skill files and `~/.rea`.
2. Removes the `rea-agents` npm package.
3. Removes the shell-profile block (macOS and Linux) or the user environment variables (Windows).
4. Removes packages the script installed. It never removes one that something else now depends on: it checks with `brew uses`, a simulated `apt-get`/`dnf` removal, or `pacman`'s reverse dependencies. On Linux it also removes only the dependencies that its own removals left orphaned.
5. Asks before removing Hopper, Homebrew or the Xcode Command Line Tools, and only if this script's run installed them.
6. Deletes `~/.rea-installer`, which holds every downloaded tool, JDK, Node.js and Python venv.

Anything that was on your machine before you ran `install` is left alone.

## How the scripts were engineered

**Built from REA's own sources, not guesswork.** Each requirement was traced to REA's documentation or source code:

- Version pins came from `docs/installation.md`, `docs/android-analysis.md`, `docs/wasm-artifacts.md` and the other per-target guides. The JADX jar hash, for example, is the one REA's docs publish.
- Two facts that shape the scripts were confirmed in REA's TypeScript:
  - `rea setup` copies only the Ghidra, IDA, JADX and Hopper settings into agent registrations (`src/doctorRuntime.ts`), so the other settings need the shell profile or Windows environment variables.
  - REA's MCP server only offers its Linux capture, firmware, pwntools and WASM tools when an *absolute path* is set (`src/server/createServer.ts`). Having the tool on `PATH` isn't enough.

**Leave pre-existing things alone.** Before installing anything, each script checks whether it's already there: a supported Node.js (including one managed by nvm), a JDK in `JAVA_HOME`, Ghidra on `PATH`, an installed package. Only what it actually adds goes into the ledger, so uninstall can't remove something you installed yourself.

**Verify every download.** Anything not from a package manager is checked against a SHA-256 before use. A mismatch deletes the partial file and stops the install.

| Download | Checksum source |
|---|---|
| Ghidra, Apktool, WABT, Rizin | GitHub release asset digests, pinned in the scripts |
| JADX jar, Wakaru | REA's documentation |
| Node.js | nodejs.org's `SHASUMS256.txt` |
| Temurin JDK | The checksum Adoptium's API publishes |

**Reruns are safe.**
- Rerunning `install` doesn't download what's already present.
- It doesn't add a second profile block; the block is replaced.
- It recognises its own previous settings instead of mistaking them for yours.

**Fail loudly.** All three scripts run in strict mode: `set -euo pipefail` in bash, `Set-StrictMode` and `$ErrorActionPreference = 'Stop'` in PowerShell. When an optional tool isn't available, the script warns and skips it. When a required step fails, it stops with a message saying what to do.

**Small and readable.** Each script is a single file with no dependencies beyond what the platform ships, plus `--dry-run` so you can read the plan before running it.

## Testing

| Script | Tested on | What was tested |
|---|---|---|
| macOS | macOS 27 (Apple silicon) | `bash -n` and `shellcheck` under the system `/bin/bash` 3.2. Dry runs of install and uninstall. Profile-block removal in a sandboxed home directory. The JADX checksum against the real download. |
| Windows | PowerShell 7 on macOS, with a stubbed `winget` | Parsed with the PowerShell parser. Full dry runs. The real download, checksum and extract path (WABT). Rejection of a tampered checksum. Uninstall ordering and environment-variable cleanup. |
| Linux | Docker container: Fedora 44 (arm64) | A full install with every option. Each configured tool run at its pinned version. `rea doctor` (healthy). A reinstall from a shell with the profile loaded (no downloads, one profile block). Uninstall, then a before-and-after comparison of the installed package list. Ubuntu 24.04 (x64) and Arch Linux (x64) runs are in progress. |

> **Not yet run on a real machine:** a full non-dry install on macOS or Windows (it would change the tester's own agent configuration), and anything involving a Windows `winget` run. Run with `--dry-run` first, and please open an issue if something doesn't work.

## Known limitations

- **Windows:** REA's Ghidra support there is experimental (read-only, Windows executables and DLLs only), and Ghidra and JADX are x64-only. Hopper and process capture aren't available on Windows. Node.js and Temurin install machine-wide, so you'll see a UAC prompt.
- **Linux arm64:** Ghidra's official release has no arm64 Linux decompiler, so Ghidra is skipped. REA supports pwntools and Wakaru only on x64.
- **Not installed:**
  - Binwalk 3.1: no prebuilt binaries, only a Rust source build.
  - Unblob 26.6 and its many extractors.
  - pwndbg: REA needs three separately pinned paths for it.

  Without Binwalk and Unblob, REA's firmware analysis and its optional pwndbg crash context stay unavailable.
- **Shell profile:** on macOS and Linux, agents launched from a desktop launcher rather than a terminal may not see settings that only live in the shell profile. The Ghidra, JADX and JDK settings aren't affected, because `rea setup` writes them into each agent's registration.
- **Hopper on Linux:** `rea setup` installs Hopper's own package dependencies (Xvfb and others). Uninstall removes the Hopper package but not those dependencies.
- **Python packages:** pinned by version, not by hash.

## Attribution

These scripts only install other people's work. All credit belongs to the projects below; each is distributed under its own license, which applies when you install it.

| Project | Author / maintainer | License |
|---|---|---|
| [REA — Reverse Engineer Anything](https://github.com/morluto/rea) (`rea-agents`) | morluto and contributors | MIT |
| [Ghidra](https://github.com/NationalSecurityAgency/ghidra) | U.S. National Security Agency | Apache-2.0 |
| [Hopper Disassembler](https://www.hopperapp.com/) | Cryptic Apps | Commercial (installed only through `rea setup`, with your approval) |
| [Node.js](https://github.com/nodejs/node) and npm | OpenJS Foundation and contributors | MIT (npm: Artistic-2.0) |
| [Eclipse Temurin](https://adoptium.net/) (OpenJDK 21) | Eclipse Adoptium | GPL-2.0 with Classpath Exception |
| [OpenJDK](https://openjdk.org/) (Homebrew `openjdk@21`) | OpenJDK community | GPL-2.0 with Classpath Exception |
| [JADX](https://github.com/skylot/jadx) | skylot and contributors | Apache-2.0 |
| [jadx-headless-mcp](https://github.com/1013503897/jadx-headless-mcp) | 1013503897 | Apache-2.0 |
| [Apktool](https://github.com/iBotPeaches/Apktool) | Connor Tumbleson (iBotPeaches) and contributors | Apache-2.0 |
| [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools) (adb) | Google / Android Open Source Project | Apache-2.0 (Android SDK terms apply to Google's builds) |
| [Rizin](https://github.com/rizinorg/rizin) | Rizin Organization | LGPL-3.0 |
| [GNU Binutils](https://www.gnu.org/software/binutils/) (objdump) | Free Software Foundation | GPL-3.0 |
| [WinLibs](https://github.com/brechtsanders/winlibs_mingw) (MinGW-w64 GCC toolchain) | Brecht Sanders | Licenses of its bundled components (GCC, binutils: GPL) |
| [WABT — WebAssembly Binary Toolkit](https://github.com/WebAssembly/wabt) | WebAssembly Community Group | Apache-2.0 |
| [Wakaru](https://github.com/pionxzh/wakaru) | pionxzh | Apache-2.0 |
| [Wireshark / TShark](https://github.com/wireshark/wireshark) | Wireshark Foundation and contributors | GPL-2.0 |
| [sigrok-cli](https://github.com/sigrokproject/sigrok-cli) | sigrok project | GPL-3.0 |
| [GDB](https://www.sourceware.org/gdb/) | Free Software Foundation | GPL-3.0 |
| [pwntools](https://github.com/Gallopsled/pwntools) | Gallopsled | Mostly MIT (some parts GPL / BSD-2-Clause) |
| [pyelftools](https://github.com/eliben/pyelftools) | Eli Bendersky | Public domain (Unlicense) |
| [Unicorn Engine](https://github.com/unicorn-engine/unicorn) | Unicorn Engine team | GPL-2.0 |
| [mitmproxy](https://github.com/mitmproxy/mitmproxy) | mitmproxy project | MIT |
| [Homebrew](https://github.com/Homebrew/brew) | Homebrew maintainers | BSD-2-Clause |
| [winget](https://github.com/microsoft/winget-cli) | Microsoft | MIT |
| [nvm](https://github.com/nvm-sh/nvm) (detected if present, never installed) | nvm-sh | MIT |
| [procps-ng](https://gitlab.com/procps-ng/procps), [util-linux](https://github.com/util-linux/util-linux) | Their respective maintainers | GPL-2.0+ / mixed |

Product names and trademarks belong to their owners. If you maintain one of these projects and would like the attribution changed, please open an issue.
