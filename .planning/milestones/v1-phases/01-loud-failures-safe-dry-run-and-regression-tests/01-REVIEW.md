---
phase: 01-loud-failures-safe-dry-run-and-regression-tests
reviewed: 2026-10-14T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - rea-install-linux.sh
  - rea-install-macos.sh
  - rea-install-windows.ps1
  - test.sh
  - .github/workflows/test.yml
findings:
  critical: 0
  warning: 7
  info: 4
  total: 11
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-10-14
**Depth:** standard (diff `d927b0d..HEAD`, full files read for context)
**Files Reviewed:** 5
**Status:** issues_found

## Summary

The phase delivers what HARD-01/02/03/07/08/12 asked for. `unpack` and `Expand-PinnedArchive` now stage before renaming. `pkg_install` and `brew_install` propagate failures. The Linux dry run no longer needs Node or deletes `~/.rea-installer/node`. A failing `rea` no longer blocks uninstall on any platform. `test.sh` passes locally on macOS: 31 passed, 0 failed, 2 skipped (Linux-only checks).

No blockers found. The main concerns:

1. **New silent-failure path in `unpack`.** The "no top-level folder" fallback in the new Linux `unpack` turns an archive-layout mismatch into a silently wrong install instead of a loud failure. This contradicts the phase goal. Verified with a reproduction.
2. **Stale partial folders are now trusted.** Moving Rizin and Wakaru onto `unpack` replaced a file-level "already installed" check with a directory-level one, so a partial folder left by an older run is now trusted. Verified.
3. **The dry-run tests miss content changes.** They compare only file *names*, so a regression that edits `~/.bashrc` during a dry run would still pass.
4. **Smaller loud-failure gaps remain.** A failing `pkg_list` is still swallowed, and partial package installs leave changes that are never recorded in the ledger.

## Warnings

### WR-01: `unpack` hides archive-layout mismatches by moving the whole staging folder

**File:** `rea-install-linux.sh:252-254`
**Issue:** If the archive has no `$2` folder at its top level, `unpack` assumes the archive has no top-level folder at all. It moves the entire staging folder to `$TOOLS_DIR/$2` and succeeds. When the archive actually *has* a top-level folder under a different name, the result is `$TOOLS_DIR/$2/<real-name>/...`. Callers then point settings one level too high:

- `JAVA_HOME` (`install_jdk`, line 332, where `$release` comes from Adoptium's live API, not a pin)
- `GHIDRA_INSTALL_DIR` (line 397)
- `REA_WABT_BIN_DIRECTORY` (line 434)
- the Node `PATH` (line 313)

The install still prints "Done". The old code failed loudly in the same case, because `mv "$dir" "$STATE_DIR/jdk"` hit a missing folder. Reproduced: an archive containing `jdk-21.0.9+10/bin/java`, unpacked as `jdk-21.0.9+11`, returns rc=0 and the folder `tools/jdk-21.0.9+11/jdk-21.0.9+10/bin/java`.
**Fix:** Make the flat-archive case explicit instead of guessing, and fail when the expected folder is missing:
```bash
# Usage: unpack "url sha256" DIR [--flat]
if [ "${3:-}" = --flat ]; then
  src="$staging"
elif [ -d "$staging/$2" ] || [ "$dry_run" = true ]; then
  src="$staging/$2"
else
  run rm -rf "$staging" >&2; die "$(basename "$archive") has no top-level $2 folder."
fi
```
Then call it with `--flat` for Rizin (line 424) and Wakaru (line 452). Windows already fails loudly here, because `Move-Item` throws at `rea-install-windows.ps1:147`.

### WR-02: Rizin and Wakaru now trust a partial folder left by an earlier failed run

**File:** `rea-install-linux.sh:423-425`, `rea-install-linux.sh:451-453`
**Issue:** The old code skipped extraction only when the binary existed (`[ ! -x "$rizin_dir/bin/rizin" ]`, `[ ! -x "$wakaru_dir/wakaru" ]`). It also ran `mkdir -p "$rizin_dir"` *before* `tar`, so an interrupted or failed extract left a partial folder that the next run retried. `unpack` only checks `[ ! -d "$target" ]`. After upgrading the script, that same partial folder is now trusted forever. `REA_RIZIN_COMMAND` and `REA_WAKARU_COMMAND` are written into the profile pointing at missing binaries, and the run prints "Done". Reproduced: an empty `tools/rizin-0.9.1/` makes `unpack` return rc=0 with no `bin/rizin`.
**Fix:** At each call site, check the file the caller needs and redo the extract when it is missing:
```bash
rizin_dir="$(unpack "$RIZIN_x64" rizin-0.9.1)"
[ "$dry_run" = true ] || [ -x "$rizin_dir/bin/rizin" ] || die "$rizin_dir is incomplete; delete it and rerun."
```
Alternatively, pass an expected-file argument to `unpack` and treat a target without that file as absent: `rm -rf` it, then extract again.

### WR-03: DRY-01/DRY-02 compare file names only, so a dry run that edits a file still passes

**File:** `test.sh:243-246`, `test.sh:255-257`
**Issue:** `find ~ | sort` lists paths only. The most likely dry-run regressions would not change that list:

- appending to an existing `~/.bashrc` (the profile write at `rea-install-linux.sh:482`)
- `sed -i` from `remove_profile_block`
- rewriting the ledger

Also, DRY-02 seeds no ledger and no profile block. So the dry-run uninstall's `profile:`, `pkg:` and `hopper:` branches are never exercised, and the check only covers the `rmdir` and the final `rm -rf`.
**Fix:** Record size, mode and mtime (or content hashes), and seed a ledger plus a profile block for DRY-02:
```bash
snap() { find ~ -printf '%p %s %m %T@\n' | sort; }
before="$(snap)"; ...; [ "$(snap)" = "$before" ] || { echo "dry run changed the home folder"; exit 1; }
# DRY-02 setup:
printf "keep\n# >>> rea-installer >>>\nexport X=1\n# <<< rea-installer <<<\n" >>~/.bashrc
printf "profile:%s\npkg:curl\n" ~/.bashrc >~/.rea-installer/installed
```

### WR-04: `pkg_install` still swallows a failing `pkg_list`, which can corrupt the ledger

**File:** `rea-install-linux.sh:169`, `rea-install-linux.sh:178-179`
**Issue:** Every caller invokes `pkg_install` as `pkg_install X || ...` or `if ! pkg_install X`, so errexit is off inside it. This is the root cause behind HARD-02. The phase added `|| return 1` to the install command only. If `before="$(pkg_list)"` fails (dpkg-query/rpm/pacman error, which pipefail reports), `before` is silently empty. `added` then becomes *every installed package*, and that list is written to `pkg:NAME ...`. Uninstall feeds this set to `pkg_set_removable` and `apt-get purge`. On apt, the only thing that prevents mass removal is apt refusing to remove essential packages under `-y`.
**Fix:**
```bash
before="$(pkg_list)" || { warn "could not list installed packages."; return 1; }
...
added="$(comm -13 <(printf '%s\n' "$before") <(pkg_list) | grep -vxF "$name" | tr '\n' ' ')" || true
local after; after="$(pkg_list)" || { warn "could not list installed packages."; return 1; }
```
The `added` pipeline needs no check, because `grep -v` exits 1 when nothing is added. The real fix is to capture the second `pkg_list` into a variable and check that.

### WR-05: A failed package or brew install records nothing, leaving partial changes uninstall cannot remove

**File:** `rea-install-linux.sh:173-176`, `rea-install-macos.sh:106`
**Issue:** `|| return 1` returns before the `added` diff and `record`. When `apt-get install` or `dnf install` fails after unpacking or configuring some dependencies, or `brew install` fails after pouring dependencies, those packages stay on the machine with no ledger entry. The optional tools (`adb`, `binutils`, `tshark`, `sigrok-cli`, `gdb`) now `warn` and continue, so this path leads to a "Done" install whose later `uninstall` leaves the extra packages behind. The project's core value requires that uninstall remove exactly what the script added.
**Fix:** On failure, still record what was newly added, excluding the target package if it is not installed. For example, on Linux:
```bash
if ! run sudo_cmd ...; then
  added="$(comm -13 <(printf '%s\n' "$before") <(pkg_list) | tr '\n' ' ')"
  [ -n "${added// }" ] && record "pkg:$name ${added% }"
  return 1
fi
```
On macOS, snapshot `brew list --formula -1` before and after, and record each new formula as `brew:NAME`.

### WR-06: The PowerShell parse check uses the pwsh 7 parser, so 5.1-incompatible syntax passes CI

**File:** `test.sh:73-86`
**Issue:** The project requires `rea-install-windows.ps1` to run on Windows PowerShell 5.1. TEST-01 parses it with `pwsh`, which accepts 7-only syntax: `??`, `?.`, ternary `a ? b : c`, pipeline chains `&&`/`||`, and `clean {}`. The driver comment (line 267) acknowledges this for the driver itself, but the installer has no guard. A 7-only construct would pass CI and then fail on every stock Windows 10/11 machine that runs it with `powershell.exe`.
**Fix:** Add a check for PS7-only tokens using the AST, or a simple token scan:
```powershell
$tokens = $null; [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
$bad = $tokens | Where-Object { $_.Kind -in 'QuestionQuestion','QuestionQuestionEquals','QuestionDot','QuestionLBracket','AndAnd','OrOr' -or ($_.Kind -eq 'QuestionMark') }
if ($bad) { $bad | ForEach-Object { Write-Host "PS7-only token $($_.Text) at line $($_.Extent.StartLineNumber)" }; exit 1 }
```

### WR-07: macOS install, including `--dry-run`, dies at the final step without a terminal

**File:** `rea-install-macos.sh:233-237`
**Issue:** `run "$rea_bin" setup </dev/tty` has no guard. Without a controlling terminal (CI, ssh without `-t`, some agent-driven shells), the redirect itself fails ("/dev/tty: Device not configured", exit 1, confirmed). `set -e` then aborts the install after `npm install` has already run and been recorded. Because the redirect happens even when `run` would only print, `install --dry-run` also exits non-zero. This phase fixed exactly this in the Linux script (line 493) but not here, so the scripts now diverge. This is tracked as HARD-09, but it undercuts this phase's "dry run exits 0" goal on macOS.
**Fix:** Mirror the Linux branch:
```bash
elif (: </dev/tty) 2>/dev/null; then
  run "$rea_bin" setup </dev/tty
else
  warn "no terminal available; run '$rea_bin setup' yourself."
fi
```

## Info

### IN-01: The dry-run plan differs from what a real run would do

**File:** `rea-install-linux.sh:303-307`, `rea-install-linux.sh:384-386`, `rea-install-linux.sh:252-254`
**Issue:**

- **Missing PATH line.** When an unsupported system Node exists (e.g. `/usr/bin/node` v18), the dry run's `install_node` prepends a `$STATE_DIR/node/bin` that does not exist. `command -v node` then still resolves to `/usr/bin/node`, so the dry run never prints the `export PATH="$STATE_DIR/node/bin:$PATH"` profile line that the real run writes.
- **Wrong `mv` source.** For archives with a top-level folder, the dry run prints `mv .staging-X X` instead of `mv .staging-X/X X`, because `[ -d "$staging/$2" ]` is always false in a dry run.

**Fix:** In dry-run `install_node`, add the profile line directly. In `unpack`, use `src="$staging/$2"` when `dry_run=true` (folded into the WR-01 fix).

### IN-02: CI action pinned by a mutable tag, and the jobs have no timeout

**File:** `.github/workflows/test.yml:9`, `.github/workflows/test.yml:14`
**Issue:** `actions/checkout@v7.0.1` exists (it resolves to `3d3c42e5…`), but a tag can be moved. Neither job sets `timeout-minutes`, so a check that hangs (a Docker pull, or a future prompt reading `/dev/tty`) uses the default 6-hour limit.
**Fix:** Pin `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` and add `timeout-minutes: 15` to each job.

### IN-03: Regression gaps in the new checks

**File:** `test.sh:151-166`, `test.sh:113`, `test.sh:296-297`
**Issue:**

- **FAIL-01 (Linux).** It covers only the `.tar.gz` path for an archive with a top-level folder. The flat-archive path (Rizin, Wakaru), the `.zip` path, the `mv` failure branch and the removal of `.staging-*` are never asserted.
- **TEST-03.** It has no rows for the odd majors 23 and 25, so a broken `major >= 22` gate would pass.
- **Windows UNIN-01.** It discards all output (`*> $null`), so unlike the bash UNIN-01 checks it never asserts that the "rea uninstall failed" warning was shown.

**Fix:**

- Add a flat-archive case and `[ ! -e "$tools/.staging-foo-1.0" ]` to FAIL-01.
- Add rows `23.0.0:1` and `25.0.0:1` to TEST-03.
- Capture the warning stream (`3>&1`) in the Windows driver and match on it.

### IN-04: Uninstall removes `~/.agents` without a ledger entry

**File:** `rea-install-linux.sh:569`
**Issue:** The new dry-run guard is correct. But the non-dry-run `rmdir "$HOME/.agents/skills" "$HOME/.agents"` removes these folders even if the user created them, empty, before installing. This is minor, because `rmdir` only removes empty folders, but it is outside the "uninstall removes only what the script added" contract.
**Fix:** At install time, record `dir:$HOME/.agents` only if the folder did not already exist, and remove it only when that ledger entry is present.

---

_Reviewed: 2026-10-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
