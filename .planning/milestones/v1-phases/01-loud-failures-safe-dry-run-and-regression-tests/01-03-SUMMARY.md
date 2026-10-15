---
phase: 01-loud-failures-safe-dry-run-and-regression-tests
plan: 03
subsystem: installer-linux
tags: [bash, linux, errexit, dry-run, uninstall, staging-extract]

requires:
  - phase: 01-02
    provides: "Red checks in test.sh for FAIL-01 Linux, FAIL-02, DRY-01, DRY-02, UNIN-01 Linux"
provides:
  - "Staging unpack in rea-install-linux.sh ($TOOLS_DIR/.staging-<name>, rename on success, archive kept on failure)"
  - "Rizin and Wakaru extracted through unpack"
  - "pkg_install returns 1 on a failed package-manager install; optional tools warn"
  - "Side-effect-free Linux dry runs on a fresh machine (install_node, install_jdk, /dev/tty probe, rmdir guard)"
  - "Linux uninstall that warns and continues when rea uninstall fails"
affects: [01-04, 01-05]

actuals:
  tokens: 2064
  tasks: 2
  commits: 2
plan_head_before: 2786a5eea33bf700ab9f99427c4644f5e6565a6a
plan_head_after: 2d952d5937ff815cb50581ce054ad043a387da1b

tech-stack:
  added: []
  patterns:
    - "Archive extracts go to $TOOLS_DIR/.staging-<name> and are mv'd to the target only on success; an archive with no top-level folder becomes the target itself"
    - "Functions called in $(...), f || x, or if-conditions check each step explicitly (|| exit 1 / || return 1 / || die)"
    - "Terminal availability is probed by opening /dev/tty in a subshell, not by testing readability"

key-files:
  created: []
  modified:
    - rea-install-linux.sh

key-decisions:
  - "unpack uses tar -xf (auto-detects gzip and xz) so Rizin .tar.xz and Wakaru .tar.gz share the one staging path"
  - "On an extract failure the verified archive is kept, so a rerun extracts again without downloading"
  - "install_node returns early under --dry-run, because a dry run cannot fetch SHASUMS256.txt when curl was only printed"

patterns-established:
  - "Optional tool failure: pkg_install X || warn \"X could not be installed; skipping it.\""

requirements-completed: [FAIL-01, FAIL-02, DRY-01, DRY-02, UNIN-01]

coverage:
  - id: D1
    description: "Failed Linux extract stops with 'could not unpack', leaves no tool or staging folder, keeps the archive, and the rerun extracts"
    requirement: "FAIL-01"
    verification:
      - kind: integration
        ref: "./test.sh#FAIL-01 Linux failed unpack stops and leaves no tool folder (Mac bash 3.2 and ubuntu:24.04)"
        status: pass
      - kind: integration
        ref: "./test.sh#FAIL-01 Linux rerun extracts again (Mac bash 3.2 and ubuntu:24.04)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Failed package install stops with 'X is required.' and writes no pkg: ledger line; optional tools warn"
    requirement: "FAIL-02"
    verification:
      - kind: integration
        ref: "./test.sh#FAIL-02 failed package install stops and is not recorded (Mac and ubuntu:24.04)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Linux install --dry-run (with --with-android, and with every optional flag) exits 0 in a fresh no-network ubuntu:24.04"
    requirement: "DRY-01"
    verification:
      - kind: e2e
        ref: "./test.sh#DRY-01 Linux install --dry-run --with-android in fresh ubuntu:24.04"
        status: pass
      - kind: e2e
        ref: "docker run --network none ubuntu:24.04 install --dry-run --with-android --with-extras --with-linux-tools (exit 0, prints npm install --global)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Linux uninstall --dry-run leaves the home folder snapshot unchanged"
    requirement: "DRY-02"
    verification:
      - kind: e2e
        ref: "./test.sh#DRY-02 Linux uninstall --dry-run changes nothing"
        status: pass
    human_judgment: false
  - id: D5
    description: "Linux uninstall with a failing rea warns and still removes the profile block and ~/.rea-installer"
    requirement: "UNIN-01"
    verification:
      - kind: integration
        ref: "docker ubuntu:24.04 ./test.sh#UNIN-01 Linux uninstall survives a failing rea"
        status: pass
    human_judgment: false

duration: 2min
completed: 2026-10-14
status: complete
---

# Phase 1 Plan 03: Linux loud failures, safe dry run and uninstall fixes Summary

