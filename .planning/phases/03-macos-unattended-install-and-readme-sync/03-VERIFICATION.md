---
phase: 03-macos-unattended-install-and-readme-sync
verified: 2026-10-15T14:08:19Z
status: gaps_found
score: 18/20 must-haves verified
covered_files:
  - .planning/phases/03-macos-unattended-install-and-readme-sync/03-01-PLAN.md
  - .planning/phases/03-macos-unattended-install-and-readme-sync/03-01-SUMMARY.md
  - .planning/phases/03-macos-unattended-install-and-readme-sync/03-02-PLAN.md
  - .planning/phases/03-macos-unattended-install-and-readme-sync/03-02-SUMMARY.md
  - README.md
  - rea-install-linux.sh
  - rea-install-macos.sh
  - test.sh
covered_digest: "v3:sha256:ff0b70936b5fefbc02dcb9ccac7527da9d78ad55d0939bd4a9e5e7939e5af63a"
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "An unattended `install --yes` on a Mac without Homebrew leaves a working REA: in the new terminal the script tells the user to open, `brew`, `node` and the printed `<rea_bin> doctor` health check run (derived from the phase goal 'completes unattended' and the core value 'never leave the machine silently broken'; review CR-01)"
    status: failed
    reason: "On Apple silicon, Homebrew installed by install_homebrew lives in /opt/homebrew/bin, which is not on macOS's default PATH (/etc/paths and /etc/paths.d on this Mac confirm it). Homebrew's install.sh only prints a 'Next steps' instruction to add `eval \"$(/opt/homebrew/bin/brew shellenv)\"` to ~/.zprofile (install.sh ~1167-1181, fetched and read as data); under NONINTERACTIVE that text is buried in the run. load_brew fixes PATH only for the current process. The macOS profile block (write_profile) carries only JAVA_HOME, REA_OBJDUMP_COMMAND and REA_WABT_BIN_DIRECTORY; unlike Linux (rea-install-linux.sh:457, :543) it never adds a PATH entry. So the run prints 'Done. Open a new terminal ... check health with: /opt/homebrew/bin/rea doctor' (rea-install-macos.sh:376), and in that new terminal node (a Homebrew formula on a fresh Mac) is not on PATH, so the npm launcher's `#!/usr/bin/env node` fails, as do brew and ghidraRun. The run completes; the install it produces is not usable. Pre-existing before this phase (the old step 2 had the same gap), but this phase makes the fresh-Mac --yes flow a supported path, so the goal's outcome is not met on the default Mac hardware. Intel Macs are unaffected (/usr/local/bin is on the default PATH)."
    artifacts:
      - path: "rea-install-macos.sh"
        issue: "install_homebrew (232-250) records homebrew but never queues Homebrew's shellenv into profile_exports; write_profile (252-294) writes no PATH entry"
      - path: "README.md"
        issue: "Known limitations does not mention that a script-installed Homebrew on Apple silicon is not on PATH in new terminals"
    missing:
      - "When this run installed Homebrew, add `eval \"$(<prefix>/bin/brew shellenv)\"` to the profile block (removed with the block on uninstall), or otherwise put the Homebrew prefix on PATH for new shells"
      - "Decide what happens to that line if the user declines Homebrew removal at uninstall (removing the block takes brew off PATH again): keep it outside the block or warn"
      - "A test.sh check that a dry run of do_install's profile step with a this-run Homebrew plans the shellenv line"
      - "If the fix is deferred instead, a Known limitations bullet telling Apple-silicon users to add Homebrew's shellenv line themselves"
