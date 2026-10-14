# Installer Hardening Audit

**Date:** 2026-10-14
**Scope:** `rea-install-linux.sh`, `rea-install-macos.sh`, `rea-install-windows.ps1` (read in full), README status/testing/limitations
**Assumed load:** one person running the installer on their own machine, sometimes rerun. Judged on correctness and failure recovery, not concurrency.
**Source:** `/ponytail-audit` (report only, no code changed); HARD-11 and HARD-12 added from `/code-review high` the same day. That review also found errors in `.planning/codebase/*.md`, which have been corrected.

## Milestone goal

Make every installer fail loudly instead of silently, recover cleanly on rerun and uninstall, respect the user's existing Java setup, and add one repeatable test so these regressions are caught automatically.

## Root cause behind findings 1 and 2

Bash disables `set -e` in two places these scripts rely on:

- inside command substitution `$(...)` (bash without `inherit_errexit`, including macOS bash 3.2)
- inside any function called on the left of `||` / `&&` or in an `if` condition

Verified under bash 3.2.57:

```bash
set -euo pipefail
u() { false; echo "after-fail"; }
x="$(u)"            # x = "after-fail"; script continues
p() { false; echo "kept going"; }
p || exit 1         # prints "kept going"; exit never runs
```

---

## Requirements

Severity: **MUST** = bug, crash, or data/env damage. **SHOULD** = risk or missing test. **NICE** = polish.

### HARD-01 — Failed archive extraction is swallowed and blocks reruns (MUST)

- **Where:** `rea-install-linux.sh:239-250` (`unpack`), `rea-install-windows.ps1:133-140` (`Expand-PinnedArchive`)
- **Problem:** `unpack` always runs inside `$(...)`, so a failed `unzip`/`tar` is ignored. The archive is deleted, the target path is returned, and the script sets e.g. `GHIDRA_INSTALL_DIR` to a broken folder and prints "Done". Reruns skip extraction because the partial folder exists. Windows throws on the error, but has the same partial-folder rerun problem.
- **Scenario:** Disk fills or Ctrl-C during the ~400 MB Ghidra unzip → Ghidra broken until the user manually deletes `~/.rea-installer/tools/ghidra_*`.
- **Fix:** After the extract `case` in `unpack`: `|| { rm -rf "$target"; die "could not unpack $(basename "$archive")"; }`. On Windows, wrap the `tar` step in `try`/`catch` and remove `$target` in `catch` before rethrowing.
- **Acceptance:** A forced extract failure exits non-zero, leaves no `$target` folder, and a rerun extracts again.

### HARD-02 — `pkg_install` failures are recorded as success; `|| die` guards never fire (MUST)

- **Where:** `rea-install-linux.sh:158-180`, callers `352-356`; `rea-install-macos.sh:105` (`brew_install`), caller `191`
- **Problem:** Every caller uses `pkg_install X || die ...` / `|| true` / `if !`, which disables `set -e` inside the function. A failed `apt-get`/`dnf`/`pacman install` continues, records `pkg:X`, and returns 0. Same for `brew install` via `[ -n "$JAVA_HOME" ] || install_jdk`.
- **Scenario:** Fresh Ubuntu VM where unattended-upgrades holds the dpkg lock → curl/unzip silently missing, confusing failure later or "Done" with tools absent.
- **Fix:** Append `|| return 1` to the three install commands in `pkg_install` (lines 173, 175, 176) and to `run brew install` in `brew_install`.
- **Acceptance:** A failed package install makes `pkg_install` return non-zero, writes no state record, and the `|| die` message appears.

### HARD-03 — `--dry-run` crashes on a fresh Linux machine and deletes a real folder (MUST)

- **Where:** `rea-install-linux.sh:292-313` (`install_node`, `install_jdk`)
- **Problem:** With no Node present, dry-run `install_node` only prints, then `install_jdk` pipes Adoptium JSON into `node -e` → "command not found" → exit. Hits default options on x64 (Ghidra on by default). Also `rm -rf "$STATE_DIR/node"` (line 297) is not wrapped in `run`, so dry-run really deletes it.
- **Fix:** In `install_jdk`'s download branch: `[ "$dry_run" = true ] && { log "would download Temurin 21"; setting JAVA_HOME "$STATE_DIR/jdk"; return; }`. Change line 297 to `run rm -rf ...`.
- **Acceptance:** `./rea-install-linux.sh install --dry-run --with-android` exits 0 in a fresh `ubuntu:24.04` container with no Node, and changes nothing on disk.

