---
phase: 03-macos-unattended-install-and-readme-sync
reviewed: 2026-10-15T13:57:15Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - README.md
  - rea-install-linux.sh
  - rea-install-macos.sh
  - test.sh
findings:
  critical: 1
  warning: 8
  info: 3
  total: 12
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-10-15T13:57:15Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

I reviewed the phase 3 diff (`a36be83..HEAD`): `have_tty`, `TTY_PATH`, two-argument `confirm`, `register_agents` in both bash scripts, macOS `install_homebrew`, the README sync, and the new MAC-01/MAC-02 checks in `test.sh`. I also read the surrounding macOS install and uninstall paths that the new code feeds into. I checked Homebrew's current `install.sh` and `uninstall.sh` (fetched as data, not run) to confirm how they behave with `NONINTERACTIVE`, stdin and `sudo`.

`/bin/bash ./test.sh` on this Mac: 114 passed, 0 failed, 2 skipped (both Linux-only). Shellcheck passes on all three files, and the container dry runs (DRY-01, DRY-02) pass.

The no-terminal handling itself is correct. `have_tty` opens the device rather than testing the file, every `confirm` call passes the second argument, and an inherited `TTY_PATH` is overwritten. The problems are around `install_homebrew` and what happens after it:

- On Apple silicon, a Homebrew installed by the script never gets onto `PATH` in new terminals, so the `rea doctor` command the script prints at the end fails.
- The new `sudo -v` stops Homebrew's installer from clearing the cached sudo credential when it exits, so that credential is still live while unpinned npm and brew code runs.
- If Homebrew's installer fails partway, the Homebrew it leaves behind is never recorded, and a rerun treats it as yours.
- Items kept because there was no terminal are dropped from the ledger, because uninstall deletes `~/.rea-installer` anyway.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: A Homebrew installed by the script is never added to PATH, so the final `rea doctor` fails in a new terminal on Apple silicon

**File:** `rea-install-macos.sh:232-250`, `rea-install-macos.sh:252-294`, `rea-install-macos.sh:376`
**Issue:** On a Mac without Homebrew, `install_homebrew` puts `brew` under `/opt/homebrew/bin` on Apple silicon. Homebrew's installer does not edit any shell profile; it only prints "Next steps" telling the user to add `eval "$(/opt/homebrew/bin/brew shellenv)"` (install.sh, lines ~1167-1181). Under `NONINTERACTIVE`, that message is buried in the middle of a long run. `load_brew` fixes `PATH` only for the current process.

The profile block holds only `JAVA_HOME`, `REA_OBJDUMP_COMMAND` and `REA_WABT_BIN_DIRECTORY`. Unlike Linux (line 543), it never adds a `PATH` entry. `/opt/homebrew/bin` is not in macOS's default `/etc/paths`. So when Node.js came from Homebrew, `rea_bin` is `/opt/homebrew/bin/rea`, an npm launcher that, like npm CLIs generally, starts with `#!/usr/bin/env node`. In the "new terminal" that line 376 tells the user to open, `node` is not on `PATH`, so `$rea_bin doctor` fails with `env: node: No such file or directory`. `brew` and `ghidraRun` are missing from `PATH` too. The install reports "Done" while its own health check does not run.

This was already true before this phase. Phase 3 makes the fresh-Mac unattended path (`--yes`, no Homebrew) a supported flow, which makes it more visible. Intel Macs are not affected because `/usr/local/bin` is on the default `PATH`.
**Fix:** When this run installed Homebrew, put Homebrew's shellenv in the profile block, so uninstall removes it together with the block:
```bash
install_homebrew() {
  ...
  record "homebrew"
  [ "$dry_run" = true ] || load_brew || die "Homebrew installed but brew was not found."
  local brew_path
  if [ "$(uname -m)" = arm64 ]; then brew_path=/opt/homebrew/bin/brew; else brew_path=/usr/local/bin/brew; fi
  # Homebrew's installer only prints this step; without it new terminals have no brew, node or rea.
  profile_exports+=("eval \"\$($brew_path shellenv)\"")
}
```
If the user later declines to remove Homebrew at uninstall, removing the block takes `brew` off `PATH` again. Either write that line outside the block in that case, or warn about it.

