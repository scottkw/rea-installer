---
phase: 01-loud-failures-safe-dry-run-and-regression-tests
plan: 02
subsystem: testing
tags: [bash, pwsh, docker, regression-tests, red-evidence]

requires:
  - phase: 01-01
    provides: "test.sh harness (ok/bad/skip, need, stub, sandbox, fresh_home) and the source guard"
provides:
  - "Red checks in test.sh for FAIL-01 (Linux, Windows), FAIL-02, FAIL-03, UNIN-01 (Linux, macOS, Windows), DRY-01, DRY-02"
  - "STUB_TAR-controlled tar stub shared by the bash and pwsh checks"
  - "Runtime-generated pwsh driver ($work/w.ps1) that dot-sources rea-install-windows.ps1"
  - "01-RED.log: red evidence from this Mac (bash 3.2, Docker, pwsh) plus an ubuntu:24.04 run"
affects: [01-03, 01-04, 01-05]

actuals:
  tokens: 4357
  tasks: 3
  commits: 3
plan_head_before: 557262c8bb1174df5e4af62e2901b4cca9b987e8
plan_head_after: 3aa4a0e9da856e85be0ece40bc65c98e306bc689

tech-stack:
  added: []
  patterns:
    - "One tar stub switched by the STUB_TAR env var: fail = partial foo-1.0 in the -C folder then exit 1, otherwise exec /usr/bin/tar"
    - "show() prints $work/out indented after a FAIL, so the red log carries the reason"
    - "stub_path computed once at the top and used by sandbox and the pwsh run (keeps shellcheck clean without SC2030/2031 disables)"
    - "pwsh driver prints PASS:/FAIL: lines; test.sh feeds them to ok/bad and fails 'Windows checks (pwsh driver produced no results)' when none appear"

key-files:
  created:
    - .planning/phases/01-loud-failures-safe-dry-run-and-regression-tests/01-RED.log
  modified:
    - test.sh

key-decisions:
  - "Check names are the output contract from the plan, used verbatim (plans 01-03 and 01-04 grep them)"
  - "UNIN-01 profile check compares bytes with cmp against 'keep me\\n' rather than $(cat), which would drop the trailing newline"
  - "pwsh runs with HOME=$work/pwsh-home as well as overridden $StateDir/$ToolsDir, the same temp-HOME pattern as the TEST-01 parse check"
  - "The docker CLI keeps the real HOME (it reads ~/.docker for its context); only the container sees a fresh home"

patterns-established:
  - "Red-before-fix: 01-RED.log committed alone, before any commit that touches an installer"

requirements-completed: [TEST-04, TEST-05]

coverage:
  - id: D1
    description: "Bash red checks FAIL-01 Linux (failure + rerun), FAIL-02, FAIL-03, UNIN-01 Linux/macOS"
    requirement: "TEST-05"
    verification:
      - kind: command
        ref: "./test.sh (Darwin) and docker run ubuntu:24.04 bash ./test.sh: FAIL lines as listed in 01-RED.log"
        status: pass
    human_judgment: false
  - id: D2
    description: "DRY-01 / DRY-02 fresh-container dry-run checks (--network none, repo :ro)"
    requirement: "TEST-04"
    verification:
      - kind: command
        ref: "./test.sh#DRY-01 shows 'curl: command not found'; #DRY-02 shows 'dry run changed the home folder'"
        status: pass
    human_judgment: false
  - id: D3
    description: "Windows checks through the pwsh driver (FAIL-01 Windows x2, UNIN-01 Windows)"
    requirement: "TEST-05"
    verification:
      - kind: command
        ref: "./test.sh#FAIL-01 Windows / UNIN-01 Windows"
        status: pass
    human_judgment: false
  - id: D4
    description: "01-RED.log committed alone before any fix"
    requirement: "TEST-05"
    verification:
      - kind: command
        ref: "git show --name-only --format= 3aa4a0e == 01-RED.log"
        status: pass
    human_judgment: false

duration: 3min
completed: 2026-10-14
status: complete
---

# Phase 1 Plan 02: Red regression checks and 01-RED.log Summary

