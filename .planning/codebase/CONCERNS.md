---
last_mapped_commit: 894cf00cc8f19f557bdbdee6cab36a3d5d6b5f25
last_mapped_at: 2026-10-14
---
# Codebase Concerns

**Analysis Date:** 2026-10-14

## Scope Note

The repository is small: three installer scripts (`rea-install-macos.sh`, `rea-install-linux.sh`, `rea-install-windows.ps1`), a `README.md`, and a `LICENSE`. There is no application source, no package manifest, no CI configuration and no automated test suite. Findings below are drawn from reading the scripts and README and from running `bash -n` and `--help` on the two bash scripts. Nothing was executed against a real install.

## Tech Debt

**Duplicated logic and pins across three scripts:**
- Issue: The same logic (state ledger, shell-profile block markers, `node_supported` version check, `confirm`, `run`, `record`, `remove_profile_block`) is re-implemented in `rea-install-macos.sh` and `rea-install-linux.sh`, and again in PowerShell in `rea-install-windows.ps1`. Pinned values are repeated by hand: the JADX jar SHA-256 `6e5eacf5...` appears in the macOS script (`JADX_SHA256`), the Linux script (`JADX`) and the Windows script (`$Downloads.jadx`). Ghidra 12.1.4 URL and hash appear in the Linux and Windows scripts.
- Files: `rea-install-macos.sh`, `rea-install-linux.sh`, `rea-install-windows.ps1`
- Impact: A pin bump (REA moving to a new JADX or Ghidra) must be applied in up to three places. A missed update leaves platforms on different tool versions, which the README presents as a single supported configuration.
- Fix approach: Keep one table of pins per platform and add a check (a grep in CI or a small script) that asserts the shared values match across the three files. Full de-duplication across bash and PowerShell is not practical, so the drift check is the realistic fix.

**Node.js version check contradicts its own comment:**
- Issue: `node_supported()` in both bash scripts (and `Test-NodeSupported` in PowerShell) accepts Node 22.19 and newer on the 22.x line. The comment directly above it says "SQLite analysis needs 24.15+", but the check does not enforce that for 22.x. A user on Node 22.19 to 22.x passes the check with no warning.
- Files: `rea-install-macos.sh` (`node_supported`), `rea-install-linux.sh` (`node_supported`), `rea-install-windows.ps1` (`Test-NodeSupported`)
- Impact: The installer reports success on a configuration the comment says is unsupported for SQLite analysis. The failure surfaces later, inside REA, not during install.
- Fix approach: Either enforce 24.15+ for the SQLite-dependent path or state explicitly in the README and script output that Node 22.x lacks SQLite analysis. Confirm which is true against REA's documentation before changing the check.

**Floating versions where pins are claimed elsewhere:**
- Issue: `rea-agents@latest` is installed on all three platforms. On Linux, Node.js is fetched from `https://nodejs.org/dist/latest-v24.x` (the newest 24.x at run time). On Windows, Node LTS comes from winget `OpenJS.NodeJS.LTS`. On macOS, Ghidra, Apktool and Node come from unpinned Homebrew formulae or casks. Rizin on Windows comes from winget with no checksum.
- Files: `rea-install-macos.sh` (`brew_install` calls, `npm install --global "$PACKAGE@latest"`), `rea-install-linux.sh` (`install_node`, `npm install --global --prefix ... "$PACKAGE@latest"`), `rea-install-windows.ps1` (`Install-Winget`, `Invoke-Step npm ... "$Package@latest"`)
- Impact: Two runs a week apart can produce different toolchains. The macOS Ghidra version may not be 12.1.4, the version the Linux and Windows scripts pin and the README tabulates. Reproducibility and the "tested" claims in the README do not carry over to macOS or Windows.
- Fix approach: Pin `rea-agents` to a tested version (exact semver, not `@latest`) and make the version a single variable per script. For macOS, pin Ghidra by a versioned cask or formula if one exists, or verify and report the installed version. For Node, pin to a specific 24.x release with its SHASUMS entry.

**Python dependencies pinned by version, not hash:**
- Issue: `make_venv` installs `pwntools==4.15.0 pyelftools==0.33 unicorn==2.1.2` and `mitmproxy==12.2.3` with `uv pip install` and no `--require-hashes`. The README acknowledges this.
- Files: `rea-install-linux.sh` (`make_venv`, `--with-linux-tools` branch)
- Impact: A compromised or re-published version on PyPI with the same version string is not detected. Transitive dependencies float.
- Fix approach: Generate a hash-locked requirements file per venv and install with `--require-hashes`.