## Warnings

### WR-01: `sudo -v` keeps a cached root credential live after Homebrew's installer exits, while unpinned third-party code runs

**File:** `rea-install-macos.sh:239-244`
**Issue:** Homebrew's installer deliberately clears the sudo credential when it exits, but only if no credential was cached before it started:
```bash
if ! /usr/bin/sudo -n -v 2>/dev/null; then trap '/usr/bin/sudo -k' EXIT; fi
```
(install.sh ~line 329). Because `install_homebrew` runs `sudo -v` first, that check succeeds, no trap is set, and the credential stays valid. On macOS it stays valid for this terminal, and every successful `sudo` call by the installer extends it, for 5 minutes by default.

The script then runs `brew install` formulae, `npm install --global rea-agents@latest` (unpinned dependencies, with lifecycle scripts) and `rea setup --yes --all-detected` in the same terminal. A short run, such as nvm Node with `--no-ghidra`, reaches npm well inside that window. Any child process can then run `sudo -n …` and get root without a prompt. This phase introduced the exposure; before it, Homebrew cleared the credential itself.
**Fix:** Clear the credential as soon as Homebrew's installer finishes, whether it succeeded or not:
```bash
if have_tty; then run sudo -v || die "$hint"; fi
local rc=0
run env NONINTERACTIVE=1 /bin/bash -c "$script" || rc=$?
[ "$dry_run" = true ] || sudo -k
((rc == 0)) || die "$hint"
```

### WR-02: A Homebrew install that fails partway is orphaned, and a rerun adopts it as the user's

**File:** `rea-install-macos.sh:244-249`, `rea-install-macos.sh:321`
**Issue:** `record "homebrew"` runs only when the installer exits 0. Homebrew's installer creates `/opt/homebrew/bin/brew` during its git checkout (install.sh ~line 1047). It then fetches homebrew-core and runs `brew update --force` (~line 1097). Either can fail on the network and abort with a non-zero exit. The script then dies with nothing recorded.

On the rerun the README promises will recover, `load_brew` finds `/opt/homebrew/bin/brew`, so step 2 treats Homebrew as already present and never records it. Uninstall then never offers to remove a Homebrew that this script installed.

Recording is safe here: `install_homebrew` runs only when `load_brew` has just found no `brew` at either prefix, so nothing that existed before the run can be mistaken for the script's.
**Fix:** If the installer failed but left a `brew` behind, record it before dying:
```bash
if ! run env NONINTERACTIVE=1 /bin/bash -c "$script"; then
  # load_brew found no brew before this call, so any brew now present is ours.
  { [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ]; } && record "homebrew"
  die "$hint"
fi
```
Then update the README line "a Homebrew install that fails ... records nothing" to match.

### WR-03: Items kept because there was no terminal are lost from the ledger, because uninstall deletes `~/.rea-installer` anyway

**File:** `rea-install-macos.sh:411`, `rea-install-macos.sh:441-449`, `rea-install-linux.sh:610`, `rea-install-linux.sh:637`
**Issue:** With no terminal, `confirm` now warns "no terminal available; leaving Homebrew in place." and returns 1. The `app:`, `homebrew`, `clt` and `hopper:` records are kept in the user's interest. But both scripts then run `rm -rf "$STATE_DIR"` without conditions, which deletes the ledger that recorded them.

Running `uninstall` again from a terminal later can no longer offer to remove the Hopper app, Homebrew or the Command Line Tools, so they become indistinguishable from things the user installed. The user never chose to keep them; the default was applied because no terminal was available. The new warning wording ("leaving … in place") suggests they can deal with it later, but they cannot.
**Fix:** Keep the records that were not removed. Collect them while processing, and if any are left, rewrite the ledger with only those lines instead of deleting the directory:
```bash
kept=()
...
elif ! have_tty && [ "$assume_yes" = false ]; then kept+=("homebrew"); fi
...
if [ "$dry_run" = false ]; then
  rm -rf "$STATE_DIR"
  if ((${#kept[@]} > 0)); then
    mkdir -p "$STATE_DIR"; printf '%s\n' "${kept[@]}" >"$STATE_FILE"
    warn "kept ${#kept[@]} item(s) in $STATE_FILE; rerun uninstall from a terminal to remove them."
  fi
fi
```
At minimum, make the warning say the item will not be tracked after this run. Under `set -u` on Bash 3.2, an empty `"${kept[@]}"` is unbound, so check the length before expanding it, as shown.