**test.sh now checks failed extracts, failed package and brew installs, uninstall with a broken `rea` on all three platforms, and fresh-container dry runs. All of these fail against the unfixed installers, and that red run is committed as `01-RED.log`.**

## Performance

- **Duration:** about 3 min (2026-10-14T16:30:30Z to 16:33:38Z)
- **Tasks:** 3 of 3
- **Files:** 2 (test.sh modified, 01-RED.log created)

## Accomplishments

- Portable bash checks for FAIL-01 Linux (failed `unpack` leaves no folder, and the rerun extracts), FAIL-02 (`pkg_install curl || die`) and FAIL-03 (`brew_install X || echo returned $?`, expecting `brew install X failed.`).
- UNIN-01 for each OS: Linux (`tac`, GNU sed) and macOS (`tail -r`, BSD sed). The ledgers hold only `npm:<stub>` and `profile:<temp file>` lines, and `rea` exits 3.
- DRY-01 and DRY-02 each run in their own `docker run --rm --network none --platform linux/amd64 -v "$root:/src:ro" ubuntu:24.04` container, with a seeded `~/.rea-installer/node`, an empty `~/.agents/skills` and a `find ~ | sort` snapshot.
- A pwsh driver generated at runtime covers FAIL-01 Windows (failure and rerun) and UNIN-01 Windows. The driver uses only PowerShell 5.1 constructs.
- Results on this Mac: 21 passed, 10 failed, 2 skipped. In ubuntu:24.04: 17 passed, 5 failed, 9 skipped. Every plan 01-01 check still passes.

## Task Commits

1. **Task 1: Bash failure and uninstall checks** - `81fcad0`
2. **Task 2: Container dry-run and Windows checks** - `3c96f26`
3. **Task 3: Red evidence log** - `3aa4a0e` (01-RED.log only)

## Verification evidence

- Every `<verify>` command in the plan passed: the required FAIL names are present, no TEST-0x or GUARD check fails, no "Windows checks" failure line appears, and the HEAD commit contains only 01-RED.log.
- Red signatures in the log: DRY-01 shows `curl: command not found`, DRY-02 shows `dry run changed the home folder`, and UNIN-01 Windows shows `rea uninstall --purge-data failed with exit code 3`.
- **Green check (scratch only, not committed):** test.sh ran against throwaway copies with minimal fixes: staging `unpack`, `|| return 1` in `pkg_install`, `warn ... failed.; return 1` in `brew_install`, `|| warn` on the rea step, and a staging, try/catch `Expand-PinnedArchive` plus try/catch on the Windows rea step. Every FAIL-01/02/03 and UNIN-01 check printed PASS, on the Mac and in ubuntu:24.04. So none of these checks is stuck red. DRY-01/02 were not patched in the scratch run; research Finding 1 verified they pass with the four dry-run edits.
- `git diff 1183787..HEAD -- rea-install-*.sh rea-install-windows.ps1` is empty. No installer changed in this plan.
- `find ~/.rea-installer ~/.zshrc ~/.bash_profile -newer test.sh` printed nothing after the runs.
- `shellcheck test.sh` is clean. `git ls-files '*.ps1'` lists only rea-install-windows.ps1. test.sh contains no `??` and no `-Parallel`.

## Deviations from Plan

None. The plan ran as written. Small implementation choices:
- The first capture of 01-RED.log had an empty bash version in its header, because the tool shell is zsh. The log was regenerated with `/bin/bash`'s version (3.2.57) before the commit. The captured test output was not edited.
- When the pwsh driver reports any FAIL, test.sh prints the driver's other lines indented. These are the `caught: ...` exception texts, so the log shows why each Windows check failed.

## Notes for plans 01-03 / 01-04

- The fixed Linux `unpack` must keep the verified archive when extraction fails. The "FAIL-01 Linux rerun extracts again" check reuses the same HOME and depends on it.
- The tar stub reads `-C` for its target folder. A staging-folder `unpack` and `Expand-PinnedArchive` both work with it: the scratch green run confirmed this.
- FAIL-03 expects the exact text `brew install rea-test-formula failed.`, and UNIN-01 expects `rea uninstall failed` in the output on all three platforms.

## Self-Check: PASSED
