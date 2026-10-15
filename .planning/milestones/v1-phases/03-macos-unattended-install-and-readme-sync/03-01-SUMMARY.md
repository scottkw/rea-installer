---
phase: 03-macos-unattended-install-and-readme-sync
plan: 01
subsystem: installer
tags: [macos, linux, tty, homebrew, unattended, uninstall-prompts]
status: complete

requires:
  - phase: 02-consistent-java-handling
    provides: "test.sh sandbox harness (97 passed on macOS Bash 3.2, 63 in ubuntu:24.04 before this plan, per research baseline)"
provides:
  - "TTY_PATH internal constant and have_tty predicate in both bash scripts (test seam, D-11)"
  - "register_agents REA_BIN, byte-identical in both bash scripts: --yes plans setup --yes --all-detected, a terminal plans interactive setup, neither warns and continues (MAC-01, D-01)"
  - "confirm QUESTION ITEM, byte-identical in both bash scripts: no terminal answers no and warns 'leaving ITEM in place.' (D-02)"
  - "macOS install_homebrew: --yes runs sudo -v (with a terminal) then env NONINTERACTIVE=1; failed download or installer stops and records nothing (MAC-02, D-04..D-06)"
  - "test.sh MAC-01/02 section: 17 checks"
affects: [03-02, README Testing and Known limitations]

actuals:
  tokens: 4070
  tasks: 3
  commits: 6
plan_head_before: 9941577393a0b295ff699084e7a5ea52aba60926
plan_head_after: f8b25d4bf87303399fc42ca130d44d35cf94c45e

tech-stack:
  added: []
  patterns:
    - "Terminal access goes through TTY_PATH (assigned unconditionally) and have_tty; test.sh repoints TTY_PATH after sourcing to a missing path or a file holding y"
    - "Environment variables reach a command run through run via env NAME=VALUE, because run execs its arguments"

key-files:
  created: []
  modified:
    - rea-install-macos.sh
    - rea-install-linux.sh
    - test.sh

key-decisions:
  - "TTY_PATH is an internal constant assigned unconditionally, never read from the environment, so an inherited value cannot pre-answer an uninstall prompt (T-03-01)"
  - "register_agents and confirm are byte-identical in both bash scripts; Linux step 9 now calls register_agents too"
  - "install_homebrew downloads by plain assignment with || die and records homebrew only after the installer returned 0, which also fixes the old step 2 recording homebrew after a failed download"

patterns-established:
  - "Every confirm call passes ITEM as a second argument (set -u makes a missing $2 fatal)"

requirements-completed: [MAC-01, MAC-02]

coverage:
  - id: D1
    description: "macOS install without a terminal and without --yes skips rea setup with a warning and exits 0"
    requirement: "MAC-01"
    verification:
      - kind: test
        ref: "test.sh#MAC-01 macOS rea setup without a terminal warns and continues (+ with a terminal, under --yes)"
        status: pass
      - kind: other
        ref: "HOME=$(mktemp -d) /bin/bash ./rea-install-macos.sh install --dry-run --no-ghidra </dev/null (exit 0, warning, ==> Done.)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Uninstall prompts without a terminal answer no and name the item, identically on macOS and Linux; inherited TTY_PATH is ignored"
    requirement: "MAC-01"
    verification:
      - kind: test
        ref: "test.sh#MAC-01 confirm ... (rea-install-macos.sh, rea-install-linux.sh), MAC-01 an inherited TTY_PATH cannot pre-answer prompts, MAC-01 Linux rea setup without a terminal warns and continues"
        status: pass
      - kind: other
        ref: "Task 2 helper-identity diff command (prints 'helpers identical, seam and call sites ok')"
        status: pass
    human_judgment: false
  - id: D3
    description: "macOS --yes installs Homebrew with sudo -v then NONINTERACTIVE=1; without --yes nothing is forced; failures stop and record nothing"
    requirement: "MAC-02"
    verification:
      - kind: test
        ref: "test.sh#MAC-02 (5 checks)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Real Homebrew installer honours NONINTERACTIVE=1 and reuses the sudo -v ticket under curl | bash on a real Mac"
    requirement: "MAC-02"
    human_judgment: true
    rationale: "Research assumptions A1/A2; not verifiable without a real fresh Mac (VERI-01). The D-06 die catches a failure either way."

duration: 8 min
completed: 2026-10-15
---

# Phase 3 Plan 1: macOS Unattended Install Summary