prohibitions_flagged:
  - statement: "MUST NOT force Homebrew's installer into non-interactive mode without --yes (03-01, test tier)"
    status: unverified
    flagged: true
    note: "The test only checks that the printed command has no NONINTERACTIVE. Under `curl ... | bash` without --yes the child installer inherits the pipe as stdin, and Homebrew's install.sh (lines 129-141) then sets NONINTERACTIVE=1 itself. The script does not set the variable, but its stdin choice forces the mode (review WR-04). Documented in README Known limitations. Non-authoritative judgment: holds for the script's own setting, not for the effect."
  - statement: "MUST NOT state or imply that the macOS or Windows script has been installed on a real machine (03-02, test tier)"
    status: unverified
    flagged: true
    note: "No test.sh check enforces it. Non-authoritative judgment: holds. README:30-31 say 'Dry runs and test.sh only: no real install has been run yet' / 'never run on real Windows'; the callout at README:235 lists what has not been run on a real machine."
  - statement: "MUST NOT describe a hosted CI service as running the tests (03-02, test tier)"
    status: unverified
    flagged: true
    note: "No test.sh check enforces it. Non-authoritative judgment: holds. 'GitHub Actions' appears 0 times; README:213 says 'nothing runs in hosted CI'."
  - statement: "MUST NOT state as fact that REA finds Ghidra on macOS without GHIDRA_INSTALL_DIR (03-02, test tier)"
    status: unverified
    flagged: true
    note: "No test.sh check enforces it. Non-authoritative judgment: holds. GHIDRA_INSTALL_DIR appears 0 times in README.md and no sentence makes the claim."
coincidental_reliance_items:
  - truth: "macOS install without a terminal prints the rea setup warning and finishes (SC1)"
    reason: undeclared-precondition
    harden: "The end-to-end evidence (HOME=temp, </dev/null, --dry-run --no-ghidra, exit 0) ran on a Mac that already has Homebrew, the Command Line Tools and Node, so steps 1-3 were skipped. On a Mac without Homebrew and without a terminal the run stops at Homebrew unless sudo is passwordless (and a dry run without Homebrew stops at step 3's `brew --prefix`). Both preconditions are documented in README Known limitations; state them in the success criterion too so 'without a terminal' is not read as 'on any Mac'."
human_verification:
  - test: "On a real Mac (Apple silicon) with the Command Line Tools but no Homebrew, run `./rea-install-macos.sh install --yes --no-ghidra` from Terminal, then open a new terminal and run the printed `rea doctor` command"
    expected: "sudo asks for the password once, Homebrew installs with no Return prompt, the run ends with 'Done.', and in the new terminal `rea doctor` runs (currently expected to fail with `env: node: No such file or directory` per the CR-01 gap)"
    why_human: "test.sh only checks the dry-run plan with stubbed curl; Homebrew's real NONINTERACTIVE/sudo -n behavior and the new-terminal PATH need a real fresh Mac (tracked as v2 VERI-01)"
  - test: "Read README Options (line 133), Uninstalling step 5 (line 149), How the scripts were engineered 'Fail loudly' (line 189) and Known limitations 'Unattended macOS install' (line 258) side by side"
    expected: "All four describe no-terminal behavior the same way: rea setup skipped with a warning, uninstall prompts answered no (kept items named)"
    why_human: "03-02 marks this truth `verification: backstop`; reading prose is presence, not explicit evidence. Verifier's non-authoritative reading: consistent."
  - test: "Decide each flagged prohibition above (4 items)"
    expected: "Accept or reject the verifier's non-authoritative judgment; for the NONINTERACTIVE item, decide whether WR-04's `<\"$TTY_PATH\"` redirect is required"
    why_human: "Test-tier prohibitions with no wired test.sh enforcement are never auto-passed"
---

# Phase 3: macOS Unattended Install and README Sync Verification Report

**Phase Goal:** The macOS installer completes unattended (no terminal, or `--yes` on a Mac without Homebrew), and the README's Status, Testing and Known limitations sections accurately describe every fix and the new test harness, including how to run it locally
**Verified:** 2026-10-15T14:08:19Z
**Status:** gaps_found
**Re-verification:** No, initial verification

## Goal Achievement