**No automated tests or lint gate in the repository:**
- Issue: No test files, no CI workflow and no lint configuration exist in the repo. The README's testing table records manual runs (shellcheck under macOS `/bin/bash` 3.2, PowerShell parser on macOS, Docker containers for Linux). None of that is reproducible from the repo.
- Files: repository root (no `.github/`, no `tests/`)
- Impact: Any future edit can regress the scripts silently. The Linux container results in the README describe a specific revision that may no longer match the file.
- Fix approach: Add `shellcheck` and `bash -n` on the two bash scripts, PSScriptAnalyzer and a PowerShell parse check on the Windows script, and a `--dry-run` smoke test on each platform in CI. Record the commit each container test ran against.

## Known Bugs

**Linux `--help` prints a stray code line:**
- Symptoms: `./rea-install-linux.sh --help` ends with the line `set -euo pipefail`. The `usage()` function prints lines 2 to 15 of the script, and line 15 is code, not comment.
- Files: `rea-install-linux.sh` (`usage()`, `sed -n '2,15p'`)
- Trigger: Run `--help` or run with no arguments.
- Workaround: Ignore the last line. Confirmed by running `--help`.

**Usage text is extracted by hard-coded line numbers:**
- Symptoms: `usage()` in the macOS and Linux scripts use `sed -n '2,11p'` and `sed -n '2,15p'`. Editing the header comment shifts or truncates help text silently. The Windows script does the same with `Get-Content ... -TotalCount 15`.
- Files: `rea-install-macos.sh` (`usage`), `rea-install-linux.sh` (`usage`), `rea-install-windows.ps1` (`default` branch of the main `switch`)
- Trigger: Any edit to the header comment.
- Workaround: Manually check `--help` after editing a header. Fix approach: print a heredoc usage block, or have the extraction stop at the first non-comment line (`sed -n '2,/^[^#]/{/^[^#]/!p}'`).

**macOS Ghidra install uses the formula path, but Homebrew ships Ghidra as a cask (needs verification):**
- Symptoms: `brew_install ghidra` (macOS script step 4) calls `brew list --versions ghidra` and `brew install ghidra` without `--cask`. Ghidra is distributed through Homebrew Cask, so the existence check may never match an existing install, and the install may fail or be re-run on every invocation.
- Files: `rea-install-macos.sh` (step 4 of `do_install`, `brew_install` helper)
- Trigger: `install` on macOS without `GHIDRA_INSTALL_DIR` and without `ghidraRun` on PATH. The README lists this as a verified dry-run only.
- Workaround: Run with `--no-ghidra` and install Ghidra manually. Verify the formula versus cask distinction with `brew info --cask ghidra` before relying on the macOS step.

**macOS: a pre-existing unsupported Homebrew Node causes a hard failure:**
- Symptoms: If `node` is an old Homebrew install, `brew_install node` skips it as "already installed (left as-is)", and then `node_supported` fails and the script dies with "Homebrew node ... is still unsupported." The script never upgrades it.
- Files: `rea-install-macos.sh` (step 3 of `do_install`, `brew_install node`)
- Trigger: Homebrew `node` installed at an unsupported version.
- Workaround: Run `brew upgrade node` by hand, then rerun.

**Optional-tool failures are silent on Linux:**
- Symptoms: `pkg_install adb || true`, `pkg_install tshark || true`, `pkg_install binutils || true` and `if ! pkg_install rizin` use `||` to continue. Because `set -e` is disabled inside a command that is the left side of `||`, a real package-manager failure (not just "unavailable") is also swallowed with no message. The README says "When an optional tool isn't available, the script warns and skips it", which is only true for the "not available" case.
- Files: `rea-install-linux.sh` (steps 4, 5 and 6 of `do_install`; `pkg_install`)
- Trigger: A transient apt, dnf or pacman error during an optional install.
- Workaround: Read the summary output and check `rea doctor`. Fix approach: have `pkg_install` distinguish "not available" (warn) from "install failed" (error or at least warn), and log every skipped optional tool at the end.

**Dry runs still perform network access and writes on Linux:**
- Symptoms: `install_node` calls `curl` directly, and `install_jdk` fetches Adoptium metadata and runs `node -e`, both outside `run`. `--dry-run` therefore still hits the network and can fail on it. `npm ls` and `apt-get update` in some paths also execute.
- Files: `rea-install-linux.sh` (`install_node`, `install_jdk`, `pkg_available`)
- Trigger: `--dry-run` on a machine without network access.
- Workaround: None needed for normal use. Fix approach: route metadata fetches through `run` or print a placeholder in dry-run mode.