### WR-04: Piped into bash, Homebrew's installer inherits the script's stdin and is forced non-interactive, even with a terminal and without `--yes`

**File:** `rea-install-macos.sh:245-246`, `test.sh:429-434`
**Issue:** With `curl … | bash -s -- install`, the child `/bin/bash -c "$script"` inherits stdin, which is the pipe. Homebrew's installer sees `[[ ! -t 0 ]]`, sets `NONINTERACTIVE=1` itself, and switches to `sudo -n` (install.sh lines 135-141, 297-299). With no cached credential, the install fails and the script dies with the sudo hint, although a terminal is available.

The README lists this as a known limitation, but the script already holds the fix: `register_agents` handles the same problem by redirecting from `$TTY_PATH`. The MAC-02 check named "Homebrew without --yes is not forced non-interactive" only checks that the word `NONINTERACTIVE` does not appear in the printed command, so it passes even though Homebrew is forced non-interactive in exactly this case. The name claims more than the check proves.
**Fix:**
```bash
elif have_tty; then
  run /bin/bash -c "$script" <"$TTY_PATH" || die "$hint"
else
  run /bin/bash -c "$script" || die "$hint"
fi
```
Then drop the "Piped into bash without `--yes`" sentence from the README limitations, and rename the check or add one that asserts the redirection.

### WR-05: The failure hint blames sudo for every Homebrew failure, and an inherited `INTERACTIVE` makes the `--yes` path abort

**File:** `rea-install-macos.sh:233`, `rea-install-macos.sh:241-246`
**Issue:** `hint` says "Homebrew install failed; it needs sudo. Run 'sudo -v' and rerun". It is printed for every non-zero exit: a git or network failure during the clone or `brew update`, a full disk, the user pressing a key other than Return at Homebrew's prompt, or a user who is not an administrator. The project's contract is "stops with a message saying what to do", and for most of those causes this message points the user at the wrong fix.

Separately, Homebrew aborts when both `INTERACTIVE` and `NONINTERACTIVE` are set (install.sh lines 31-33). A user with `INTERACTIVE` exported who runs with `--yes` gets an immediate abort, which the script then reports as a sudo problem.
**Fix:** Make the hint neutral and point at Homebrew's own output, and clear the conflicting variable:
```bash
local hint="Homebrew's installer failed (see its output above). If it could not use sudo, run 'sudo -v' in this terminal and rerun, or install Homebrew first."
...
run env -u INTERACTIVE NONINTERACTIVE=1 /bin/bash -c "$script" || die "$hint"
```
Update the expected message in `test.sh:442` to match.

### WR-06: A dry run now downloads Homebrew's installer and dies offline, and prints the whole installer as the plan

**File:** `rea-install-macos.sh:236-237`, `rea-install-macos.sh:244`, `rea-install-macos.sh:246`
**Issue:** `script="$(curl …)" || die` runs under `--dry-run` too. The old code also fetched in a dry run, but an offline dry run on a Mac without Homebrew carried on. It now stops with "could not download the Homebrew installer." A dry run should print the plan without depending on the network.

The `run` line also passes the entire `install.sh` (about 35 KB) through `printf %q`, so the dry-run "plan" contains one enormous escaped line where the step should be.
**Fix:** Skip the download in a dry run and print a placeholder:
```bash
if [ "$dry_run" = true ]; then
  script='<Homebrew install.sh from https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh>'
else
  script="$(curl -fsSL --proto '=https' https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ||
    die "could not download the Homebrew installer."
fi
```
The MAC-02 dry-run checks still pass, because they match only the `env NONINTERACTIVE=1 /bin/bash -c ` prefix.

### WR-07: The Homebrew uninstall step does not stop when its download fails, and `--yes` does not get past Homebrew's own prompt