### HARD-04 — Windows likely aborts with "Temurin installed but JAVA_HOME was not set" (MUST, unverified)

- **Where:** `rea-install-windows.ps1:144-151` (`Install-Jdk`)
- **Problem:** Adoptium's MSI probably sets `JAVA_HOME` only when its `FeatureJavaHome` option is chosen, and that option is off by default. winget's silent install doesn't choose it. README lists this exact point as untested on real Windows.
- **Fix:** After `Install-Winget $JdkId` and `Update-SessionPath`, derive the JDK folder from the `java` now on PATH: `$env:JAVA_HOME = Split-Path (Split-Path (Get-Command java).Source)`, then persist it with `Set-UserEnv` (so uninstall removes it).
- **Acceptance:** Default x64 install completes with `JAVA_HOME` pointing at Temurin 21, whether or not the MSI set it. Confirm on real Windows.

### HARD-05 — macOS overwrites the user's existing `JAVA_HOME` in every new shell (SHOULD)

- **Where:** `rea-install-macos.sh:122-128`, `184`
- **Problem:** The Ghidra step always calls `install_jdk`, which writes `export JAVA_HOME=<brew openjdk@21>` into the shell profile, overriding a user's JDK 17 etc. Contradicts README's "leaves pre-existing tools alone". Linux respects an existing `JAVA_HOME`.
- **Fix:** Line 184: `[ -n "${JAVA_HOME:-}" ] || install_jdk`, combined with the version check from HARD-06.
- **Acceptance:** With `JAVA_HOME` set to a JDK ≥21, install writes no `JAVA_HOME` line to the profile.

### HARD-06 — Existing `JAVA_HOME` trusted even when too old for Ghidra 12 (SHOULD)

- **Where:** `rea-install-linux.sh:305-309`, `rea-install-windows.ps1:145` (and macOS after HARD-05)
- **Problem:** Ghidra 12 needs JDK 21+. A user with `JAVA_HOME` set to openjdk-17 or 11 gets a Ghidra that won't start, while the script reports "Done".
- **Fix:** Trust `JAVA_HOME` only if `"$JAVA_HOME/bin/java" -version` reports major ≥21; otherwise install the script's own JDK. Same check in PowerShell.
- **Acceptance:** With `JAVA_HOME` → JDK 17, install uses its own Temurin 21; with JDK 21+, it reuses the existing one.

### HARD-07 — Broken `rea` CLI blocks the entire uninstall (SHOULD)

- **Where:** `rea-install-linux.sh:515-517`, `rea-install-macos.sh:258-260`, `rea-install-windows.ps1:234-236`
- **Problem:** `rea uninstall --purge-data` runs under `set -e` / `Invoke-Step`, so any failure stops uninstall before packages, profile blocks or `~/.rea-installer` are removed. Rerunning hits the same wall.
- **Scenario:** User removed the nvm Node that `rea` was installed under → `#!/usr/bin/env node` fails → uninstall can never complete.
- **Fix:** bash: `run "$rea_bin" uninstall --purge-data || warn "rea uninstall failed; remove agent registrations by hand."`. Windows: wrap in `try { ... } catch { Warn $_ }`.
- **Acceptance:** With a `rea` that exits non-zero, uninstall warns and still removes everything else it recorded.

### HARD-08 — No repeatable test for the riskiest logic (SHOULD)

- **Where:** whole repo (no test script, no CI)
- **Problem:** Logic that decides what to delete is duplicated between scripts and must change together: profile-block `sed` removal, the Node version gate (three copies), and package "safe to remove" checks. A one-character `sed` slip could delete lines from a user's `.zshrc` unnoticed.
- **Fix:** Add one `test.sh` that:
  1. runs `shellcheck` and `bash -n` on both bash scripts
  2. against a temporary `$HOME`: adds then removes the profile block and checks the rest of the file is byte-identical
  3. checks `node_supported` accepts/rejects a table of version strings (e.g. 22.18 no, 22.19 yes, 24.14 no, 24.15 yes, 26.0 yes)
  4. runs `install --dry-run` in a fresh `ubuntu:24.04` container and expects exit 0 (covers HARD-03)