**macOS install now finishes without a terminal (rea setup skipped with a warning), `--yes` installs Homebrew with `sudo -v` + `NONINTERACTIVE=1` and stops loudly without a ledger line on failure, and both bash scripts share identical `have_tty`/`confirm`/`register_agents` helpers driven by an internal `TTY_PATH` seam.**

## Performance

- Duration: about 8 min (start 2026-10-15T13:34:37Z)
- Tasks: 3 (each as a RED commit then a GREEN commit)
- Files modified: 3

## Accomplishments

- MAC-01: `register_agents` replaces step 9's inline branch in both scripts. Without `--yes` and without a terminal it prints `warning: no terminal available; run '<rea> setup' yourself.` and the install exits 0. Before, macOS stopped with `/dev/tty: Device not configured`.
- D-02: `confirm QUESTION ITEM` answers no without a terminal and prints `warning: no terminal available; leaving ITEM in place.`. Call sites pass the app path, `Homebrew`, `the Xcode Command Line Tools`, and `Hopper package <name>`.
- D-11: `TTY_PATH="/dev/tty"` is assigned unconditionally in both scripts. A `TTY_PATH` exported by the caller is overwritten when the script loads.
- MAC-02: `install_homebrew` (macOS step 2). Under `--yes`: `sudo -v` (only when a terminal opens), then `env NONINTERACTIVE=1 /bin/bash -c "$script"`. Without `--yes`: `/bin/bash -c "$script"`. A failed download gives `could not download the Homebrew installer.`. A failed installer gives the sudo hint. `record "homebrew"` runs only after the installer succeeds.
- The Xcode Command Line Tools step is unchanged (D-03).

## Task Commits

| Task | RED | GREEN |
|------|-----|-------|
| 1 (tracer) macOS rea setup without a terminal | 961eb91 Add failing checks for macOS rea setup without a terminal | fcc1b38 Skip rea setup with a warning when macOS has no terminal |
| 2 confirm without a terminal (both scripts) | 5b3af78 Add failing checks for uninstall prompts without a terminal | ec9816f Answer no with a warning when an uninstall prompt has no terminal |
| 3 Homebrew unattended / failure | 200a03d Add failing checks for unattended and failed macOS Homebrew installs | f8b25d4 Install Homebrew unattended under --yes and stop when it fails |

Commit messages follow the project's convention (`.claude/CLAUDE.md`: short imperative sentences, no prefix), which overrides the `test(...)`/`feat(...)` format, as in Phase 2.

## Red evidence

Every run used `/bin/bash ./test.sh` (Bash 3.2.57) from the executor shell, which has no controlling terminal. The harness is a custom bash PASS/FAIL harness, not TAP, JUnit, swift-testing or unittest, so `gsd_run check tdd-red-evidence` has no adapter for it. Semantic assessment was done by hand. Each FAIL below is the named target check failing on its planned assertion. None comes from a syntax error, a load error or an unrelated failure: all other checks passed in the same run.

Task 1 (before the macOS fix; `97 passed, 3 failed, 2 skipped`):
```
FAIL: MAC-01 macOS rea setup without a terminal warns and continues
    ./test.sh: line 41: register_agents: command not found
FAIL: MAC-01 macOS rea setup with a terminal runs it interactively
    ./test.sh: line 41: register_agents: command not found
FAIL: MAC-01 macOS rea setup under --yes registers every detected agent
    ./test.sh: line 41: register_agents: command not found
```
Assessment: these fail for the reason the plan gives (`register_agents` does not exist yet).

Task 2 (before the confirm fix; `103 passed, 6 failed, 2 skipped`):
```
FAIL: MAC-01 confirm without a terminal answers no and warns (rea-install-macos.sh)
    /Users/ken/dev/rea-installer/rea-install-macos.sh: line 56: /dev/tty: Device not configured
    no
FAIL: MAC-01 confirm with a terminal reads the answer (rea-install-macos.sh)
    /Users/ken/dev/rea-installer/rea-install-macos.sh: line 56: /dev/tty: Device not configured
    no
FAIL: MAC-01 confirm without a terminal answers no and warns (rea-install-linux.sh)
    /Users/ken/dev/rea-installer/rea-install-linux.sh: line 65: /dev/tty: Device not configured
    no
FAIL: MAC-01 confirm with a terminal reads the answer (rea-install-linux.sh)
    /Users/ken/dev/rea-installer/rea-install-linux.sh: line 65: /dev/tty: Device not configured
    no
FAIL: MAC-01 an inherited TTY_PATH cannot pre-answer prompts (rea-install-linux.sh)
    TTY_PATH=/var/folders/.../tty-yes
FAIL: MAC-01 Linux rea setup without a terminal warns and continues
    ./test.sh: line 41: register_agents: command not found
```
Assessment: the old confirm printed a raw `/dev/tty` error and no warning, which is the planned failure. Three checks already passed at RED, and that was expected:
- `confirm under --yes ...` (both scripts): the old confirm already returned 0 under `--yes`. These are regression guards.
- `inherited TTY_PATH ... (rea-install-macos.sh)`: Task 1 had already added the constant. The plan expected this.