**File:** `rea-install-macos.sh:441-443`, `rea-install-macos.sh:449`
**Issue:** This is the uninstall side of the problem `install_homebrew` was written to fix (see its comment at line 235). `run /bin/bash -c "$(curl -fsSL …/uninstall.sh)"`: if `curl` fails, the command substitution's status is discarded and `bash -c ''` exits 0. I confirmed this under `/bin/bash` 3.2 with `set -euo pipefail`. The script then deletes the ledger (line 449) and logs "REA uninstalled.", leaving Homebrew in place, no longer recorded, and no error shown.

`curl` here also lacks `--proto '=https'`. Under `--yes` from a terminal, Homebrew's `uninstall.sh` asks its own "Are you sure… [y/N]" question (uninstall.sh line 421, which runs when stdin is a TTY and `--force` or `NONINTERACTIVE` is not set). The README says `--yes` "accepts uninstall prompts", but this prompt is not accepted.
**Fix:**
```bash
if grep -qxF homebrew <<<"$state" && confirm "Remove Homebrew (installed by this script)?" "Homebrew"; then
  local uninstaller
  uninstaller="$(curl -fsSL --proto '=https' https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" ||
    die "could not download the Homebrew uninstaller; rerun uninstall."
  # confirm already asked, so Homebrew's own prompt is redundant.
  run env NONINTERACTIVE=1 /bin/bash -c "$uninstaller"
fi
```
Dying before line 449 keeps the ledger, so a rerun can retry.

### WR-08: macOS uninstall exits with no message when the recorded npm cannot run, contradicting the README

**File:** `rea-install-macos.sh:391`, `README.md:36`
**Issue:** `[ -n "$npm_bin" ] && rea_bin="$("$npm_bin" prefix --global)/bin/rea"`. The assignment is the final command of an `&&` list, so `set -e` applies to it. When `npm prefix` fails (for example, an `npm` whose `node` was removed, or a broken nvm install), `do_uninstall` exits 1 before any cleanup and prints only npm's own stderr. I confirmed the pattern exits under `/bin/bash` 3.2. The README now says "If it fails, or the `rea` CLI is broken, uninstall warns and carries on with the rest". On macOS a broken npm gives neither a warning nor any further cleanup. Linux (line 582) does not have this problem.
**Fix:**
```bash
if [ -n "$npm_bin" ]; then
  rea_bin="$("$npm_bin" prefix --global 2>/dev/null)/bin/rea" || { warn "npm at $npm_bin does not run."; rea_bin=""; }
fi
```

## Info

### IN-01: Gaps in the new tests

**File:** `test.sh:388-393`, `test.sh:358-451`
**Issue:**
- "confirm with a terminal reads the answer" never checks `$rc`.
- No check runs `do_uninstall` without a terminal from start to finish, so the ledger loss in WR-03 is not covered.
- Homebrew success is checked only in dry runs. Nothing checks that `record homebrew` happens after a successful real run, or the partial-install case in WR-02.
**Fix:** Add `[ "$rc" -eq 0 ]` to the terminal check. Add a sandboxed `do_uninstall` check with a stub `brew` and `rea` and `TTY_PATH="$work/no-tty"`, and assert on the ledger state after the run.

### IN-02: `confirm` exits under `set -u` if a future caller leaves out ITEM

**File:** `rea-install-macos.sh:57`, `rea-install-linux.sh:71`
**Issue:** `$2` is required. Every current caller passes it, but one that does not crashes with "unbound variable", and that happens only on the no-terminal path, which is the hardest one to test by hand.
**Fix:** `warn "no terminal available; leaving ${2:-it} in place."`

### IN-03: The README says installing Ghidra always "installs and records" `openjdk@21`

**File:** `README.md:52`
**Issue:** `brew_install` skips a formula that is already installed and does not record it (`rea-install-macos.sh:124-125`). If the user already has `openjdk@21` from Homebrew, it is left alone and not recorded, which is the correct behaviour, but the sentence says otherwise.
**Fix:** "...also installs and records Homebrew's `openjdk@21` if it isn't already installed, because Homebrew's `ghidra` depends on it..."

---

_Reviewed: 2026-10-15T13:57:15Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