The code delivers everything the success criteria literally ask for, and I confirmed it by running it myself. The unattended run reaches "Done." But on an Apple-silicon Mac without Homebrew, the install it leaves behind does not work in the next terminal (CR-01, confirmed independently). "Completes unattended" on a Mac without Homebrew is the phase's headline scenario, so I count this as a goal gap and not just a review nit. It is pre-existing and sits outside the literal SC text, so there is an override template below if you decide it is out of scope.

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | SC1: macOS `install` without a terminal prints a warning to run `rea setup` manually instead of failing | ✓ VERIFIED (coincidental-reliance) | Ran `HOME=$(mktemp -d) /bin/bash ./rea-install-macos.sh install --dry-run --no-ghidra </dev/null` from a shell with no tty (`tty` = "not a tty"): exit 0, last lines `warning: no terminal available; run '/opt/homebrew/bin/rea setup' yourself.` then `==> Done.`. The `register_agents` warn branch (rea-install-macos.sh:296-306) does not depend on dry_run. test.sh "MAC-01 macOS rea setup without a terminal warns and continues" PASS. Reliance: this Mac already has Homebrew/CLT/Node (see coincidental_reliance_items) |
| 2 | SC2: macOS `install --yes` on a Mac without Homebrew runs the Homebrew installer non-interactively and never waits for Return | ✓ VERIFIED | `install_homebrew` (232-250): under `assume_yes`, `run sudo -v` only when `have_tty`, then `run env NONINTERACTIVE=1 /bin/bash -c "$script"`. Wired at step 2 `if ! load_brew; then install_homebrew; fi`. Homebrew's install.sh (read as data) skips its Return prompt when NONINTERACTIVE is set. test.sh MAC-02 "--yes installs Homebrew with NONINTERACTIVE=1 after sudo -v" (asserts the order) and "--yes without a terminal skips sudo -v" PASS. A real-Mac check stays a human item (VERI-01) |
| 3 | SC3: README Status, Testing and Known limitations list the milestone's fixes, describe running `./test.sh` locally on macOS and in a Linux container, and still say macOS/Windows are dry run + lint only | ✓ VERIFIED | Status README:27-31; Testing table 195-199 names the checks per platform; `### Running the tests` README:211 has both commands; I ran both verbatim: `/bin/bash ./test.sh` gave 114 passed, 0 failed, 2 skipped, and the ubuntu:24.04 docker run gave 80 passed, 0 failed, 12 skipped. Fix coverage across README: FAIL-01 (staging, 172), FAIL-02/03 (184), DRY-01/02 (186, 221), JAVA-01..04 (159, 178-180, 260-261), UNIN-01 (Uninstalling step 1), MAC-01/02 (Options, step 5, 185-187, 256). Accuracy caveats are listed under warnings below |
| 4 | `register_agents` byte-identical in both scripts: --yes plans `setup --yes --all-detected`; a terminal plans `setup <TTY_PATH`; neither warns, returns 0, plans nothing | ✓ VERIFIED | awk-extracted function bodies diff clean; Linux step 9 calls it (linux:562). MAC-01 macOS (3 checks) and Linux no-terminal check PASS |
| 5 | `confirm` byte-identical: no --yes and no terminal returns 1 and warns `leaving <ITEM> in place.` with no raw /dev/tty error; --yes returns 0 first; a terminal reads the answer | ✓ VERIFIED | diff clean; 3 confirm checks x 2 scripts PASS (the no-terminal check asserts no `Device not configured` and no `/dev/tty`) |
| 6 | Every confirm call site passes ITEM | ✓ VERIFIED | macOS: `"$line"` (app), `"Homebrew"`, `"the Xcode Command Line Tools"`; Linux:610 `"Hopper package $line"`. No other callers |
| 7 | An inherited TTY_PATH is overwritten on load | ✓ VERIFIED | `TTY_PATH="/dev/tty"` set unconditionally (macos:25, linux:26); "inherited TTY_PATH cannot pre-answer prompts" PASS on both scripts |
| 8 | install_homebrew: a failed download stops with `could not download the Homebrew installer.`; a failed installer stops with the sudo hint; neither records `homebrew` | ✓ VERIFIED | Plain assignment `script="$(curl ...)" \|\| die` (236-237); `\|\| die "$hint"` before `record "homebrew"` (248). Two MAC-02 failure checks PASS and assert there is no ledger line |
| 9 | Without --yes: `/bin/bash -c` with no NONINTERACTIVE and no `sudo -v` | ✓ VERIFIED | Line 246; MAC-02 "not forced non-interactive" PASS (checks the printed command only; see the flagged prohibition / WR-04) |
| 10 | Xcode CLT step unchanged, still stops with `finish the Command Line Tools installer dialog` | ✓ VERIFIED | do_install step 1 matches pre-phase commit 9941577 |
| 11 | `/bin/bash ./test.sh` and the ubuntu:24.04 run report 0 failed | ✓ VERIFIED | Run once each by the verifier: 114/0/2 and 80/0/12; the container ran all 17 MAC-01/02 checks |
| 12 | README `### Running the tests` with the two exact commands that report 0 failed | ✓ VERIFIED | README:211-219; both executed verbatim (see #11) |
| 13 | Running the tests states the SKIP rule and `CI=true` | ✓ VERIFIED | README:231, including the Mac-specific always-SKIP for docker/shellcheck, which matches test.sh `need()` |
| 14 | Testing table macOS/Windows rows name test.sh and what it checks | ✓ VERIFIED | README:197-198 |
| 15 | Status keeps macOS/Windows unverified ("Dry runs and `test.sh` only:", no real install) | ✓ VERIFIED | README:30-31 |
| 16 | Status Linux row says the end-to-end runs came before the current fixes | ✓ VERIFIED | README:29, plus the paragraph at 209 |
| 17 | Uninstalling keeps six steps in do_uninstall order; step 1 says a failed rea uninstall warns, step 5 says no-terminal keeps the item | ✓ VERIFIED | README:141-151 match do_uninstall order (rea uninstall, npm, profile, packages, Homebrew/CLT/Hopper prompts, rm STATE_DIR). Caveat WR-08 below |
| 18 | How the scripts were engineered describes the milestone's behavior | ✓ VERIFIED | README:159, 172, 176-181, 182-187. Caveat IN-03 below |
| 19 | Known limitations holds the six D-10 items plus the accepted Java limitations | ✓ VERIFIED | D-10's six items: README:259 (pinned layout), 260 (Rizin/Wakaru), 261 (partial installs), 262 (Windows JAVA_HOME), 256 (unattended macOS prerequisites), 257 (dry run without Node). Java: 263. Spot-checked 257 against code: step 8 `$(npm prefix --global)` and step 3 `$(brew --prefix)` do stop the run |
| 20 | Goal-derived: an unattended `--yes` install on a Mac without Homebrew leaves a working REA in the new terminal the script tells the user to open | ✗ FAILED | CR-01, confirmed: /etc/paths has no /opt/homebrew/bin (this Mac is arm64); the macOS profile block has no PATH/shellenv line; Homebrew's installer only prints the instruction. See gaps |
| - | 03-02 backstop: Options, Uninstalling, Engineered and Known limitations describe no-terminal behavior the same way | ⚠️ insufficient_spec | `verification: backstop`, so abstained. Non-authoritative reading: consistent. Routed to human verification. Not counted |

**Score:** 18/20 truths verified (0 present, behavior-unverified; 1 insufficient_spec backstop excluded; 1 failed)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `rea-install-macos.sh` | TTY_PATH, have_tty, two-arg confirm, register_agents, install_homebrew | ✓ VERIFIED | verify.artifacts passed; all symbols present and called from do_install / do_uninstall |
| `rea-install-linux.sh` | TTY_PATH, have_tty, confirm and register_agents identical to macOS | ✓ VERIFIED | Bodies diff clean; `register_agents "$rea_bin"` at :562 |
| `test.sh` | MAC-01/02 section | ✓ VERIFIED | 17 checks, all PASS on Bash 3.2 and in ubuntu:24.04 |
| `README.md` | Status, Options, Uninstalling, Engineered, Testing + Running the tests, Known limitations | ✓ VERIFIED | `### Running the tests` at :211 |

### Key Link Verification

`verify.key-links` could not parse these links (the `from:` fields are descriptions, not paths, so it exited 1). I checked them by hand:

| From | To | Via | Status | Details |
|---|---|---|---|---|
| do_install step 9 (both) | register_agents | `register_agents "$rea_bin"` | WIRED | macOS step 9, Linux :562; the Hopper before/after lines stay in do_install |
| macOS do_install step 2 | install_homebrew | `if ! load_brew; then install_homebrew; fi` | WIRED | Present verbatim |
| confirm / register_agents | have_tty / TTY_PATH | `<"$TTY_PATH"` | WIRED | macOS :51, :61, :303; the only terminal reads in either script |
| install_homebrew | record homebrew | after the installer returns 0 | WIRED | `\|\| die` on 244/246 precedes 248 |
| README Running the tests | test.sh | commands run verbatim | WIRED | Both executed by the verifier, 0 failed |
| README Known limitations | cited code | wording checked against code | WIRED | Spot-checked the dry-run-without-Node and unattended bullets against the code |

### Data-Flow Trace (Level 4)

Not applicable. These are installer scripts with no rendered dynamic data. The equivalent check is the ledger write (`record "homebrew"`), traced in the key links above.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| No-terminal install finishes | `HOME=$(mktemp -d) /bin/bash ./rea-install-macos.sh install --dry-run --no-ghidra </dev/null` | exit 0, warning + Done | ✓ PASS |
| Full harness, Bash 3.2 | `/bin/bash ./test.sh` (run once) | 114 passed, 0 failed, 2 skipped | ✓ PASS |
| Full harness, Linux | documented `docker run ... ubuntu:24.04 bash ./test.sh` (run once) | 80 passed, 0 failed, 12 skipped | ✓ PASS |
| Commits exist | `verify.commits` on 9 hashes | all valid | ✓ PASS |
| WR-08 shell semantics | `/bin/bash -c 'set -euo pipefail; ... [ -n "$b" ] && a="$(false)/bin/rea"'` | exits 1 before the next line | Confirms WR-08 |
| WR-07 shell semantics | `/bin/bash -c 'set -euo pipefail; /bin/bash -c "$(false)"; echo after'` | prints `after`, rc 0 | Confirms WR-07 |

### Probe Execution

No `scripts/*/tests/probe-*.sh` exist and neither plan declares a probe. Step 7c: not applicable.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| MAC-01 | 03-01 | macOS install without a terminal warns to run `rea setup` manually instead of failing | ✓ SATISFIED | Truths 1, 4-7 |
| MAC-02 | 03-01 | macOS `install --yes` on a Mac without Homebrew installs Homebrew without waiting for Return | ✓ SATISFIED (literal) | Truths 2, 8, 9. The resulting install is unusable on Apple silicon: gap #20 |
| DOCS-01 | 03-02 | README Status, Testing and Known limitations reflect every fix, the harness and how to run it | ✓ SATISFIED | Truths 3, 12-19; accuracy warnings below |

No orphaned requirements: REQUIREMENTS.md maps only MAC-01, MAC-02 and DOCS-01 to Phase 3, and all three are claimed by a plan.

### Anti-Patterns Found

No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER markers in the four modified files. No Bash 4+ constructs in rea-install-macos.sh (`mapfile`, `readarray`, `declare -A`, case modification, `|&`, `&>>`, `coproc` were all grepped).

The review findings, as I judge them independently against the goal:

| Finding | File:Line | Severity (verifier) | Impact on goal |
|---|---|---|---|
| CR-01 Homebrew never on PATH in new terminals (Apple silicon) | rea-install-macos.sh:232-294, :376 | 🛑 Blocker | Gap #20. The unattended fresh-Mac install ends "Done." with no working brew/node/rea in the next terminal. Confirmed from /etc/paths and Homebrew's install.sh |
| WR-01 `sudo -v` stops Homebrew's `sudo -k` exit trap, so a cached root ticket stays live while unpinned npm/brew/rea-setup code runs | :241 | ⚠️ Warning (security, introduced this phase) | Does not stop completion. Confirmed: install.sh sets `trap 'sudo -k' EXIT` only when `sudo -n -v` fails first (~line 329-331). Should be fixed before ship |
| WR-02 Partial Homebrew install orphaned, adopted on rerun | :244-249 | ⚠️ Warning | Rerun "recovers" but uninstall never offers to remove that Homebrew |
| WR-03 No-terminal uninstall keeps items but deletes the ledger that tracks them | :449, linux:637 | ⚠️ Warning | README step 5 + step 6 are literally accurate, but the "leaving X in place" warning implies a later retry that is impossible |
| WR-04 `curl \| bash` without --yes: the installer inherits pipe stdin and goes non-interactive | :246 | ⚠️ Warning | Outside the goal's two scenarios. Stops loudly; documented in Known limitations; Quick start uses `./rea-install-macos.sh`, not curl. Makes a test-tier prohibition flag (see frontmatter) |
| WR-05 Sudo hint shown for every Homebrew failure; inherited INTERACTIVE aborts the --yes path | :233, :244 | ⚠️ Warning | Confirmed: install.sh:31-33 aborts when both variables are set. Misleading guidance, not silent |
| WR-06 Dry run downloads install.sh (dies offline) and prints all ~35 KB of it as the plan | :236-246 | ⚠️ Warning | Changes nothing on disk, so the dry-run safety constraint holds; the plan output is unreadable |
| WR-07 Homebrew uninstall: a failed curl runs an empty script (rc 0) and the ledger is deleted; --yes does not answer Homebrew's own prompt | :442 | ⚠️ Warning | Pre-existing, uninstall side; reproduced. Also makes README Options "accepts uninstall prompts" incomplete |
| WR-08 macOS uninstall exits silently when the recorded npm cannot run | :391 | ⚠️ Warning (DOCS accuracy) | Reproduced. README:143 "If it fails, or the rea CLI is broken, uninstall warns and carries on" does not cover a broken npm on macOS |
| IN-01 Test gaps (rc not checked in "confirm with a terminal"; no end-to-end no-terminal uninstall) | test.sh | ℹ️ Info | |
| IN-02 `confirm` without `$2` crashes under `set -u` | :57 | ℹ️ Info | All current callers pass ITEM |
| IN-03 README says Ghidra always "installs and records" openjdk@21 | README:163 | ℹ️ Info (DOCS accuracy) | `brew_install` skips and does not record a formula that is already installed |

### Human Verification Required

1. **Real fresh-Mac unattended install.** On an Apple-silicon Mac with the CLT but no Homebrew, run `install --yes --no-ghidra`, then open a new terminal and run the printed `rea doctor`. Expected: one sudo prompt, no Return prompt, "Done.", and a working `rea doctor` (currently expected to fail, per gap #20). This is v2 VERI-01.
2. **No-terminal wording consistency (backstop truth).** Compare README Options, Uninstalling step 5, Engineered "Fail loudly" and Known limitations "Unattended macOS install". The verifier's reading is that they are consistent.
3. **Four flagged test-tier prohibitions** (frontmatter `prohibitions_flagged`). None has test.sh enforcement, so none is auto-passed. Three README items hold on inspection. The NONINTERACTIVE item holds for the script's own setting but not under `curl | bash` (WR-04).

### Gaps Summary

There is one blocker, and it has one root cause: when the script installs Homebrew on Apple silicon, it never puts Homebrew on PATH for future shells. The run itself finishes unattended exactly as SC1 and SC2 require. But the macOS profile block, unlike Linux's, carries no PATH entry, and Homebrew's installer only prints the shellenv instruction (buried under NONINTERACTIVE). So the "Done. Open a new terminal ... rea doctor" message points the user at a command that fails. That is a silently broken install on the phase's headline scenario. The defect predates this phase. The phase is what made the scenario supported, which is why I count it against the goal.

If you decide the goal means only that the run finishes without input, and new-shell PATH is out of scope, accept the deviation with:

```yaml
overrides:
  - must_have: "An unattended `install --yes` on a Mac without Homebrew leaves a working REA: in the new terminal the script tells the user to open, `brew`, `node` and the printed `<rea_bin> doctor` health check run"
    reason: "Pre-existing; Phase 3 SCs cover completion of the run only. New-shell PATH for a script-installed Homebrew deferred to <phase/backlog>, with a Known limitations bullet"
    accepted_by: "<name>"
    accepted_at: "<ISO timestamp>"
```

Even with the override, a Known limitations bullet is still needed, or DOCS-01's "accurately describe" is weakened. WR-01, a security regression this phase introduced, should also be fixed before `/gsd-ship`, even though it does not block the goal.

---

_Verified: 2026-10-15T14:08:19Z_
_Verifier: Claude (gsd-verifier)_