## Security Considerations

**Unpinned Homebrew bootstrap executed from `HEAD`:**
- Risk: The macOS script runs `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` with no checksum or commit pin. The uninstall path does the same with `uninstall.sh`. A compromised or changed `HEAD` runs as the user, with sudo prompts to follow.
- Files: `rea-install-macos.sh` (`do_install` step 2, `do_uninstall` step 4)
- Current mitigation: Downloads use `curl -fsSL` (fail on HTTP error, TLS verified). No checksum.
- Recommendations: Pin Homebrew's installer to a tagged commit and verify its SHA-256 before executing, or document the trust decision explicitly in the README.

**`--yes` auto-approves destructive removals on uninstall:**
- Risk: `confirm()` returns success whenever `--yes` is set. On macOS uninstall, that means `sudo rm -rf /Library/Developer/CommandLineTools` (Xcode Command Line Tools), removal of Homebrew via its uninstall script, and removal of recorded Hopper app bundles (`rm -rf`), all without a prompt. The README describes `--yes` as "accepts uninstall prompts" and does not single out the CLT deletion.
- Files: `rea-install-macos.sh` (`confirm`, `do_uninstall` steps 3 and 4), `rea-install-windows.ps1` (`Invoke-Uninstall` removes winget packages without any confirmation step even without `-Yes`)
- Current mitigation: Each removal is gated by a ledger entry, so only things the script recorded are targeted. Windows and Linux uninstall do not prompt for Node or JDK at all.
- Recommendations: Do not auto-approve the CLT removal or the Homebrew removal under `--yes`; require an explicit flag (for example `--remove-system-tools`). Add a confirmation step to the Windows uninstall for winget removals.

**`rea setup --yes --all-detected` registers an unreviewed third-party package with every detected agent:**
- Risk: Non-interactive install runs the newest `rea-agents` npm package and registers it with every agent it finds, without review. REA is described as an unofficial dependency here, and its npm release is a single upstream trust point. Combined with `@latest`, a bad release reaches every machine that reruns the installer.
- Files: `rea-install-macos.sh`, `rea-install-linux.sh`, `rea-install-windows.ps1` (the `--yes` branches calling `rea setup --yes --all-detected`)
- Current mitigation: Interactive mode is the default; `--yes` is opt-in.
- Recommendations: Pin the npm version (see Tech Debt), and document that `--yes` grants registration with all agents.

**Checksums fetched from the same origin as the artifact:**
- Risk: Node.js uses `SHASUMS256.txt` from `nodejs.org`, and the Temurin JDK checksum is read from the same Adoptium API response that supplies the download URL. Both verify integrity only against the same host, not an independent signed source. The README's "verify every download" framing overstates this.
- Files: `rea-install-linux.sh` (`install_node`, `install_jdk`)
- Current mitigation: TLS on each request, `--proto '=https'`.
- Recommendations: Pin the Node.js and Temurin versions and hashes in the script, as is already done for Ghidra, JADX and uv. Then the checksum no longer depends on the fetch.

**Shell-profile values are not quoted safely:**
- Risk: Values written into `~/.zshrc` or `~/.bashrc` are built with `export NAME="$VALUE"` string concatenation (`setting`, `profile_exports`, and the apktool launcher `printf`). A path containing `"`, `$` or a backtick produces a profile line that executes code on every shell start.
- Files: `rea-install-linux.sh` (`setting`, `tool_setting`, launcher `printf`), `rea-install-macos.sh` (`profile_exports`)
- Current mitigation: Paths are usually under `$HOME` and generated by the scripts. Low likelihood, high impact.
- Recommendations: Escape values with `printf '%q'` before writing them into the profile.

**Credentials and secrets:** No secrets, tokens or `.env` files exist in the repository. No secret handling is required by these scripts.

## Performance Bottlenecks

**Repeated package-list snapshots on Linux:**
- Problem: `pkg_install` calls `pkg_list` (a full installed-package listing) before and after each install, and `do_uninstall` calls `pkg_list` again after each removal.
- Files: `rea-install-linux.sh` (`pkg_install`, `do_uninstall`)
- Cause: Dependency tracking is done by diffing full package lists.
- Improvement path: Acceptable at this scale (a few dozen installs). Only worth changing if install time becomes a complaint.