**The Linux installer now extracts every archive through a staging folder and stops on a failed extract or package install. Its dry runs change nothing on a fresh no-network machine, and uninstall finishes when `rea uninstall` fails. All five Linux red checks from 01-02 now pass on this Mac (bash 3.2, bsdtar) and in ubuntu:24.04 (bash 5, GNU tar).**

## Performance

- **Duration:** about 2 min of edit and verify time (2026-10-14T16:36:00Z to 16:37:57Z; reading the context came before that)
- **Tasks:** 2 of 2
- **Files modified:** 1 (rea-install-linux.sh)

## Accomplishments

- `unpack` was rewritten following RESEARCH Code Example 3. It extracts into `$TOOLS_DIR/.staging-<name>` and moves the result into place only on success. On a failed extract it removes staging, keeps the verified archive and dies with `could not unpack <archive>.` A checksum `die` inside `fetch` now stops the run (`|| exit 1`).
- Rizin and Wakaru use `unpack`, which replaces the inline `mkdir` + `tar -xJf/-xzf` blocks and their truncated-executable rerun guards. A scratch run on bash 3.2 with flat `.tar.xz` and `.tar.gz` archives checked the "no top-level folder" layout.
- `pkg_install` has `|| return 1` on the apt-get, dnf and pacman arms, so a failed package never reaches `record "pkg:..."`. adb, binutils, tshark, sigrok-cli and gdb now warn `<tool> could not be installed; skipping it.` instead of failing silently with `|| true`. `make_venv` checks both `unpack` calls.
- Dry run: `install_node` only logs `Would download Node.js 24 ...` and returns. `install_jdk` only logs `Would download Temurin 21 ...` when the JDK folder is missing. The old Node folder is removed through `run`. The `/dev/tty` check is now `(: </dev/tty) 2>/dev/null`. The `~/.agents` rmdir is guarded by dry run.
- Uninstall: `run "$rea_bin" uninstall --purge-data || warn "rea uninstall failed; remove agent registrations by hand."`. Nothing extra is deleted to make up for the failure.

## Task Commits

1. **Task 1: Loud stop and clean rerun on failed extract or package install** - `f4abeab`
2. **Task 2: Side-effect-free dry runs and uninstall that survives a broken rea** - `2d952d5`

## Verification evidence

- Red first: `./test.sh` before any edit printed FAIL for FAIL-01 Linux (both checks), FAIL-02, DRY-01 and DRY-02 on the Mac. The ubuntu:24.04 run after Task 1 still printed FAIL for UNIN-01 Linux.
- Task 1 `<verify>` (Mac): all five named checks PASS, including TEST-01 shellcheck and bash -n. Task 1 `<verify>` (ubuntu:24.04): FAIL-01 Linux x2, FAIL-02 and TEST-02 Linux all PASS.
- Task 2 `<verify>`: DRY-01 and DRY-02 PASS on the Mac (Docker). UNIN-01 Linux PASS in ubuntu:24.04. The `--network none` dry run with `--with-android --with-extras --with-linux-tools` exits 0 and prints the npm install plan.
- Still FAIL: FAIL-03, UNIN-01 macOS, FAIL-01 Windows x2 and UNIN-01 Windows. All of these belong to plan 01-04 (macOS/Windows), as the plan expects. `./test.sh` as a whole still exits 1 until 01-04 is done.
- All acceptance-criteria greps pass. `sed -n '2,15p'` (the header and usage range) is unchanged, and shellcheck and bash -n are clean.

## Decisions Made

Followed the plan and RESEARCH Code Examples 3 and 4 as written. See key-decisions above.

## Deviations from Plan

None. The plan was executed as written.

Note on one acceptance criterion: `grep -c 'Using JDK at $JAVA_HOME' rea-install-linux.sh` prints 0 with macOS BSD grep, which reads the `$` in the middle of the pattern as an anchor. It prints 1 with GNU grep (checked in ubuntu:24.04) and with `grep -cF`. The reuse branch (line 321) is unchanged, so the criterion is met. Plan 01-05 or the verifier should use `grep -F` for this check on a Mac.

## Issues Encountered

None.

## User Setup Required

None. No external service configuration is required.

## Next Phase Readiness

Ready for 01-04 (macOS and Windows fixes). Once 01-04 is done, plan 01-05 runs the phase gate (`./test.sh` exit 0 on the Mac and in ubuntu:24.04) and adds CI.

## Self-Check: PASSED

- rea-install-linux.sh modified; commits f4abeab and 2d952d5 are ancestors of HEAD; `git rev-list --count 2786a5e..HEAD` = 2.