Task 3 (before install_homebrew; `109 passed, 5 failed, 2 skipped`):
```
FAIL: MAC-02 macOS --yes installs Homebrew with NONINTERACTIVE=1 after sudo -v
FAIL: MAC-02 macOS --yes without a terminal skips sudo -v
FAIL: MAC-02 macOS Homebrew without --yes is not forced non-interactive
FAIL: MAC-02 macOS failed Homebrew install stops with a sudo hint and records nothing
FAIL: MAC-02 macOS failed Homebrew download stops and records nothing
    (each: ./test.sh: line 41: install_homebrew: command not found)
```
Assessment: these fail for the reason the plan gives (`install_homebrew` does not exist yet).

## End-to-end dry run (no terminal, temp HOME)

`HOME="$(mktemp -d)" /bin/bash ./rea-install-macos.sh install --dry-run --no-ghidra </dev/null` exits 0. Last 3 lines:
```
==> Running rea setup
warning: no terminal available; run '/opt/homebrew/bin/rea setup' yourself.
==> Done. Open a new terminal, restart your agent(s), then check health with: /opt/homebrew/bin/rea doctor
```

## Local test summary lines (final)

- `./test.sh` (default shell): `114 passed, 0 failed, 2 skipped`
- `/bin/bash ./test.sh` (Bash 3.2): `114 passed, 0 failed, 2 skipped`
- `docker run ... ubuntu:24.04 bash ./test.sh`: `80 passed, 0 failed, 12 skipped` (all 17 MAC-01/02 checks pass in the container)

## Deviations from Plan

**1. [Acceptance criterion wording] Task 3 grep `install/HEAD/install.sh)"` prints 1, not 0**
- Found during: Task 3 acceptance gate.
- Issue: the criterion was written to prove that step 2's inline `run /bin/bash -c "$(curl ...)"` is gone. The plain assignment that the plan itself requires (`script="$(curl -fsSL --proto '=https' https://.../install.sh)" ||`) contains the same substring, so the grep matches the new line.
- Resolution: no code change. `grep -nF '"$(curl' rea-install-macos.sh` shows that the only remaining inline `run ... "$(curl` is the uninstall-side Homebrew uninstaller line, which the plan says to leave unchanged. The intent of the criterion is met.

**2. [Tooling] BSD grep treats `$` inside a BRE pattern as an anchor**
- The criteria `grep -n 'register_agents "$rea_bin"'` and `grep -n 'leaving $2 in place.'` print nothing on macOS. Re-run with `grep -F`, each shows exactly one matching line per script. No code impact.

**Total deviations:** 0 code deviations. 2 acceptance-check wording issues, resolved by an equivalent check. **Impact:** none.

## Issues Encountered

None.

## Known Stubs

None.

## Threat Flags

None. All new surface is covered by T-03-01..T-03-07: T-03-01, T-03-02, T-03-05 and T-03-06 are mitigated and tested, and T-03-03, T-03-04 and T-03-07 are accepted.

## Next Phase Readiness

Ready for 03-02 (README sync). The README should describe: the no-terminal `rea setup` skip on macOS, uninstall prompts answering no without a terminal, and `--yes` installing Homebrew non-interactively after `sudo -v`. A real-Mac check of Homebrew's `NONINTERACTIVE`/`sudo -n` behaviour remains open (VERI-01).

## Self-Check: PASSED

- rea-install-macos.sh, rea-install-linux.sh, test.sh exist and are modified in commits fcc1b38, ec9816f, f8b25d4.
- Commits 961eb91, fcc1b38, 5b3af78, ec9816f, 200a03d, f8b25d4 are ancestors of HEAD.