**Large optional downloads:**
- Problem: `-WithExtras` on Windows installs WinLibs (about 250 MB per the script header), and `--with-linux-tools` pulls Python 3.12 via uv, GDB, Wireshark and more.
- Files: `rea-install-windows.ps1` (step 4), `rea-install-linux.sh` (`make_venv`, step 6)
- Cause: Documented, deliberate choice.
- Improvement path: None needed; keep the flags opt-in as they are.

## Fragile Areas

**Shell-profile block removal depends on exact marker lines:**
- Files: `rea-install-macos.sh` (`remove_profile_block`), `rea-install-linux.sh` (`remove_profile_block`)
- Why fragile: Removal is `sed "/^# >>> rea-installer >>>$/,/^# <<< rea-installer <<</d"`. If the user edits, wraps or re-indents the block, uninstall leaves stray exports or deletes unrelated lines between the markers if an end marker is lost.
- Safe modification: Keep the marker strings byte-identical in `PROFILE_BEGIN` and `PROFILE_END`. Test the removal in a sandboxed `HOME` after any change, as the README describes.
- Test coverage: The macOS README entry says profile-block removal was tested in a sandbox. Not covered in the repo itself.

**Ledger format is a plain text contract:**
- Files: `rea-install-macos.sh` (`record`, `do_uninstall`), `rea-install-linux.sh` (`record`, `pkg:` and `hopper:` cases), `rea-install-windows.ps1` (`Add-Record`, `Invoke-Uninstall`)
- Why fragile: `~/.rea-installer/installed` is parsed by `kind:value` prefix matching. Linux stores space-separated dependency lists in a `pkg:` line. A value containing a newline or a stray `:` in a non-Windows path breaks the parse. Nothing validates the ledger.
- Safe modification: Keep the `kind:` vocabulary in sync across the three scripts when adding a new kind. A kind added to install but not to uninstall leaves the item behind silently.
- Test coverage: None in the repo.

**Linux package removal depends on the distribution's dependency semantics:**
- Files: `rea-install-linux.sh` (`pkg_set_removable`, `pkg_remove`)
- Why fragile: Safe removal relies on `apt-get -s purge` output parsing, the dnf `--assumeno` plan text (matched on `Removing:` and `dependent packages`), and `pacman -Rs --print`. Locale-dependent output from dnf or apt can change those matches.
- Safe modification: Force `LC_ALL=C` around the simulation commands, and test on each supported distribution after changes.
- Test coverage: Tested in Ubuntu 24.04, Fedora 44 and Arch containers per the README. Results may not hold for other locales or for distribution upgrades.

**Arch pacman partial-upgrade risk:**
- Files: `rea-install-linux.sh` (`check_pacman_synced`, `pkg_install` pacman branch)
- Why fragile: The check only verifies that the sync database files exist. It does not check whether they are current. `pacman -S --needed` on a stale database installs packages against outdated libraries, which is the partial-upgrade state Arch warns against.
- Safe modification: Require a recent sync (for example by checking the mtime of `/var/lib/pacman/sync/core.db`) or refuse and tell the user to run `sudo pacman -Syu`.
- Test coverage: The Arch container test ran on a freshly synced image, so the stale case is not exercised.

**Windows: JAVA_HOME assumption after Temurin install:**
- Files: `rea-install-windows.ps1` (`Install-Jdk`)
- Why fragile: The script expects `winget install EclipseAdoptium.Temurin.21.JDK` to set a machine-wide `JAVA_HOME`. That depends on the installer's options, and the script throws if it is absent. The README records that this has never been run on real Windows.
- Safe modification: Locate the JDK by path (for example the Temurin install folder) as a fallback before throwing, and report which path was used.
- Test coverage: Stubbed `winget` only.

**Windows: Apktool launcher assumes `java` on PATH and ASCII-encodes its path:**
- Files: `rea-install-windows.ps1` (`-WithAndroid` branch, `Set-Content -Encoding Ascii`)
- Why fragile: The `.bat` launcher calls `@java -jar`, not `%JAVA_HOME%\bin\java`, so it fails if the session PATH lacks the JDK. `-Encoding Ascii` will corrupt a jar path under a non-ASCII user profile directory (for example `C:\Users\José`).
- Safe modification: Use `"%JAVA_HOME%\bin\java.exe"` in the launcher, and write with UTF-8 or the system default code page.
- Test coverage: Not exercised on real Windows.

