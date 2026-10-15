# rea-installer

One-command install — and clean uninstall — of [REA (Reverse Engineer Anything)](https://github.com/morluto/rea) and the tools it uses, on macOS, Windows and Linux.

REA is an MCP server and CLI that lets AI coding agents (Claude Code, Codex, Cursor, Gemini CLI and others) inspect native binaries, JavaScript/Electron apps, .NET assemblies, Android APKs, WebAssembly, network captures and more. Its own setup (`npx rea-agents setup`) registers it with your agents, but it deliberately installs nothing else: Node.js, Ghidra, a JDK, JADX, Apktool, adb, Rizin, objdump, WABT and the Linux-only capture tools are all "caller-supplied". REA's docs list them across a couple of dozen pages, each with its own version pin and environment variable.

These scripts collect all of that into one command per platform, and record everything they add so `uninstall` can take it back out without touching anything you already had.

> **This is an unofficial, community project.** It is not affiliated with or endorsed by the REA authors. It installs REA from its official npm package, [`rea-agents`](https://www.npmjs.com/package/rea-agents). For REA itself, see [morluto/rea](https://github.com/morluto/rea) and [rea.tools](https://rea.tools/).

## Contents

- [Status](#status)
- [Quick start](#quick-start)
- [The three scripts](#the-three-scripts)
- [What gets installed](#what-gets-installed)
- [Options](#options)
- [Uninstalling](#uninstalling)
- [How the scripts were engineered](#how-the-scripts-were-engineered)
- [Testing](#testing)
- [Known limitations](#known-limitations)
- [Attribution](#attribution)
- [License](#license)

## Status

| Script | Status |
|---|---|
| Linux | **Tested end to end before the current round of fixes:** full install, reinstall and uninstall in Ubuntu 24.04, Fedora 44 and Arch Linux containers. Uninstall removed everything it added, except what the system still needed. The fixes since then are checked by `test.sh` and container dry runs only; a new full container run of the current script is planned (see [Testing](#testing)). |
| macOS | **Tested end to end in a macOS 27 virtual machine** with Homebrew already installed: install, `rea doctor` (Ghidra healthy), a rerun with every option, and uninstall, which left Homebrew and npm exactly as before. Also run on a real MacBook with Homebrew: the first install worked, but a rerun stopped at a symlinked `~/.zshrc`. That is now fixed and covered by `test.sh`, but the rerun hasn't been repeated on that Mac. Not yet tested on a Mac without Homebrew, or with the installer's `rea setup` step registering real agents. |
| Windows (x64 and ARM64) | **Dry runs and `test.sh` only:** parsed, dry-run and function-tested with a stubbed `winget`, but never run on real Windows |

For macOS and Windows, run with `--dry-run` / `-DryRun` first and read the plan. If anything goes wrong, please [open an issue](https://github.com/scottkw/rea-installer/issues) with the output.

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
| [`rea-install-windows.ps1`](rea-install-windows.ps1) | Windows 10+ x64 or ARM64 | Windows PowerShell 5.1 / PowerShell 7 | winget, plus pinned GitHub downloads |
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
| Ghidra 12.1.4 | Native binary analysis | ✓ Homebrew `ghidra` | ✓ GitHub release (x64 only) | ✓ GitHub release (x64 only) |
| JDK 21 | Ghidra, JADX | ✓ Homebrew `openjdk@21` | ✓ winget Temurin 21 | ✓ Adoptium Temurin 21 |
| Hopper | Native binary analysis (commercial) | offered by `rea setup` | — | offered by `rea setup` |
| Xcode Command Line Tools | Homebrew; REA's macOS process capture | ✓ if missing | — | — |
| procps `ps`, util-linux `prlimit`, curl, unzip, xz | REA's Linux process supervision, downloads | — | — | ✓ if missing |
| JADX headless 0.7.1 jar | Android APK decompilation | `--with-android` | `-WithAndroid` (x64 only) | `--with-android` |
| Apktool 3.0.3 | Android resources and manifests | `--with-android` | `-WithAndroid` | `--with-android` |
| adb (platform-tools) | Android devices and emulators | `--with-android` | `-WithAndroid` | `--with-android` |
| Rizin | Offline native analysis | `--with-extras` | `-WithExtras` | `--with-extras` (distro package, or the official static build on x64) |
| GNU objdump | Offline native analysis | `--with-extras` (binutils) | `-WithExtras` (WinLibs) | `--with-extras` (binutils) |
| WABT 1.0.42 | WebAssembly inspection | `--with-extras` | `-WithExtras` | `--with-extras` |
| TShark + capinfos | Packet captures | — | — | `--with-linux-tools` |
| sigrok-cli | Logic-analyser recordings | — | — | `--with-linux-tools` |
| GDB | Debugger sessions | — | — | `--with-linux-tools` |
| pwntools 4.15.0 (+ pyelftools 0.33, Unicorn 2.1.2) | ELF layout, recorded crashes | — | — | `--with-linux-tools` (x64; private Python 3.12 venv via uv) |
| mitmproxy 12.2.3 | Native mitmproxy captures | — | — | `--with-linux-tools` (private Python 3.12 venv via uv) |
| Wakaru 1.14.0 | JavaScript bundle recovery | — | — | `--with-linux-tools` (x64) |

A Chrome-family browser, which REA uses for website analysis, is left for you to install. Neither is anything commercial: IDA, JEB, and Hopper on Windows.

### Settings REA reads

Several tools are found only through environment variables, so the scripts set them:

- **macOS and Linux:** a marked block in your shell profile (`~/.zshrc`, or `~/.bashrc` on Linux bash):

  ```bash
  # >>> rea-installer >>>
  export JAVA_HOME="..."
  export GHIDRA_INSTALL_DIR="..."
  export REA_WABT_BIN_DIRECTORY="..."
  # <<< rea-installer <<<
  ```

  On macOS, when the script installed Homebrew, the block also holds Homebrew's `eval "$(brew shellenv)"` line, so `brew`, `node` and `rea` are on `PATH` in new terminals. Uninstall removes it with the block.

  If your profile is a symlink (for example into a dotfiles repository), the scripts edit the file it points to and leave the link in place.

  On macOS, the block also sets `GHIDRA_INSTALL_DIR` to Homebrew's Ghidra (`$(brew --prefix ghidra)/libexec`), because REA finds Ghidra only through that variable. `rea setup` copies it into each agent's registration. A `GHIDRA_INSTALL_DIR` you already set to another folder is left alone.

- **Windows:** user environment variables, so agents started from the Start menu see them too.

## Options

| macOS / Linux | Windows | Effect |
|---|---|---|
| `--no-ghidra` | `-NoGhidra` | Skip Ghidra (and its JDK, unless Android needs it) |
| `--with-android` | `-WithAndroid` | JADX jar, Apktool, adb |
| `--with-extras` | `-WithExtras` | Rizin, GNU objdump, WABT |
| `--with-linux-tools` | — | Linux only: TShark/capinfos, sigrok-cli, GDB, pwntools, mitmproxy, Wakaru |
| `--yes` | `-Yes` | Non-interactive. Runs `rea setup --yes --all-detected`, which registers REA with **every** agent it detects, and accepts uninstall prompts. On macOS it also installs Homebrew without waiting for Return, asking for your sudo password once first when a terminal is available. |
| `--dry-run` | `-DryRun` | Print the plan without changing anything |

Without `--yes`, `rea setup` runs interactively: you choose which agents to register, review its plan, and approve it. Without `--yes` and without a terminal (a script, a non-interactive ssh session or an agent), the macOS and Linux scripts skip `rea setup` with a warning telling you to run it yourself, and answer uninstall prompts no.

In the agent list, press Space to select each agent and then Enter; Enter alone selects none. When `rea setup` finishes without any agent registered, the scripts warn and tell you to run `rea setup` again. You can also register a single agent directly, for example `rea setup --client claude_code`.

## Uninstalling

```bash
./rea-install-macos.sh uninstall
```

Uninstall reads `~/.rea-installer/installed` and reverses it, newest first:

1. Runs `rea uninstall --purge-data`, REA's own command. It removes REA's agent registrations, its skill files and `~/.rea`. If it fails, or the `rea` CLI is broken, uninstall warns and carries on with the rest. On macOS, if the recorded `npm` can no longer run (for example, its Node.js was removed), uninstall stops before removing anything; repair or reinstall that Node.js and npm, then rerun.
2. Removes the `rea-agents` npm package.
3. Removes the shell-profile block (macOS and Linux) or the user environment variables (Windows).
4. Removes packages the script installed.
   - **macOS:** it skips a formula that something else now depends on (checked with `brew uses`).
   - **Linux:** at install time it records each package together with every dependency that package pulled in. At uninstall it first simulates removing that exact set. If the simulation would also remove anything else (meaning you've since installed something that relies on it), it keeps the whole set and warns. Otherwise it purges the set.
5. Asks before removing Hopper, Homebrew or the Xcode Command Line Tools, and only if this script's run installed them. Without a terminal it keeps them and prints a warning naming each one, unless you passed `--yes`.
6. Deletes `~/.rea-installer`, which holds every downloaded tool, JDK, Node.js and Python venv.

Anything that was on your machine before you ran `install` is left alone.

## How the scripts were engineered

**Built from REA's own sources, not guesswork.** Each requirement was traced to REA's documentation or source code:

- Version pins came from `docs/installation.md`, `docs/android-analysis.md`, `docs/wasm-artifacts.md` and the other per-target guides. The JADX jar hash, for example, is the one REA's docs publish.
- Two facts that shape the scripts were confirmed in REA's TypeScript:
  - `rea setup` copies only the Ghidra, IDA, JADX and Hopper settings into agent registrations (`src/doctorRuntime.ts`), so the other settings need the shell profile or Windows environment variables.
  - REA's MCP server only offers its Linux capture, firmware, pwntools and WASM tools when an *absolute path* is set (`src/server/createServer.ts`). Having the tool on `PATH` isn't enough.

**Leave pre-existing things alone.** Before installing anything, each script checks whether it's already there: a supported Node.js (including one managed by nvm), a JDK 21 or newer in `JAVA_HOME` (an older one is left alone and the script installs its own JDK 21), Ghidra on `PATH`, an installed package. Only what it actually adds goes into the ledger, so uninstall can't remove something you installed yourself. On macOS, installing Ghidra also installs and records Homebrew's `openjdk@21` if it isn't already installed (an existing one is left alone and not recorded), because Homebrew's `ghidra` depends on it, even when your own JDK 21 is used.

**Verify every download.** Anything not from a package manager is checked against a SHA-256 before use. A mismatch deletes the partial file and stops the install. Linux and Windows unpack each archive into a staging folder and move it into place only after extraction succeeds, so a failed extract leaves no half-finished tool folder and a rerun extracts again.

| Download | Checksum source |
|---|---|
| Ghidra, Apktool, WABT, Rizin, uv | GitHub release asset digests, pinned in the scripts |
| JADX jar, Wakaru | REA's documentation |
| Node.js | nodejs.org's `SHASUMS256.txt` |
| Temurin JDK | The checksum Adoptium's API publishes |

**Reruns are safe.**
- Rerunning `install` doesn't download what's already present.
- It doesn't add a second profile block; the block is replaced. A symlinked profile stays a symlink, and its target keeps its permissions.
- It recognises its own previous settings instead of mistaking them for yours.
- macOS keeps exporting its own `JAVA_HOME` in the single profile block across reruns, and never copies a JDK 21+ `JAVA_HOME` of yours into it.
- Linux replaces its own `~/.rea-installer/jdk` if that JDK no longer runs.
- Windows sets a user `JAVA_HOME` to the Temurin 21 it installed, found through the `java` on `PATH`, and replaces one it set earlier only when that folder no longer has `java.exe`.

**Keep the system Python out of it.** pwntools and mitmproxy go into private virtual environments with a Python 3.12 that [uv](https://github.com/astral-sh/uv) downloads into `~/.rea-installer`. REA pins Unicorn 2.1.2, which has no wheels past Python 3.13, and mitmproxy 12 needs 3.12+. With a private interpreter, the result doesn't depend on which Python your distribution ships. uv itself is pinned by checksum, to a release that had been out for over two weeks.

**Fail loudly.** All three scripts run in strict mode: `set -euo pipefail` in bash, `Set-StrictMode` and `$ErrorActionPreference = 'Stop'` in PowerShell. When an optional tool isn't available, the script warns and skips it. When a required step fails, it stops with a message saying what to do:

- A failed required package install (Linux) or `brew install` (macOS) stops the install and is not recorded.
- Under `--yes`, a Homebrew install that fails stops with a hint about sudo and records nothing.
- A dry run only prints the plan. A check in a fresh Linux container confirms the home folder is unchanged afterwards.
- Without a terminal, `rea setup` is skipped with a warning and uninstall prompts are answered no, instead of the script failing.
- If `rea setup` finishes without registering any agent, the script warns instead of reporting success silently. It checks this with `rea doctor`.

**Small and readable.** Each script is a single file with no dependencies beyond what the platform ships, plus `--dry-run` so you can read the plan before running it.

## Testing

| Script | Tested on | What was tested |
|---|---|---|
| macOS | macOS 27 (Apple silicon) | `bash -n` and `shellcheck` under the system `/bin/bash` 3.2. Dry runs of install and uninstall. `test.sh` loads the script's functions in a sandboxed home with stub commands and checks the profile-block round trip (including through a symlinked profile, for both bash scripts), `node_supported`, JDK selection and `JAVA_HOME` across reruns, failed `brew install` reporting, uninstall with a broken `rea`, the no-terminal prompts and `rea setup` skip, the warning when `rea setup` registers no agent, the unattended Homebrew plan, the Homebrew PATH line in the profile block, and clearing the sudo ticket after Homebrew's installer. The JADX checksum against the real download. `GHIDRA_INSTALL_DIR` on install, rerun and `--no-ghidra`, and `brew install` running with `HOMEBREW_NO_ASK=1`. |
| macOS | macOS 27 virtual machine ([Tart](https://github.com/cirruslabs/tart) image `macos-golden-gate-base`: Homebrew and the Command Line Tools preinstalled, no agents) | See below. |
| Windows | PowerShell 7 on macOS, with a stubbed `winget` | Parsed with the PowerShell parser. Full dry runs as x64 and ARM64 (Ghidra and JADX skipped on ARM64), plus rejection of 32-bit Windows. The real download, checksum and extract path (WABT). Rejection of a tampered checksum. Uninstall ordering and environment-variable cleanup. `test.sh` dot-sources the script with a stubbed `winget` and checks failed extraction and rerun, uninstall with a broken `rea`, and `Install-Jdk`'s `JAVA_HOME` handling (reuse, dry run, stale or missing values). |
| Linux | Docker containers: Ubuntu 24.04 (x64), Fedora 44 (arm64), Arch Linux (x64) | See below. |

The Linux runs used every option, on a frozen read-only copy of the script, and each went through the same steps:

1. **Install,** then run each configured tool at its pinned version and run `rea doctor`. All three were healthy, and on x64 REA detected Ghidra 12.1.4 and JADX.
2. **Reinstall** from a shell with the profile block loaded. Nothing was downloaded again, there was still one profile block, and every setting was kept.
3. **Uninstall,** then compare the installed-package list with the one from before the install:
   - **Ubuntu and Arch:** zero packages left over and zero pre-existing packages removed.
   - **Fedora:** the test also installed a package that depends on one of sigrok-cli's dependencies. Uninstall correctly kept that dependency. As expected, it also kept systemd, which Fedora protects.

Those full runs came before the current round of fixes. Since then, the Linux changes are checked by `test.sh` (sourced-function checks) and a fresh `ubuntu:24.04` dry run, not by a new full run.

The macOS virtual machine runs started from a fresh clone each time and went through the same steps:

1. **Dry run,** then **install** with `--yes`, then `rea doctor` in a new login shell. REA reported Ghidra 12.1.4 healthy through the `GHIDRA_INSTALL_DIR` the script set.
2. **Rerun.** In the first run, the rerun added `--with-android --with-extras`: the extra tools installed, nothing was installed again, and the profile block was replaced in place. A second run, after the Ghidra fix, confirmed that a rerun keeps Ghidra configured.
3. **Uninstall,** then compare with a snapshot taken before the install. The Homebrew formula and cask lists and the global npm packages matched exactly.

These runs found the two bugs fixed since: REA could not find Homebrew's Ghidra, and Homebrew 7's default install prompt hung `--yes`. The prompt fix was checked by `test.sh`, not by a new VM run.

### Running the tests

`test.sh` is run locally before a release, on a Mac and in a Linux container; nothing runs in hosted CI.

```bash
# macOS, under the system Bash 3.2:
/bin/bash ./test.sh
# Linux, from the repo root:
docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" -w /src ubuntu:24.04 bash ./test.sh
```

It covers:

- `bash -n` and `shellcheck` on both bash scripts and on `test.sh`.
- A PowerShell parse of the Windows script, and a dot-sourced driver for its functions.
- Sourced-function checks of the bash scripts, with a temporary home and stub commands.
- A dry run in a fresh `ubuntu:24.04` container with no network, which must leave the home folder unchanged.

It prints one `PASS:`, `FAIL:` or `SKIP:` line per check, then a final count line, and exits with status 1 when any check fails.

A missing `docker` (a stopped Docker daemon counts as missing), `pwsh` or `shellcheck` SKIPs only the checks that need it. On a Mac, a missing `docker` or `shellcheck` is expected and always SKIPs. Otherwise, with `CI=true` set, a missing tool is a FAIL instead, so a run can't pass by skipping.

A few checks use BSD or GNU tools and run only on the matching OS, so the two runs report different PASS and SKIP counts.

> **Not yet run on a real machine:**
> - a full macOS install with `rea setup` registering real agents, or on a Mac without Homebrew (the script's own Homebrew install);
> - a full Linux install of the current script (the container runs above predate the latest fixes);
> - anything on real Windows, including the `winget` installs, the `JAVA_HOME` the script derives from the Temurin it installs, WinLibs putting `objdump` on `PATH`, and the registry check that detects ARM64.
>
> Run with `--dry-run` first, and please open an issue if something doesn't work.

## Known limitations

- **Windows:** REA's Ghidra support there is experimental (read-only, Windows executables and DLLs only). Hopper and process capture aren't available on Windows. Node.js and Temurin install machine-wide, so you'll see a UAC prompt.
- **Windows on ARM64:** REA's Windows native code, which Ghidra and JADX need, ships for x64 only, so the script skips those two and installs everything else. Node.js runs natively. The JDK, adb, Rizin, WinLibs and WABT have no ARM64 builds, so they run under Windows' built-in x64 emulation. `rea doctor` reports an ARM64 host as unsupported, because REA's Windows support targets x64.
- **Linux arm64:** Ghidra's official release has no arm64 Linux decompiler, so Ghidra is skipped. REA supports pwntools and Wakaru only on x64.
- **Not installed:**
  - Binwalk 3.1: no prebuilt binaries, only a Rust source build.
  - Unblob 26.6 and its many extractors.
  - pwndbg: REA needs three separately pinned paths for it.

  Without Binwalk and Unblob, REA's firmware analysis and its optional pwndbg crash context stay unavailable.
- **Shell profile:** on macOS and Linux, agents launched from a desktop launcher rather than a terminal may not see settings that only live in the shell profile. The Ghidra, JADX and JDK settings aren't affected, because `rea setup` writes them into each agent's registration.
- **Fedora protected packages:** dnf never removes packages that Fedora marks protected (such as `systemd`), or anything they depend on. If installing a tool pulled systemd into a minimal system (sigrok-cli does, through libftdi), systemd stays after uninstall. That's by design.
- **Arch Linux:** the script won't partially sync pacman's database. If it has never been synced, run `sudo pacman -Syu` first.
- **Hopper on Linux:** `rea setup` installs Hopper's own package dependencies (Xvfb and others). Uninstall removes the Hopper package but not those dependencies.
- **Python packages:** pinned by version, not by hash.
- **Unattended macOS install:** the Xcode Command Line Tools must already be installed (the script stops and asks you to finish their installer dialog, then rerun). Without a terminal, Homebrew must already be installed or sudo must need no password, because sudo can't reuse a password cached in another terminal. Without a terminal and without `--yes`, `rea setup` is skipped with a warning and uninstall prompts are answered no. Piped into bash without `--yes`, Homebrew's installer also runs non-interactively and needs a cached sudo ticket: run `sudo -v` first, or pass `--yes`.
- **Homebrew edge cases (macOS):**
  - If Homebrew's own installer fails partway (for example, a network error during `brew update`), it can leave a working `brew` behind that isn't recorded. A rerun treats it as yours, so uninstall won't offer to remove it.
  - When Homebrew's installer fails, the script always suggests running `sudo -v`, even when the cause was something else; read Homebrew's output above the message. With `INTERACTIVE` set in your environment, `--yes` makes Homebrew's installer abort straight away.
  - On a Mac without Homebrew, a dry run downloads Homebrew's installer, so it needs network access and prints the whole installer as one long line of the plan.
  - When uninstall removes Homebrew, a failed download of Homebrew's uninstaller isn't reported: Homebrew stays and is dropped from the ledger. Under `--yes`, Homebrew's uninstaller still asks its own confirmation question.
- **Kept without a terminal:** when uninstall runs without a terminal and keeps Hopper, Homebrew or the Xcode Command Line Tools, it still deletes `~/.rea-installer`, so a later uninstall from a terminal can no longer offer to remove them.
- **npm install scripts:** npm 11 skips install scripts for packages not listed in `allowScripts`. Installing `rea-agents` reports that `frida`'s install script was skipped. `rea doctor` doesn't flag it, and whether any REA feature needs it hasn't been checked.
- **Leftovers after macOS uninstall:** an empty `~/.zshrc` remains if the script created it, and REA's own uninstall leaves an empty `~/.agents/skills` folder.
- **Dry run without Node.js (macOS and Windows):** a dry run on a Mac or Windows PC without Node.js stops at the npm step (on a Mac without Homebrew, at the Node.js step) instead of printing the whole plan.
- **Linux pinned-download layout:** if a pinned download's top-level folder ever differs from the expected name, the tool is unpacked one folder deeper and its setting points at the wrong place; the install does not stop. The JDK is checked and handled.
- **Linux Rizin and Wakaru folders:** an existing `~/.rea-installer/tools/rizin-0.9.1` or `wakaru-1.14.0` folder is reused without checking the binary inside. If REA can't find Rizin or Wakaru, delete the folder and rerun.
- **Partial package installs (Linux and macOS):** if a package install fails partway, the dependencies it already installed aren't recorded, so uninstall leaves them.
- **Windows `JAVA_HOME`:** if a Temurin upgrade leaves the old folder (with `java.exe`) in place, the user `JAVA_HOME` the script saved keeps pointing at it, while the install run and `rea setup` use the new JDK. If you already had a user `JAVA_HOME` set to an older JDK, the script warns and leaves it, so programs other than this run and `rea setup` keep seeing yours. Uninstall removes the user `JAVA_HOME` the script set, even if you repointed it afterwards. A saved `JAVA_HOME` on a drive that is no longer available stops the install with a "Cannot find drive" error; clear or fix that variable and rerun.
- **JDK check:** the scripts accept any `JAVA_HOME` whose `java -version` reports 21 or newer, so a JRE 21 is reused even though Ghidra needs a full JDK.

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
| [uv](https://github.com/astral-sh/uv) and [python-build-standalone](https://github.com/astral-sh/python-build-standalone) | Astral | uv: Apache-2.0 or MIT; python-build-standalone: MPL-2.0; Python itself: PSF License |
| [Homebrew](https://github.com/Homebrew/brew) | Homebrew maintainers | BSD-2-Clause |
| [winget](https://github.com/microsoft/winget-cli) | Microsoft | MIT |
| [nvm](https://github.com/nvm-sh/nvm) (detected if present, never installed) | nvm-sh | MIT |
| [procps-ng](https://gitlab.com/procps-ng/procps), [util-linux](https://github.com/util-linux/util-linux) | Their respective maintainers | GPL-2.0+ / mixed |

Product names and trademarks belong to their owners. If you maintain one of these projects and would like the attribution changed, please open an issue.

## License

The scripts and documentation in this repository are released under the [MIT License](LICENSE).

That license covers only this repository. Each tool the scripts install keeps its own license, listed under [Attribution](#attribution).