- **Acceptance:** `./test.sh` passes locally; each of HARD-01/02/03 has a check that fails before its fix.

### HARD-09 — macOS `rea setup </dev/tty` fails without a terminal (NICE)

- **Where:** `rea-install-macos.sh:234-236`
- **Fix:** Copy the Linux `elif [ -r /dev/tty ]` / `else warn` branch (`rea-install-linux.sh:487-491`).
- **Acceptance:** Install over non-tty ssh or CI warns instead of failing.

### HARD-10 — `--yes` doesn't make the Homebrew install non-interactive (NICE)

- **Where:** `rea-install-macos.sh:162`
- **Fix:** When `assume_yes` is true, run the Homebrew installer with `NONINTERACTIVE=1`.
- **Acceptance:** `install --yes` on a Mac without Homebrew doesn't wait for Return.

### HARD-11 — macOS rerun drops `JAVA_HOME` from the shell profile (MUST)

- **Where:** `rea-install-macos.sh:180-216` (steps 4-7), `install_jdk` `122-128`
- **Problem:** `JAVA_HOME` reaches the profile block only when `install_jdk` runs, and the block is rewritten whole on every run. On a rerun, Ghidra is already on `PATH` (step 4 skips `install_jdk`) and `JAVA_HOME` is already set from the old block (step 5's `[ -n "$JAVA_HOME" ] || install_jdk` skips it too). With `--with-extras`, the block is rewritten holding only the extras.
- **Scenario:** `install --with-extras`, then rerun `install --with-extras` from a new terminal → `~/.zshrc` loses `export JAVA_HOME=...` → new shells and later `rea setup` runs have no JDK. Linux avoids this by unsetting its own settings and rewriting them every run (`rea-install-linux.sh:345-349`).
- **Fix:** When `JAVA_HOME` points at the script's `openjdk@21` (`brew --prefix openjdk@21`), add it to `profile_exports` again even if `install_jdk` was skipped. Fold this into HARD-05's "reuse or install" rule.
- **Acceptance:** Two `install --with-extras` runs in a row leave exactly one profile block that still contains `JAVA_HOME`.

### HARD-12 — Linux `uninstall --dry-run` removes `~/.agents` for real (NICE)

- **Where:** `rea-install-linux.sh:563`
- **Problem:** `rmdir "$HOME/.agents/skills" "$HOME/.agents"` runs outside `run` and has no `dry_run` check. It only removes empty folders, so the harm is small, but it breaks the "dry run changes nothing" promise.
- **Fix:** `[ "$dry_run" = true ] || rmdir ...`, the same guard the next line uses.
- **Acceptance:** `uninstall --dry-run` leaves an empty `~/.agents/skills` in place.

---

## Suggested phase breakdown

| Phase | Requirements | Notes |
|---|---|---|
| 1. Fail loudly | HARD-01, HARD-02, HARD-07 | Shared root cause (errexit); each fix is about one line per script |
| 2. Dry-run and test harness | HARD-03, HARD-08, HARD-12 | Write the tests first; they should fail before the HARD-01/02/03 fixes |
| 3. Java handling | HARD-04, HARD-05, HARD-06, HARD-11 | One consistent "reuse JDK ≥21, else install our own" rule across all three scripts, and keep `JAVA_HOME` across reruns |
| 4. macOS polish | HARD-09, HARD-10 | Small; can fold into phase 3 |

Phases 1 and 2 can swap if you prefer test-first.

## Out of scope / not checked

- No real installs were run on macOS or Windows; nothing was installed on Linux during the audit.
- HARD-04 is based on my understanding of the Temurin MSI's defaults, not on documentation I checked or behavior I observed. Verify on real Windows.
- Unverified: whether REA finds Ghidra on macOS without `GHIDRA_INSTALL_DIR` (Homebrew installs Ghidra as a cask, and the script never sets the variable). Worth a check during phase 3.
- REA's own `setup` / `uninstall` behavior was not reviewed.
- Intentional, not a finding: the two bash scripts duplicate their helpers. Each one is meant to run standalone via `curl | bash`, so sharing code would break that.

## Lean

No meaningful deletions found. The scripts are already tight.