**Windows: unused function:**
- Files: `rea-install-windows.ps1` (`Confirm-Step`)
- Why fragile: Defined but never called. Uninstall prompts described in the README (Homebrew, CLT, Hopper) do not exist on Windows, so the function is leftover.
- Safe modification: Remove it, or use it for the confirmation step recommended above.

**Windows: uninstall removes the ledger and env vars without checking current values:**
- Files: `rea-install-windows.ps1` (`Invoke-Uninstall`, `env` case)
- Why fragile: `SetEnvironmentVariable($name, $null, 'User')` deletes the variable even if the user has since changed it to a different value. The ledger records the name only, not the value the script set.
- Safe modification: Record the value alongside the name and delete only when the current value matches.

**Ghidra and JDK coupling on macOS:**
- Files: `rea-install-macos.sh` (`install_jdk`, step 4)
- Why fragile: `JAVA_HOME` is set only inside `install_jdk`, and `profile_exports` is written only when that function runs. If `--no-ghidra` is combined with a later step that expects `JAVA_HOME`, the variable is unset in the profile.
- Safe modification: Keep `install_jdk` idempotent and call it from each step that needs a JDK, which the Android branch already does.

## Scaling Limits

Not applicable. The scripts run once per machine and do not scale with data or users.

## Dependencies at Risk

**`rea-agents` (REA) on npm:**
- Risk: The primary dependency is an unofficial install of a third-party tool, installed at `@latest`. The README states the project is not affiliated with REA.
- Impact: A breaking or malicious release affects every new install and every rerun.
- Migration plan: Pin an exact version and bump it deliberately after a `rea doctor` check.

**Hopper (commercial, Linux and macOS only):**
- Risk: Installed through `rea setup` as a commercial app. Linux installs it with sudo and pulls its own dependencies (Xvfb and others), which the uninstall does not remove.
- Impact: Leftover packages after uninstall, as the README's "Known limitations" section already notes.
- Migration plan: Document the leftovers in the uninstall output, or record Hopper's dependencies in the ledger.

**Single-maintainer GitHub artifacts:**
- Risk: The JADX headless jar comes from `github.com/1013503897/jadx-headless-mcp`, a single-maintainer repository, and Wakaru from `pionxzh/wakaru`.
- Impact: Upstream removal or a re-tagged release breaks the pinned download. The SHA-256 pin protects against silent change but not against loss of the asset.
- Migration plan: Mirror the pinned artifacts (or keep the hash plus a fallback source) and record the mirror in the README.

## Missing Critical Features

**No verification step after install beyond `rea doctor` advice:**
- Problem: The scripts finish with "check health with `rea doctor`" but do not run it, and do not check that the pinned tool versions actually work.
- Blocks: Users cannot tell from the installer output whether the installation is healthy, and the README's "tested" claims cannot be reproduced by a user.

**No macOS or Windows real-machine test:**
- Problem: The README states that a real macOS install and any real Windows run have not been done. The macOS script is the one most likely to be used by the repo owner.
- Blocks: Confidence in the macOS and Windows install paths, including the Homebrew cask question and the Temurin `JAVA_HOME` assumption above.

## Test Coverage Gaps

**macOS install path (never run for real):**
- What's not tested: The full `install` and `uninstall` flows, Homebrew formula and cask names, the CLT dialog path, and `sudo rm -rf` of CLT.
- Files: `rea-install-macos.sh`
- Risk: The first real run could fail at the Ghidra step or overwrite profile settings unexpectedly.
- Priority: High

**Windows install path (never run on real Windows):**
- What's not tested: winget package IDs and their behavior, Temurin `JAVA_HOME`, WinLibs `objdump` on PATH, the ARM64 registry check, PowerShell 5.1 compatibility (only PowerShell 7 was used), and env-var cleanup on uninstall.
- Files: `rea-install-windows.ps1`
- Risk: The default install could fail partway, leaving registered env vars and partial tools behind.
- Priority: High

**Linux stale-pacman and optional-tool failure paths:**
- What's not tested: A failed optional install (the `|| true` branches), an Arch system with an outdated sync database, and a locale other than C or English for the removal simulation.
- Files: `rea-install-linux.sh`
- Risk: Silent partial installs and mis-detected removal sets.
- Priority: Medium

**Profile-block round-trip with user edits:**
- What's not tested: Behavior when the block was edited by hand, or when the marker lines are missing.
- Files: `rea-install-macos.sh`, `rea-install-linux.sh`
- Risk: Stray exports remain after uninstall, or unrelated lines are removed.
- Priority: Medium

---

*Concerns audit: 2026-10-14*
